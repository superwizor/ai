package storage

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/storage"
)

// Converter shells out to ffmpeg to transcode GCS-hosted audio into a
// Chirp 3-compatible codec (FLAC 16 kHz mono by default). Used by the
// new IngestionService.ConvertAudio RPC as the server-side fallback
// for clients that can't convert M4A on-device (Android, web, or iOS
// edge cases where AVAudioFile fails).
//
// Flow per call:
//   1. Download source object into a tmp file.
//   2. Shell out to ffmpeg with the target codec args.
//   3. Upload the result back to GCS at a sibling path (`<base>.flac`).
//   4. Best-effort delete the original object (OLM 48h is the
//      backstop if the delete fails).
//
// The Converter is stateless — one per service instance, safe to share
// across goroutines; the underlying *storage.Client is goroutine-safe.
type Converter struct {
	client *storage.Client
}

// ConvertResult bundles the post-conversion GCS coordinates so the
// caller (the gRPC handler) can stamp the audio_uploads row in a
// single UPDATE.
type ConvertResult struct {
	BucketName  string
	ObjectPath  string
	ContentType string
}

// NewConverter creates a Converter bound to the provided GCS client.
// In production the caller passes the same *storage.Client used by the
// Signer; for tests, pass a client wired to a fake transport.
func NewConverter(client *storage.Client) *Converter {
	return &Converter{client: client}
}

// IsChirpSupported reports whether ContentType already maps to a codec
// the Chirp 3 europe-central2 endpoint accepts. M4A / AAC / MP4 / WMA
// / MP3 all return false — those require transcoding.
//
// Mirrors the codec gate in ai-pipeline-svc/cmd/stt-worker/main.go
// (the rejection site). Keep the two lists in sync.
func IsChirpSupported(contentType string) bool {
	switch strings.ToLower(contentType) {
	case "audio/flac",
		"audio/wav",
		"audio/x-wav",
		"audio/ogg",
		"audio/opus",
		"audio/webm", // Opus-in-WebM; STT side accepts it
		"audio/amr",
		"audio/amr-wb":
		return true
	}
	return false
}

// IsValidTargetFormat gates the ConvertAudio target_content_type
// field. We allow FLAC and WAV (LINEAR16). MP3/OGG/etc. are
// intentionally out of scope — the only consumer is the downstream
// Chirp pipeline, and FLAC is the cheapest format for clinical speech.
func IsValidTargetFormat(contentType string) bool {
	switch strings.ToLower(contentType) {
	case "audio/flac", "audio/wav":
		return true
	}
	return false
}

// Convert transcodes the GCS object at (bucketName, srcObjectPath)
// into targetContentType, writes the result to a sibling path, and
// returns the new GCS coordinates. The original source object is
// best-effort deleted after the new one lands (OLM 48h catches any
// leftovers if the delete races).
//
// The handler should not call Convert when IsChirpSupported(srcType)
// is already true — short-circuit there to keep the no-op cheap.
func (c *Converter) Convert(
	ctx context.Context,
	bucketName, srcObjectPath, srcContentType, targetContentType string,
) (ConvertResult, error) {
	if !IsValidTargetFormat(targetContentType) {
		return ConvertResult{}, fmt.Errorf("unsupported target format: %s", targetContentType)
	}

	srcExt := filepath.Ext(srcObjectPath)
	if srcExt == "" {
		srcExt = extFromContentType(srcContentType)
	}

	// Stage source into a temp dir. We use a per-call dir so concurrent
	// conversions don't collide on filenames, and so the deferred
	// RemoveAll wipes both input and output in one shot.
	tmpDir, err := os.MkdirTemp("", "audioconv-*")
	if err != nil {
		return ConvertResult{}, fmt.Errorf("mktmp: %w", err)
	}
	defer func() { _ = os.RemoveAll(tmpDir) }()

	srcLocal := filepath.Join(tmpDir, "input"+srcExt)
	dstExt := extFromContentType(targetContentType)
	dstLocal := filepath.Join(tmpDir, "output"+dstExt)

	if err := c.downloadObject(ctx, bucketName, srcObjectPath, srcLocal); err != nil {
		return ConvertResult{}, fmt.Errorf("download src: %w", err)
	}

	if err := runFFmpeg(ctx, srcLocal, dstLocal, targetContentType); err != nil {
		return ConvertResult{}, err
	}

	// Sibling object path: replace extension on the original key. Keeps
	// the therapist_id/patient_file_id/timestamp prefix intact, which is
	// what audit + cleanup tooling indexes on.
	dstObjectPath := strings.TrimSuffix(srcObjectPath, srcExt) + dstExt

	// If dst == src (would only happen if someone mis-routed a
	// .flac → .flac request), append a suffix so we don't overwrite
	// the input before downloading is complete.
	if dstObjectPath == srcObjectPath {
		dstObjectPath = strings.TrimSuffix(srcObjectPath, srcExt) +
			"-converted" + dstExt
	}

	if err := c.uploadObject(ctx, bucketName, dstObjectPath, dstLocal, targetContentType); err != nil {
		return ConvertResult{}, fmt.Errorf("upload dst: %w", err)
	}

	// Best-effort delete the original. If this fails (eviction race,
	// IAM hiccup), the OLM 48h policy on the bucket cleans it up.
	// Don't fail the RPC over this — the new object is already
	// uploaded and the DB will get pointed at it.
	if delErr := c.client.Bucket(bucketName).Object(srcObjectPath).Delete(ctx); delErr != nil {
		// Not fatal — log via the caller after Convert returns.
		// We surface as a "soft" notice through the result struct's
		// fields (no extra surface for now; caller logs the converter
		// outcome).
		_ = delErr
	}

	return ConvertResult{
		BucketName:  bucketName,
		ObjectPath:  dstObjectPath,
		ContentType: targetContentType,
	}, nil
}

