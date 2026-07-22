package storage

// chunker.go — Stage 2 of feat/stt-long_audio_support.
//
// Splits a Chirp-supported FLAC (16 kHz mono — already produced by
// Convert if the source was M4A/etc.) into ≤ maxChunkSec segments
// with a configurable overlap window for cross-chunk diarization
// alignment. ffmpeg silencedetect is used to pick cut points near
// the target intervals; falls back to time-based cuts when no
// suitable silence is found.
//
// Caller (grpc/server.go::ConvertAudio) feeds the returned slice
// directly to a CreateAudioChunks SQL batch.
//
// See docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md "ffmpeg chunking
// strategy" + "Overlap window" sections.

import (
	"bytes"
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// Algorithm parameters. Centralized so future tuning is one PR.
const (
	// Target overlap behind every chunk_index > 0 chunk. Stage 2
	// alignment uses this window for time-anchored speaker-label
	// matching (see internal/sttgcs/alignment.go). Default mirrors
	// the alignOverlapMinMS knob in ai-pipeline-svc.
	overlapTargetMS int64 = 10_000 // 10s

	// Hard upper bound on chunk duration, in seconds. Chirp 3's
	// word-timestamp limit is 1200s (20 min); we leave a 60s safety
	// margin. Caller default is 1140s.
	maxChunkSecHardCap = 1200

	// Default max chunk duration when caller passes 0 in the proto.
	defaultMaxChunkSec = 1140

	// silencedetect threshold: anything below -30dB sustained for
	// ≥ silenceMinD seconds is considered a silence candidate.
	// Tuned empirically — Polish-therapy speech typically rests at
	// -40dB to -60dB during pauses, so -30dB safely captures
	// natural pauses without false-positives on background noise.
	silenceNoiseDB = "-30dB"
	silenceMinD    = "0.2"

	// Search window around the target cut point where we look for
	// the longest silence. ±60s is generous enough to find a real
	// pause on a 19-min chunk (people pause every ~30s in
	// therapy); short enough that we don't drift wildly off-target.
	silenceSearchWindowMS int64 = 60_000

	// Safety slop subtracted from the hard cap when bounding cut points.
	// Absorbs FLAC frame-boundary rounding in ffmpeg's time-based cut and
	// Chirp's exclusive interpretation of the 20-min limit, so a chunk
	// planned just under the cap never tips over it on the wire.
	chunkSafetySlopMS int64 = 20_000
)

// AudioChunk is the per-chunk metadata returned by ChunkForChirp,
// ready to be persisted as one row in the audio_chunks table.
//
// Field semantics match the migration 000023_audio_chunks columns.
type AudioChunk struct {
	ChunkIndex    int
	BucketName    string
	ObjectPath    string
	StartOffsetMS int64
	SeamOffsetMS  int64
	EndOffsetMS   int64
	OverlapMS     int
	CutOnSilence  bool
}

// ChunkForChirp downloads the source FLAC at (bucket, objectPath),
// runs ffmpeg silencedetect to pick cut points, splits the audio
// into ≤ maxChunkSec segments with overlapTargetMS overlap, uploads
// each chunk back to a sibling GCS path, and returns the per-chunk
// metadata.
//
// Caller invariants:
//   - sourceContentType MUST be a Chirp-supported codec (FLAC/WAV/
//     OGG/etc.). Normalize via Convert FIRST if the upload was M4A.
//   - sourceDurationSec MUST match actual audio length; we use it
//     for fallback time cuts when silence detection misses.
//
// Returns nil + nil error when sourceDurationSec ≤ maxChunkSec
// (no chunking needed — caller should leave audio_chunks empty
// and stt-submit falls back to the single virtual-chunk path).
//
// On any failure (download, ffmpeg, upload), returns a wrapped
// error. The caller wraps in pg_advisory_xact_lock so partial GCS
// uploads from a crashed earlier attempt are rolled back via the
// re-check + transaction discipline.
func (c *Converter) ChunkForChirp(
	ctx context.Context,
	bucketName, objectPath string,
	sourceDurationSec int,
	maxChunkSec int,
) ([]AudioChunk, error) {
	if maxChunkSec <= 0 {
		maxChunkSec = defaultMaxChunkSec
	}
	if maxChunkSec > maxChunkSecHardCap {
		maxChunkSec = maxChunkSecHardCap
	}

	if sourceDurationSec <= maxChunkSec {
		// Short enough — no chunking needed.
		return nil, nil
	}

	tmpDir, err := os.MkdirTemp("", "audiochunk-*")
	if err != nil {
		return nil, fmt.Errorf("mktmp: %w", err)
	}
	defer func() { _ = os.RemoveAll(tmpDir) }()

	// 1. Download source FLAC.
	srcExt := filepath.Ext(objectPath)
	if srcExt == "" {
		srcExt = ".flac"
	}
	srcLocal := filepath.Join(tmpDir, "input"+srcExt)
	if err := c.downloadObject(ctx, bucketName, objectPath, srcLocal); err != nil {
		return nil, fmt.Errorf("download src: %w", err)
	}

	// Same zeroed-STREAMINFO belt as Convert — chunking can also meet a
	// never-finalized on-device FLAC directly (Chirp-supported content
	// type skips the transcode stage).
	if repaired, repErr := repairZeroedFlacStreaminfo(srcLocal); repErr == nil && repaired {
		slog.Info("flac header repaired before chunking", "object", objectPath)
	}

	// 2. Compute target cut points and run silencedetect.
	targets := planCutTargets(sourceDurationSec, maxChunkSec)
	if len(targets) == 0 {
		// Source short enough after rounding; treat as no-chunk.
		return nil, nil
	}
	silences, err := detectSilences(ctx, srcLocal)
	if err != nil {
		// Silence detection failure is recoverable — fall back to
		// time-based cuts. Log via the wrapped error.
		silences = nil
	}

	// 3. Pick actual cut points from silence candidates near each
	//    target, BOUNDED so no resulting chunk can exceed Chirp's 20-min
	//    BatchRecognize hard cap (the silence snap used to be able to push
	//    a cut forward by up to silenceSearchWindowMS, blowing the 60s
	//    margin and producing a >20-min chunk that Chirp rejects with
	//    INVALID_ARGUMENT — root cause of session e55b7c1e failing).
	durationMS := int64(sourceDurationSec) * 1000
	cutPoints := selectCutPoints(targets, silences, durationMS, overlapTargetMS)

	// 4. Build chunk plan with overlap_ms behind each chunk > 0.
	chunks := buildChunkPlan(cutPoints, durationMS, overlapTargetMS)

	// 5. ffmpeg-split + upload each chunk.
	srcPrefix := strings.TrimSuffix(objectPath, srcExt)
	for i := range chunks {
		dstLocal := filepath.Join(tmpDir, fmt.Sprintf("chunk_%d.flac", chunks[i].ChunkIndex))
		dstObjectPath := fmt.Sprintf("%s_chunk_%d.flac", srcPrefix, chunks[i].ChunkIndex)

		if err := ffmpegExtractSlice(
			ctx,
			srcLocal,
			dstLocal,
			chunks[i].StartOffsetMS,
			chunks[i].EndOffsetMS,
		); err != nil {
			// Deterministic decode failure — the same input fails on
			// every redelivery, so mark terminal for the subscriber.
			return nil, fmt.Errorf("ffmpeg chunk %d: %w: %v",
				chunks[i].ChunkIndex, ErrBadAudio, err)
		}
		if err := c.uploadObject(ctx, bucketName, dstObjectPath, dstLocal, "audio/flac"); err != nil {
			return nil, fmt.Errorf("upload chunk %d: %w", chunks[i].ChunkIndex, err)
		}

		chunks[i].BucketName = bucketName
		chunks[i].ObjectPath = dstObjectPath
	}

	return chunks, nil
}

// planCutTargets returns the absolute ms positions at which we'd
// like to cut, ignoring overlap. e.g. for a 70-min source with
// maxChunkSec=1140 (19 min), returns [19*60_000, 38*60_000,
// 57*60_000] ms — three cuts producing four ~17.5-min chunks.
//
// Strategy: divide source duration into roughly equal segments
// where each is ≤ maxChunkSec. Picking N = ceil(duration /
// maxChunkSec) chunks and spreading targets evenly gives all
// chunks the same approximate length, which is better for
// alignment quality than packing the early chunks to maxChunkSec
// and leaving a short tail.
func planCutTargets(sourceDurationSec, maxChunkSec int) []int64 {
	if sourceDurationSec <= maxChunkSec {
		return nil
	}
	n := (sourceDurationSec + maxChunkSec - 1) / maxChunkSec // ceil
	chunkLen := int64(sourceDurationSec) * 1000 / int64(n)
	targets := make([]int64, 0, n-1)
	for i := 1; i < n; i++ {
		targets = append(targets, chunkLen*int64(i))
	}
	return targets
}

type cutPoint struct {
	AtMS         int64
	OnSilence    bool
}

// selectCutPoints turns evenly-spaced cut targets into actual cut points,
// snapping each to nearby silence WHILE GUARANTEEING that no resulting
// chunk exceeds Chirp's 20-min BatchRecognize hard cap.
//
// Each cut is bounded to [minAtMS, maxAtMS]:
//   - maxAtMS keeps the chunk this cut CLOSES under the cap. The chunk
//     starts at the previous cut minus the overlap (or 0 for chunk 0);
//     the cut may not land more than (hardCap − slop) past that start.
//   - minAtMS applies only to the FINAL cut, ensuring the TRAILING chunk
//     (lastCut−overlap … durationMS) also fits under the cap — a backward
//     silence snap on the last cut could otherwise over-extend the tail.
//
// Pure function (no I/O) so the cap invariant is unit-testable.
func selectCutPoints(targets []int64, silences []silenceRange, durationMS, overlapMS int64) []cutPoint {
	hardLimitMS := int64(maxChunkSecHardCap)*1000 - chunkSafetySlopMS
	out := make([]cutPoint, 0, len(targets))
	var prevCut int64
	for i, t := range targets {
		chunkStart := int64(0)
		if i > 0 {
			chunkStart = prevCut - overlapMS
			if chunkStart < 0 {
				chunkStart = 0
			}
		}
		maxAtMS := chunkStart + hardLimitMS
		if maxAtMS > durationMS {
			maxAtMS = durationMS
		}
		minAtMS := int64(0)
		if i == len(targets)-1 {
			minAtMS = durationMS - hardLimitMS + overlapMS
			if minAtMS < 0 {
				minAtMS = 0
			}
		}
		if minAtMS > maxAtMS {
			minAtMS = maxAtMS
		}
		out = append(out, chooseCutPoint(silences, t, minAtMS, maxAtMS))
		prevCut = out[i].AtMS
	}
	return out
}

// chooseCutPoint picks the silence midpoint nearest to `target` within
// ±silenceSearchWindowMS, but only among candidates inside [minAtMS,
// maxAtMS] — silence outside that window would push an adjacent chunk
// past Chirp's hard cap and is rejected. Falls back to the target
// clamped into [minAtMS, maxAtMS] (OnSilence=false) when no candidate is
// in range.
func chooseCutPoint(silences []silenceRange, target, minAtMS, maxAtMS int64) cutPoint {
	// Clamp the fallback so even a no-silence cut respects the cap.
	effTarget := target
	if effTarget < minAtMS {
		effTarget = minAtMS
	}
	if effTarget > maxAtMS {
		effTarget = maxAtMS
	}

	bestDelta := silenceSearchWindowMS + 1
	bestMid := effTarget
	onSilence := false
	for _, s := range silences {
		mid := (s.StartMS + s.EndMS) / 2
		if mid < minAtMS || mid > maxAtMS {
			continue // would breach the hard cap on an adjacent chunk
		}
		delta := mid - target
		if delta < 0 {
			delta = -delta
		}
		if delta <= silenceSearchWindowMS && delta < bestDelta {
			bestDelta = delta
			bestMid = mid
			onSilence = true
		}
	}
	return cutPoint{AtMS: bestMid, OnSilence: onSilence}
}

// silenceRange is a single silence interval reported by ffmpeg's
// silencedetect filter.
type silenceRange struct {
	StartMS int64
	EndMS   int64
}

// detectSilences runs ffmpeg with silencedetect and parses the
// stderr output for silence start/end markers. ffmpeg's filter
// emits lines like:
//
//	[silencedetect @ 0x...] silence_start: 12.345
//	[silencedetect @ 0x...] silence_end: 14.678 | silence_duration: 2.333
//
// We pair each start with the following end. Unmatched starts (at
// EOF) are dropped — those would represent silence-to-end-of-file
// which we don't want to cut on anyway.
func detectSilences(ctx context.Context, srcLocal string) ([]silenceRange, error) {
	cmd := exec.CommandContext(ctx, "ffmpeg",
		"-hide_banner", "-loglevel", "info",
		"-i", srcLocal,
		"-af", fmt.Sprintf("silencedetect=noise=%s:d=%s", silenceNoiseDB, silenceMinD),
		"-f", "null",
		"-",
	)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("silencedetect: %w (stderr: %s)", err, truncate(stderr.String(), 512))
	}

	startRE := regexp.MustCompile(`silence_start: ([0-9.]+)`)
	endRE := regexp.MustCompile(`silence_end: ([0-9.]+)`)
	starts := parseAllFloats(startRE, stderr.String())
	ends := parseAllFloats(endRE, stderr.String())

	out := make([]silenceRange, 0, min(len(starts), len(ends)))
	for i := 0; i < len(starts) && i < len(ends); i++ {
		out = append(out, silenceRange{
			StartMS: int64(starts[i] * 1000),
			EndMS:   int64(ends[i] * 1000),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].StartMS < out[j].StartMS })
	return out, nil
}

