package storage

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/storage"
)

// ErrBadAudio marks DETERMINISTIC input failures (ffmpeg/ffprobe can't
// decode the bytes) — retrying the same input can't succeed, so the
// subscriber treats these as terminal (session FAILED). Every other
// error out of this package (GCS download/upload, tmp-dir I/O) is
// assumed TRANSIENT and must be Nack'd for Pub/Sub redelivery instead —
// live incident 2026-07-17 (session 0fb3d59b): a single
// `connection reset by peer` on the chunk-0 slice upload permanently
// failed a fully-valid session.
var ErrBadAudio = errors.New("bad audio input")

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

	if err := c.downloadObject(ctx, bucketName, srcObjectPath, srcLocal); err != nil {
		// Redelivery resilience: a prior attempt may have converted +
		// deleted the source, then failed AFTER (chunking transient →
		// Nack → tx rollback keeps the DB pointed at the deleted src).
		// If the converted sibling already exists, hand it back instead
		// of looping on a missing source until the DLQ.
		if errors.Is(err, storage.ErrObjectNotExist) {
			if _, attrsErr := c.client.Bucket(bucketName).Object(dstObjectPath).
				Attrs(ctx); attrsErr == nil {
				return ConvertResult{
					BucketName:  bucketName,
					ObjectPath:  dstObjectPath,
					ContentType: targetContentType,
				}, nil
			}
		}
		return ConvertResult{}, fmt.Errorf("download src: %w", err)
	}

	// Recording interrupted mid-session (incoming call) can leave the
	// on-device FLAC with a never-finalized STREAMINFO (all zeros) —
	// ffmpeg then refuses the file at open ("Invalid data found"),
	// live incident 2026-07-22 (session a1b09d6c). Synthesizing a valid
	// header from the first frame makes the re-encode below able to do
	// its job. No-op for healthy files.
	if repaired, repErr := repairZeroedFlacStreaminfo(srcLocal); repErr != nil {
		// Repair is best-effort — a failure here just means ffmpeg gets
		// the original bytes and renders its own verdict.
		slog.Warn("flac header repair skipped", "error", repErr)
	} else if repaired {
		slog.Info("flac header repaired (zeroed STREAMINFO)",
			"object", srcObjectPath)
	}

	if err := runFFmpeg(ctx, srcLocal, dstLocal, targetContentType); err != nil {
		// ffmpeg rejecting the input is deterministic — same bytes will
		// fail on every redelivery.
		return ConvertResult{}, fmt.Errorf("%w: %v", ErrBadAudio, err)
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
// unfinalized header — the pause/resume bug, or a mid-capture kill)
// and a machine-readable `reason` for observability.
//
// This is the AUTHORITATIVE duration source — Flutter clients vary in
// what they report (0 for some upload flows; the actual recording
// elapsed time for live recordings). Server-side probing makes the
// long-audio chunking trigger client-implementation-independent.
//
// Strategy (since session e22d25f3, 2026-07-16):
//  1. Read the container header via `ffprobe format=duration` (cheap).
//  2. ALWAYS decode the whole stream to raw PCM and count samples —
//     this ignores the container's (possibly corrupt) timestamps and
//     is the ground truth. A pause/resume-corrupted FLAC whose header
//     under-reports only moderately (782 s claimed vs 4382 s real,
//     ~0.19 MB/s implied — under the 1 MB/s size ceiling) is caught
//     by the header-vs-decode comparison, which the size heuristic
//     alone missed.
//  3. The size heuristic (`isDurationSuspect`) remains as the backstop
//     for the decode-failure path.
//
// Cost: the full-decode pass runs at >1000× realtime on the local copy
// we already downloaded for ffprobe (~0.5 s for a 73-min FLAC), once
// per upload finalization.
//
// `suspect == true` tells the caller to re-encode the file (clean
// STREAMINFO + monotonic DTS) before chunking / Chirp see it.
func (c *Converter) ProbeDuration(ctx context.Context, bucketName, objectPath string) (durationSec int, suspect bool, reason string, err error) {
	ext := filepath.Ext(objectPath)
	if ext == "" {
		ext = ".bin"
	}
	tmpDir, err := os.MkdirTemp("", "audioprobe-*")
	if err != nil {
		return 0, false, "", fmt.Errorf("mktmp: %w", err)
	}
	defer func() { _ = os.RemoveAll(tmpDir) }()

	local := filepath.Join(tmpDir, "input"+ext)
	if err := c.downloadObject(ctx, bucketName, objectPath, local); err != nil {
		return 0, false, "", fmt.Errorf("download src: %w", err)
	}

	fi, statErr := os.Stat(local)
	var fileSizeBytes int64
	if statErr == nil {
		fileSizeBytes = fi.Size()
	}

	return probeLocalDuration(ctx, local, fileSizeBytes)
}

// probeLocalDuration implements ProbeDuration's decision logic on an
// already-downloaded local file. Split out so the anomaly detection is
// testable against synthesized fixtures without a GCS client.
func probeLocalDuration(ctx context.Context, local string, fileSizeBytes int64) (durationSec int, suspect bool, reason string, err error) {
	headerSec, headerErr := probeHeaderDuration(ctx, local)
	if headerErr != nil {
		return 0, false, "", headerErr
	}

	sizeSuspect := isDurationSuspect(headerSec, fileSizeBytes)

	trueSec, decErr := decodeDurationSec(ctx, local)
	if decErr != nil {
		// Decode unavailable (genuinely broken media) — judge on the
		// size heuristic alone rather than blocking the pipeline.
		if sizeSuspect {
			return headerSec, true, "size_vs_header", nil
		}
		return headerSec, false, "", nil
	}

	switch {
	case sizeSuspect:
		return trueSec, true, "size_vs_header", nil
	case DurationsMismatch(headerSec, trueSec, 0.05, 2):
		// Header and real stream disagree beyond rounding — the
		// pause/resume concatenation signature (stale STREAMINFO).
		return trueSec, true, "header_vs_decode", nil
	}
	return trueSec, false, "", nil
}

// DurationsMismatch reports whether two duration measurements disagree
// beyond tolerance: max(absTolSec, relTol × the larger value). Used to
// compare the container header against the decoded stream length
// (tight: 5% / 2 s) and the client-reported capture time against the
// decoded length (loose: caller passes ~30% / 30 s — this catches
// gross corruption like 13 min claimed vs 73 min real, not sloppy
// client estimates; old app versions report 0, which the caller must
// filter out before calling). Pure function, unit-tested.
func DurationsMismatch(aSec, bSec int, relTol float64, absTolSec int) bool {
	diff := aSec - bSec
	if diff < 0 {
		diff = -diff
	}
	larger := aSec
	if bSec > larger {
		larger = bSec
	}
	tol := int(relTol * float64(larger))
	if tol < absTolSec {
		tol = absTolSec
	}
	return diff > tol
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
//
// Retries (live incident 2026-07-17, session 0fb3d59b): the Go SDK
// does NOT retry object writes by default (no preconditions ⇒
// non-idempotent), so a single `connection reset by peer` from the GCS
// front-end used to bubble up and terminally fail the whole session.
// Our writes are semantically idempotent — same deterministic bytes to
// the same key — so we (a) opt the handle into RetryAlways for the
// SDK's per-chunk transient handling and (b) wrap the whole write in a
// 3-attempt outer loop for failures the SDK doesn't cover.
func (c *Converter) uploadObject(
	ctx context.Context,
	bucket, object, src, contentType string,
) error {
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(time.Duration(attempt*attempt) * 2 * time.Second):
			}
			slog.Warn("uploadObject retry", "object", object,
				"attempt", attempt+1, "prev_error", lastErr)
		}
		lastErr = c.uploadObjectOnce(ctx, bucket, object, src, contentType)
		if lastErr == nil {
			return nil
		}
		if ctx.Err() != nil {
			return lastErr
		}
	}
	return lastErr
}