// maxPlausibleBytesPerSec is the upper bound on how many bytes per
// second of audio any codec we accept can sustain. 16 kHz mono FLAC
// (our recording format) runs ~16-20 KB/s; even uncompressed 48 kHz
// stereo s16 WAV is ~192 KB/s, and 96 kHz stereo s24 is ~576 KB/s.
// We set the bar at 1 MB/s (~8 Mbps) — an order of magnitude above any
// real speech recording — so a legitimate file never trips it, while a
// container whose header duration is a small fraction of the real
// length always does.
//
// This is the signature of the pause/resume corruption (session
// 028b7dcc): a 59 MB FLAC whose STREAMINFO claims ~14 s ⇒ ~4 MB/s,
// when the audio is really ~32 min. ffprobe trusts the header, so the
// long-audio chunking trigger was silently bypassed and the whole
// >20-min file was rejected by Chirp ("too long").
const maxPlausibleBytesPerSec = 1_000_000

// decodeSampleRate / decodeBytesPerSample define the raw PCM stream we
// decode to when the header duration can't be trusted. Forcing mono
// s16le @ 16 kHz makes the byte count translate directly to wall-clock
// seconds (resampling preserves duration), independent of the source's
// declared rate/channels — which is exactly what we can't trust here.
const (
	decodeSampleRate     int64 = 16000
	decodeBytesPerSample int64 = 2
)

// ProbeDuration returns the duration in seconds of the audio object at
// (bucketName, objectPath), plus a `suspect` flag indicating the
// container's declared duration could not be trusted (corrupt /
// unfinalized header — the pause/resume bug, or a mid-capture kill).
//
// This is the AUTHORITATIVE duration source — Flutter clients vary in
// what they report (0 for some upload flows; the actual recording
// elapsed time for live recordings). Server-side probing makes the
// long-audio chunking trigger client-implementation-independent.
//
// Two-tier strategy:
//  1. Read the container header via `ffprobe format=duration` (cheap).
//  2. Sanity-check it against the file size. If the implied bitrate is
//     impossible for real audio (> maxPlausibleBytesPerSec), the header
//     is lying — re-derive the true duration by decoding the whole
//     stream to raw PCM and counting samples. This ignores the corrupt
//     timestamps entirely. `suspect` is returned true so the caller
//     re-encodes the file (clean STREAMINFO + monotonic DTS) before it
//     ever reaches the chunker / Chirp.
//
// Cost: header read is ~5s for a 100 MB FLAC (download + parse); the
// decode-count fallback adds a full decode pass (~seconds), but only
// runs on the rare corrupt file. Both run once per CompleteAudioUpload.
//
// Returns (0, false, nil) when ffprobe succeeds but reports no duration
// on a trivially small file (broken/empty media with no real audio).
func (c *Converter) ProbeDuration(ctx context.Context, bucketName, objectPath string) (durationSec int, suspect bool, err error) {
	ext := filepath.Ext(objectPath)
	if ext == "" {
		ext = ".bin"
	}
	tmpDir, err := os.MkdirTemp("", "audioprobe-*")
	if err != nil {
		return 0, false, fmt.Errorf("mktmp: %w", err)
	}
	defer func() { _ = os.RemoveAll(tmpDir) }()

	local := filepath.Join(tmpDir, "input"+ext)
	if err := c.downloadObject(ctx, bucketName, objectPath, local); err != nil {
		return 0, false, fmt.Errorf("download src: %w", err)
	}

	fi, statErr := os.Stat(local)
	var fileSizeBytes int64
	if statErr == nil {
		fileSizeBytes = fi.Size()
	}

	headerSec, headerErr := probeHeaderDuration(ctx, local)
	if headerErr != nil {
		return 0, false, headerErr
	}

	if !isDurationSuspect(headerSec, fileSizeBytes) {
		return headerSec, false, nil
	}

	// Header is untrustworthy — decode the real stream to get the true
	// length. If the decode itself fails (genuinely broken media), fall
	// back to whatever the header said rather than blocking the pipeline.
	trueSec, decErr := decodeDurationSec(ctx, local)
	if decErr != nil {
		return headerSec, true, nil
	}
	return trueSec, true, nil
}