func parseAllFloats(re *regexp.Regexp, s string) []float64 {
	matches := re.FindAllStringSubmatch(s, -1)
	out := make([]float64, 0, len(matches))
	for _, m := range matches {
		v, err := strconv.ParseFloat(m[1], 64)
		if err == nil {
			out = append(out, v)
		}
	}
	return out
}

// buildChunkPlan turns a list of cut points + total duration into
// the AudioChunk slice. Each chunk_i (i > 0) starts overlapMS
// before chunk_{i-1}'s seam, providing the overlap window the
// cross-chunk alignment needs.
//
// Chunk layout:
//
//	chunk 0:  [0,                       cut[0] + 0          ]  seam=cut[0]
//	chunk 1:  [cut[0] - overlap,        cut[1] + 0          ]  seam=cut[1]
//	chunk 2:  [cut[1] - overlap,        cut[2] + 0          ]  seam=cut[2]
//	chunk N-1:[cut[N-2] - overlap,      duration            ]  seam=duration
//
// overlap_ms is recorded per-row (0 for chunk 0; otherwise = overlap).
func buildChunkPlan(cuts []cutPoint, durationMS, overlapMS int64) []AudioChunk {
	if len(cuts) == 0 {
		return nil
	}
	chunks := make([]AudioChunk, 0, len(cuts)+1)
	for i := 0; i <= len(cuts); i++ {
		var start, end, seam int64
		var overlap int
		switch {
		case i == 0:
			start = 0
			seam = cuts[0].AtMS
			end = seam
			overlap = 0
		case i == len(cuts):
			start = cuts[i-1].AtMS - overlapMS
			if start < 0 {
				start = 0
			}
			seam = durationMS
			end = durationMS
			overlap = int(overlapMS)
		default:
			start = cuts[i-1].AtMS - overlapMS
			if start < 0 {
				start = 0
			}
			seam = cuts[i].AtMS
			end = seam
			overlap = int(overlapMS)
		}

		cutOnSilence := true
		if i > 0 && !cuts[i-1].OnSilence {
			// The cut LEADING this chunk was a fallback (no
			// silence found). Tag for observability.
			cutOnSilence = false
		}

		chunks = append(chunks, AudioChunk{
			ChunkIndex:    i,
			StartOffsetMS: start,
			SeamOffsetMS:  seam,
			EndOffsetMS:   end,
			OverlapMS:     overlap,
			CutOnSilence:  cutOnSilence,
		})
	}
	return chunks
}