func (c *Converter) uploadObjectOnce(
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

	w := c.client.Bucket(bucket).Object(object).
		Retryer(storage.WithPolicy(storage.RetryAlways)).
		NewWriter(uploadCtx)
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

// ── FLAC header repair (zeroed STREAMINFO) ──────────────────────────
//
// iOS finalizes the FLAC STREAMINFO block only on a clean recorder
// stop; an OS interruption history can leave the 42-byte prefix as
// `fLaC` + zeros, which every ffmpeg tool refuses at open even though
// the frames after it are valid. repairZeroedFlacStreaminfo detects
// exactly that shape and writes a synthetic-but-valid STREAMINFO with
// the sample rate / channels / bit depth sniffed from the first frame
// header (fallback: 16 kHz mono 16-bit — the app's recording config).
// Returns (false, nil) for files that don't match the broken shape.
func repairZeroedFlacStreaminfo(path string) (bool, error) {
	f, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return false, err
	}
	defer func() { _ = f.Close() }()

	head := make([]byte, 46)
	if _, err := io.ReadFull(f, head); err != nil {
		return false, nil // too short to be a FLAC — not our case
	}
	if string(head[:4]) != "fLaC" {
		return false, nil
	}
	for _, b := range head[4:42] {
		if b != 0 {
			return false, nil // header present — healthy or differently broken
		}
	}

	// Sniff stream parameters from the first frame header right after
	// the (zeroed) metadata: sync 0xFFF8, then blocksize/rate nibbles
	// and channels/sample-size bits.
	rate, channels, bps := 16000, 1, 16
	if head[42] == 0xFF && head[43]&0xFC == 0xF8 {
		switch head[44] & 0x0F { // sample-rate code
		case 0x4:
			rate = 8000
		case 0x5:
			rate = 16000
		case 0x6:
			rate = 22050
		case 0x7:
			rate = 24000
		case 0x8:
			rate = 32000
		case 0x9:
			rate = 44100
		case 0xA:
			rate = 48000
		case 0xB:
			rate = 96000
		}
		chCode := head[45] >> 4
		if chCode <= 0x7 {
			channels = int(chCode) + 1
		} else {
			channels = 2 // stereo decorrelation modes
		}
		switch (head[45] >> 1) & 0x7 { // sample-size code
		case 0x1:
			bps = 8
		case 0x2:
			bps = 12
		case 0x4:
			bps = 16
		case 0x5:
			bps = 20
		case 0x6:
			bps = 24
		case 0x7:
			bps = 32
		}
	}

	patch := make([]byte, 38)
	// Metadata block header: last-metadata-block=1, type=0 (STREAMINFO),
	// length=34.
	patch[0] = 0x80
	patch[3] = 34
	// min/max blocksize — any legal fixed value; ffmpeg reads the real
	// size per-frame.
	binary.BigEndian.PutUint16(patch[4:6], 4608)
	binary.BigEndian.PutUint16(patch[6:8], 4608)
	// min/max framesize (6 bytes) stay 0 = unknown.
	// rate(20) | channels-1(3) | bps-1(5) | total-samples(36, 0=unknown).
	packed := uint64(rate)<<44 |
		uint64(channels-1)<<41 |
		uint64(bps-1)<<36
	binary.BigEndian.PutUint64(patch[14:22], packed)
	// MD5 (16 bytes) stays zeroed = unset.

	if _, err := f.WriteAt(patch, 4); err != nil {
		return false, err
	}
	return true, nil
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