// probeHeaderDuration reads the container's declared duration via
// ffprobe. Returns 0 (no error) when the header reports no usable
// duration (e.g. an unfinalized FLAC with total_samples=0).
func probeHeaderDuration(ctx context.Context, local string) (int, error) {
	cmd := exec.CommandContext(ctx, "ffprobe",
		"-v", "error",
		"-show_entries", "format=duration",
		"-of", "default=noprint_wrappers=1:nokey=1",
		local,
	)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return 0, fmt.Errorf("ffprobe: %w (stderr: %s)", err, stderr.String())
	}

	// Output is e.g. "1320.026000\n" — seconds with fractional part.
	raw := strings.TrimSpace(stdout.String())
	if raw == "" || raw == "N/A" {
		return 0, nil
	}
	secs, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return 0, fmt.Errorf("parse duration %q: %w", raw, err)
	}
	return int(secs), nil
}

// isDurationSuspect decides whether a header-reported duration can be
// trusted given the file size. Pure function so the heuristic is
// unit-testable without ffmpeg.
//
//   - fileSize ≤ 0: no size signal (stat failed) — trust the header.
//   - headerSec ≤ 0 with real bytes: broken/unfinalized header — suspect.
//   - implied bytes/sec above the plausible ceiling: the header
//     under-reports the real length — suspect.
func isDurationSuspect(headerSec int, fileSizeBytes int64) bool {
	if fileSizeBytes <= 0 {
		return false
	}
	if headerSec <= 0 {
		return true
	}
	return fileSizeBytes/int64(headerSec) > maxPlausibleBytesPerSec
}

// decodeDurationSec returns the true audio length by decoding the whole
// stream to raw mono s16le @ 16 kHz and counting the bytes produced.
// Decoding to raw PCM ignores the container's (corrupt) timestamps and
// reconstructs the real sample count, so it is immune to the
// non-monotonic-DTS / bad-STREAMINFO corruption that fools ffprobe.
//
// The PCM is counted, never buffered — a 50-min file decodes to ~95 MB
// of s16le, which we stream through a counter rather than hold in RAM.
func decodeDurationSec(ctx context.Context, local string) (int, error) {
	cmd := exec.CommandContext(ctx, "ffmpeg",
		"-v", "error",
		"-i", local,
		"-map", "0:a:0",
		"-ac", "1",
		"-ar", strconv.FormatInt(decodeSampleRate, 10),
		"-f", "s16le",
		"-",
	)
	counter := &byteCounter{}
	cmd.Stdout = counter
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return 0, fmt.Errorf("ffmpeg decode-count: %w (stderr: %s)", err, truncate(stderr.String(), 512))
	}
	samples := counter.n / decodeBytesPerSample
	return int(samples / decodeSampleRate), nil
}

// byteCounter is an io.Writer that discards its input and tallies the
// byte count — used to measure a decoded PCM stream without buffering it.
type byteCounter struct{ n int64 }