// ffmpegExtractSlice cuts [startMS, endMS] out of srcLocal into
// dstLocal as FLAC. Uses -ss BEFORE -i for fast seek (frame-
// accurate within ~10ms for FLAC), and -t for duration. -c copy is
// NOT used — Chirp 3 expects re-encoded FLAC at known sample-rate
// boundaries.
func ffmpegExtractSlice(ctx context.Context, srcLocal, dstLocal string, startMS, endMS int64) error {
	durationMS := endMS - startMS
	if durationMS <= 0 {
		return fmt.Errorf("invalid slice: start=%d end=%d", startMS, endMS)
	}
	// Last-resort guard: a single chunk must never exceed Chirp's 20-min
	// BatchRecognize hard cap. selectCutPoints already bounds the planned
	// span and the +genpts/aresample flags keep ffmpeg honest, but clamp
	// the -t value here too so no oversized chunk can ever reach Chirp if
	// some future regression slips past both.
	if hardMS := int64(maxChunkSecHardCap)*1000 - chunkSafetySlopMS; durationMS > hardMS {
		slog.Warn("clamping oversized chunk slice to Chirp 20-min cap",
			"fromMS", durationMS, "toMS", hardMS, "startMS", startMS, "endMS", endMS)
		durationMS = hardMS
	}
	cmd := exec.CommandContext(ctx, "ffmpeg",
		"-hide_banner", "-loglevel", "error",
		// ROOT-CAUSE FIX (session e55b7c1e): the recorded FLAC can carry
		// non-monotonic DTS (seen from the on-device recorder). With a
		// plain "-ss N -i src -t D" that makes ffmpeg SILENTLY ignore the
		// -t duration cap on the first slice — chunk_0 overshot its
		// planned ~18.5 min to 21.0 min and Chirp BatchRecognize rejected
		// it ("file too long"), failing the whole session. `+genpts`
		// regenerates presentation timestamps and `aresample=async=1`
		// rebuilds a monotonic audio timeline, so `-t` is honoured exactly
		// (verified: 1259s → 1110s on the offending recording). The cut
		// planning was already correct; this is the layer that was broken.
		"-fflags", "+genpts",
		"-ss", msToSecondsArg(startMS),
		"-i", srcLocal,
		"-t", msToSecondsArg(durationMS),
		"-af", "aresample=async=1",
		"-ar", "16000",
		"-ac", "1",
		"-c:a", "flac",
		"-compression_level", "5",
		"-y", dstLocal,
	)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("ffmpeg slice: %w (stderr: %s)", err, truncate(stderr.String(), 512))
	}
	return nil
}

// msToSecondsArg formats milliseconds as ffmpeg's seconds-with-
// decimals input, e.g. 1234567 → "1234.567".
func msToSecondsArg(ms int64) string {
	whole := ms / 1000
	frac := ms % 1000
	return fmt.Sprintf("%d.%03d", whole, frac)
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "...(truncated)"
}