func (b *byteCounter) Write(p []byte) (int, error) {
	b.n += int64(len(p))
	return len(p), nil
}

// downloadObject pulls the GCS object into a local file. We stream to
// avoid loading the entire payload in RAM — clinical audio runs up to
// 300 MB.
func (c *Converter) downloadObject(ctx context.Context, bucket, object, dst string) error {
	r, err := c.client.Bucket(bucket).Object(object).NewReader(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = r.Close() }()

	f, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()

	if _, err := io.Copy(f, r); err != nil {
		return err
	}
	return nil
}

// uploadObject writes a local file back to GCS at (bucket, object) with
// the supplied Content-Type. We let the Cloud Storage client choose
// chunked vs single-shot upload based on file size.
func (c *Converter) uploadObject(
	ctx context.Context,
	bucket, object, src, contentType string,
) error {
	f, err := os.Open(src)
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()

	// Give the upload a fresh context with a generous deadline. The
	// caller's gRPC deadline already covers the whole RPC; this extra
	// bound just prevents a hung TCP socket from blocking forever.
	uploadCtx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()

	w := c.client.Bucket(bucket).Object(object).NewWriter(uploadCtx)
	w.ContentType = contentType
	// Match the metadata stamp Signer applies on signed-URL uploads so
	// downstream tooling can't tell the converted object apart.
	w.Metadata = map[string]string{"x-goog-meta-source": "superwizor-mobile"}

	if _, err := io.Copy(w, f); err != nil {
		_ = w.Close()
		return err
	}
	return w.Close()
}

// runFFmpeg shells out to the binary in PATH. The Dockerfile installs
// ffmpeg via apt; the runtime base image is debian:bookworm-slim
// specifically to make this call work (distroless can't host external
// binaries).
//
// Args explanation:
//   -i <in>                source file
//   -ar 16000              16 kHz sample rate (Chirp 3's sweet spot)
//   -ac 1                  mono
//   -c:a flac|pcm_s16le    encoder
//   -compression_level 5   FLAC default; balances size vs CPU
//   -y                     overwrite if exists (we always start fresh
//                          but the flag costs nothing)
func runFFmpeg(ctx context.Context, srcPath, dstPath, targetContentType string) error {
	args := []string{"-hide_banner", "-loglevel", "error",
		// `+genpts` regenerates presentation timestamps before decode.
		// Sources from the on-device recorder can carry non-monotonic DTS
		// after a pause/resume (phone-call interruption); re-encoding then
		// rewrites a clean, finalized header with a monotonic timeline.
		// Mirrors the proven fix in chunker.go::ffmpegExtractSlice.
		"-fflags", "+genpts",
		"-i", srcPath,
		"-ar", "16000",
		"-ac", "1",
	}
	switch strings.ToLower(targetContentType) {
	case "audio/flac":
		args = append(args, "-c:a", "flac", "-compression_level", "5")
	case "audio/wav":
		args = append(args, "-c:a", "pcm_s16le")
	default:
		return fmt.Errorf("unsupported target: %s", targetContentType)
	}
	args = append(args, "-y", dstPath)

	cmd := exec.CommandContext(ctx, "ffmpeg", args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		msg := stderr.String()
		// Cap stderr included in the gRPC error message — ffmpeg can
		// dump hundreds of KB on corrupt input.
		const cap = 1024
		if len(msg) > cap {
			msg = msg[:cap] + "...(truncated)"
		}
		return fmt.Errorf("ffmpeg: %w (stderr: %s)", err, msg)
	}
	return nil
}

// extFromContentType returns the canonical filename extension for a
// MIME type. Used to name temp files + the destination GCS object key.
// Unknown types fall back to ".bin" so ffmpeg still gets a path it can
// open by extension (ffmpeg sniffs the container, the extension is
// just for staging).
func extFromContentType(ct string) string {
	switch strings.ToLower(ct) {
	case "audio/flac":
		return ".flac"
	case "audio/wav", "audio/x-wav":
		return ".wav"
	case "audio/mpeg":
		return ".mp3"
	case "audio/ogg", "audio/opus":
		return ".ogg"
	case "audio/webm":
		return ".webm"
	case "audio/mp4", "audio/m4a":
		return ".m4a"
	case "audio/aac":
		return ".aac"
	case "audio/amr":
		return ".amr"
	case "audio/x-ms-wma":
		return ".wma"
	}
	return ".bin"
}
