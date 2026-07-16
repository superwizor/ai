package storage

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"testing"
)

// TestIsChirpSupported codifies the codec gate. Keep this in sync
// with the rejection site in
// services/ai-pipeline-svc/cmd/stt-worker/main.go — drift between
// the two lists would silently send unsupported audio to Chirp and
// land the session in FAILED.
func TestIsChirpSupported(t *testing.T) {
	cases := []struct {
		ct   string
		want bool
	}{
		// Supported codecs (Chirp 3 europe-central2)
		{"audio/flac", true},
		{"audio/wav", true},
		{"audio/x-wav", true},
		{"audio/ogg", true},
		{"audio/opus", true},
		{"audio/webm", true},
		{"audio/amr", true},
		{"audio/amr-wb", true},
		// Case-insensitive.
		{"AUDIO/FLAC", true},
		{"Audio/Wav", true},

		// Unsupported codecs (need ConvertAudio fallback).
		{"audio/m4a", false},
		{"audio/mp4", false},
		{"audio/aac", false},
		{"audio/mpeg", false}, // MP3 — not in Chirp 3's accept list
		{"audio/x-ms-wma", false},
		{"", false},
		{"text/plain", false},

		// audio/x-flac MUST stay unsupported. The Flutter orphan-recovery
		// path (docs/28 R1) uploads possibly-unfinalized recovered FLAC
		// under this MIME *specifically* so the subscriber routes it
		// through ffmpeg, which rewrites a clean STREAMINFO header Chirp
		// will accept. Adding audio/x-flac here would skip that re-encode
		// and resurrect the unfinalized-header rejection. Do not change
		// without updating recording_recovery_service.dart.
		{"audio/x-flac", false},
	}
	for _, tc := range cases {
		t.Run(tc.ct, func(t *testing.T) {
			if got := IsChirpSupported(tc.ct); got != tc.want {
				t.Errorf("IsChirpSupported(%q) = %v, want %v", tc.ct, got, tc.want)
			}
		})
	}
}

func TestIsValidTargetFormat(t *testing.T) {
	cases := []struct {
		ct   string
		want bool
	}{
		{"audio/flac", true},
		{"audio/wav", true},
		{"AUDIO/FLAC", true},
		{"audio/mpeg", false},
		{"audio/ogg", false},
		{"", false},
	}
	for _, tc := range cases {
		t.Run(tc.ct, func(t *testing.T) {
			if got := IsValidTargetFormat(tc.ct); got != tc.want {
				t.Errorf("IsValidTargetFormat(%q) = %v, want %v", tc.ct, got, tc.want)
			}
		})
	}
}

func TestExtFromContentType(t *testing.T) {
	cases := map[string]string{
		"audio/flac":     ".flac",
		"audio/wav":      ".wav",
		"audio/x-wav":    ".wav",
		"audio/mpeg":     ".mp3",
		"audio/ogg":      ".ogg",
		"audio/opus":     ".ogg",
		"audio/webm":     ".webm",
		"audio/mp4":      ".m4a",
		"audio/m4a":      ".m4a",
		"audio/aac":      ".aac",
		"audio/amr":      ".amr",
		"audio/x-ms-wma": ".wma",
		"":               ".bin",
		"unknown/type":   ".bin",
	}
	for ct, want := range cases {
		if got := extFromContentType(ct); got != want {
			t.Errorf("extFromContentType(%q) = %q, want %q", ct, got, want)
		}
	}
}

// TestRunFFmpeg_HappyPath exercises the actual ffmpeg shell-out. Skips
// when ffmpeg isn't on PATH — local dev machines without it shouldn't
// block CI; CI runs inside the ingestion-svc Docker image which has
// ffmpeg installed, so this test will execute there.
//
// We synthesize a 1-second 16 kHz mono sine WAV via ffmpeg's lavfi,
// then transcode WAV → FLAC through runFFmpeg. Asserts that the
// output file exists + is non-empty and starts with the FLAC magic
// number "fLaC" (per RFC 9639).
func TestRunFFmpeg_HappyPath(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not on PATH; skipping (CI image has ffmpeg)")
	}

	tmp := t.TempDir()
	src := filepath.Join(tmp, "in.wav")
	dst := filepath.Join(tmp, "out.flac")

	// Generate a 1s 440 Hz sine WAV using ffmpeg's lavfi source. This
	// keeps the test self-contained — no fixture file to commit.
	gen := exec.Command("ffmpeg",
		"-hide_banner", "-loglevel", "error",
		"-f", "lavfi",
		"-i", "sine=frequency=440:duration=1:sample_rate=16000",
		"-ac", "1",
		"-y", src,
	)
	if out, err := gen.CombinedOutput(); err != nil {
		t.Fatalf("generate sample wav: %v\n%s", err, out)
	}

	ctx := context.Background()
	if err := runFFmpeg(ctx, src, dst, "audio/flac"); err != nil {
		t.Fatalf("runFFmpeg: %v", err)
	}

	st, err := os.Stat(dst)
	if err != nil {
		t.Fatalf("output stat: %v", err)
	}
	if st.Size() == 0 {
		t.Fatalf("output file is empty")
	}

	// FLAC magic per RFC 9639 §8.1: first 4 bytes are "fLaC".
	head := make([]byte, 4)
	f, err := os.Open(dst)
	if err != nil {
		t.Fatalf("open dst: %v", err)
	}
	defer func() { _ = f.Close() }()
	if _, err := f.Read(head); err != nil {
		t.Fatalf("read dst head: %v", err)
	}
	if string(head) != "fLaC" {
		t.Fatalf("output is not FLAC: leading bytes = %q", string(head))
	}
}

// TestRunFFmpeg_BadInput surfaces the error path: when the source
// file isn't audio at all, ffmpeg returns non-zero and runFFmpeg
// surfaces a wrapped error containing the stderr tail.
func TestRunFFmpeg_BadInput(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not on PATH")
	}

	tmp := t.TempDir()
	src := filepath.Join(tmp, "garbage.m4a")
	dst := filepath.Join(tmp, "out.flac")
	if err := os.WriteFile(src, []byte("this is not audio"), 0o600); err != nil {
		t.Fatal(err)
	}

	err := runFFmpeg(context.Background(), src, dst, "audio/flac")
	if err == nil {
		t.Fatalf("expected error for non-audio input, got nil")
	}
}

// TestRunFFmpeg_UnsupportedTarget guards the target format gate. The
// gRPC handler validates via IsValidTargetFormat first, but the
// converter must refuse the same set defensively in case it's
// invoked from a different call site in the future.
func TestRunFFmpeg_UnsupportedTarget(t *testing.T) {
	err := runFFmpeg(context.Background(), "irrelevant", "irrelevant", "audio/mpeg")
	if err == nil {
		t.Fatalf("expected error for audio/mpeg target, got nil")
	}
}

// TestIsDurationSuspect locks the heuristic that decides when a
// container's declared duration can't be trusted. The pause/resume
// corruption (session 028b7dcc) is the headline case: a 59 MB FLAC
// whose STREAMINFO claims ~14 s ⇒ ~4 MB/s, an order of magnitude past
// any real speech codec. Legit files (FLAC, even uncompressed WAV) must
// never trip it, or every upload eats a needless full-decode pass.
func TestIsDurationSuspect(t *testing.T) {
	cases := []struct {
		name      string
		headerSec int
		sizeBytes int64
		want      bool
	}{
		// The real incident: 62,179,235 bytes claiming 14 s ⇒ ~4.4 MB/s.
		{"incident_028b7dcc", 14, 62_179_235, true},
		// Healthy 16 kHz mono FLAC: ~32 min, ~32 MB ⇒ ~17 KB/s.
		{"healthy_flac_32min", 1932, 33_000_000, false},
		// Healthy 1 h FLAC at the same rate.
		{"healthy_flac_1h", 3600, 62_000_000, false},
		// Uncompressed 48 kHz stereo s16 WAV: ~192 KB/s — well under cap.
		{"uncompressed_wav_10min", 600, 115_000_000, false},
		// Broken/unfinalized header (total_samples=0) but real bytes.
		{"unfinalized_header", 0, 50_000_000, true},
		// No size signal (stat failed) — can't judge, trust header.
		{"no_size_signal", 14, 0, false},
		// Empty/no-audio file with zero header — nothing to suspect.
		{"empty_file", 0, 0, false},
		// Exactly at the 1 MB/s ceiling is NOT suspect (strict >).
		{"at_ceiling", 1, maxPlausibleBytesPerSec, false},
		// Just over the ceiling is suspect.
		{"over_ceiling", 1, maxPlausibleBytesPerSec + 1, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := isDurationSuspect(tc.headerSec, tc.sizeBytes); got != tc.want {
				t.Errorf("isDurationSuspect(%d, %d) = %v, want %v",
					tc.headerSec, tc.sizeBytes, got, tc.want)
			}
		})
	}
}

// TestDecodeDurationSec verifies the decode-count fallback recovers the
// true length by decoding to raw PCM (immune to corrupt timestamps /
// STREAMINFO). We synthesize a known-length sine FLAC and assert the
// measured duration matches. Skips when ffmpeg isn't on PATH (CI image
// has it).
func TestDecodeDurationSec(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not on PATH; skipping (CI image has ffmpeg)")
	}

	tmp := t.TempDir()
	src := filepath.Join(tmp, "in.flac")

	// 7-second 440 Hz sine, 16 kHz mono FLAC — matches our recording fmt.
	const wantSec = 7
	gen := exec.Command("ffmpeg",
		"-hide_banner", "-loglevel", "error",
		"-f", "lavfi",
		"-i", "sine=frequency=440:duration=7:sample_rate=16000",
		"-ac", "1",
		"-c:a", "flac",
		"-y", src,
	)
	if out, err := gen.CombinedOutput(); err != nil {
		t.Fatalf("generate sample flac: %v\n%s", err, out)
	}

	got, err := decodeDurationSec(context.Background(), src)
	if err != nil {
		t.Fatalf("decodeDurationSec: %v", err)
	}
	// Allow ±1 s for frame-boundary rounding in the sample count.
	if got < wantSec-1 || got > wantSec+1 {
		t.Fatalf("decodeDurationSec = %d, want ~%d", got, wantSec)
	}
}

// TestDurationsMismatch codifies the tolerance math used for both the
// header-vs-decode comparison (tight) and the client-vs-decode
// cross-check (loose). The production incident it must catch:
// session e22d25f3 — header 782 s, decoded 4382 s (73 min), implied
// bitrate ~0.19 MB/s which the size heuristic alone let through.
func TestDurationsMismatch(t *testing.T) {
	cases := []struct {
		name           string
		a, b           int
		relTol         float64
		absTol         int
		want           bool
	}{
		// The e22d25f3 incident under header-vs-decode tolerances.
		{"incident_e22d25f3", 782, 4382, 0.05, 2, true},
		// Header == decode: never a mismatch.
		{"exact_match", 3600, 3600, 0.05, 2, false},
		// Rounding drift on a long file stays within 5%.
		{"rounding_long", 3600, 3598, 0.05, 2, false},
		// Short files: absolute floor dominates (2 s grace).
		{"short_within_abs", 5, 7, 0.05, 2, false},
		{"short_beyond_abs", 5, 8, 0.05, 2, true},
		// Client-vs-decode profile (15% / 10 s): wall-clock drift ok…
		{"client_drift_ok", 3600, 3400, 0.30, 30, false},
		// …but a 60-min capture claiming 13 min is not.
		{"client_gross_mismatch", 782, 4382, 0.30, 30, true},
		// Sloppy-but-honest harness estimate must NOT flag (60 s claimed, 40 s real).
		{"client_sloppy_estimate_ok", 60, 40, 0.30, 30, false},
		// Symmetric: order of args must not matter.
		{"symmetric", 4382, 782, 0.05, 2, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := DurationsMismatch(tc.a, tc.b, tc.relTol, tc.absTol); got != tc.want {
				t.Errorf("DurationsMismatch(%d, %d, %v, %d) = %v, want %v",
					tc.a, tc.b, tc.relTol, tc.absTol, got, tc.want)
			}
		})
	}
}

// TestProbeLocalDuration_ConcatenatedFlac reproduces the pause/resume
// corruption end-to-end at fixture scale: two independently-encoded
// FLAC streams concatenated into one file. The leading STREAMINFO
// describes only the first segment, so the header under-reports —
// exactly the session-e22d25f3 shape (moderate under-report, below the
// 1 MB/s size ceiling). probeLocalDuration must (a) return the real
// decoded length and (b) flag the file as suspect via header_vs_decode.
// Skips when ffmpeg isn't on PATH (CI image has it).
func TestProbeLocalDuration_ConcatenatedFlac(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not on PATH; skipping (CI image has ffmpeg)")
	}

	tmp := t.TempDir()
	genSine := func(name string, seconds int) string {
		p := filepath.Join(tmp, name)
		gen := exec.Command("ffmpeg",
			"-hide_banner", "-loglevel", "error",
			"-f", "lavfi",
			"-i", "sine=frequency=440:duration="+strconv.Itoa(seconds)+":sample_rate=16000",
			"-ac", "1", "-c:a", "flac", "-y", p,
		)
		if out, err := gen.CombinedOutput(); err != nil {
			t.Fatalf("generate %s: %v\n%s", name, err, out)
		}
		return p
	}

	seg1 := genSine("seg1.flac", 8)
	seg2 := genSine("seg2.flac", 30)

	concat := filepath.Join(tmp, "concat.flac")
	b1, err := os.ReadFile(seg1)
	if err != nil {
		t.Fatal(err)
	}
	b2, err := os.ReadFile(seg2)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(concat, append(b1, b2...), 0o600); err != nil {
		t.Fatal(err)
	}
	fi, err := os.Stat(concat)
	if err != nil {
		t.Fatal(err)
	}

	durationSec, suspect, reason, err := probeLocalDuration(context.Background(), concat, fi.Size())
	if err != nil {
		t.Fatalf("probeLocalDuration: %v", err)
	}
	if !suspect {
		t.Fatalf("suspect = false, want true (duration=%d reason=%q)", durationSec, reason)
	}
	if reason != "header_vs_decode" {
		t.Errorf("reason = %q, want header_vs_decode", reason)
	}
	// True length is ~38 s; the header claims only the first ~8 s.
	if durationSec < 36 || durationSec > 40 {
		t.Errorf("durationSec = %d, want ~38 (decoded ground truth)", durationSec)
	}
}

// TestProbeLocalDuration_HealthyFlac is the regression guard: a clean
// single-stream FLAC must NOT be flagged suspect (a false positive
// would re-encode every healthy upload — wasted CPU and a changed
// object path on every session).
func TestProbeLocalDuration_HealthyFlac(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg not on PATH; skipping (CI image has ffmpeg)")
	}

	tmp := t.TempDir()
	p := filepath.Join(tmp, "clean.flac")
	gen := exec.Command("ffmpeg",
		"-hide_banner", "-loglevel", "error",
		"-f", "lavfi",
		"-i", "sine=frequency=440:duration=12:sample_rate=16000",
		"-ac", "1", "-c:a", "flac", "-y", p,
	)
	if out, err := gen.CombinedOutput(); err != nil {
		t.Fatalf("generate clean flac: %v\n%s", err, out)
	}
	fi, err := os.Stat(p)
	if err != nil {
		t.Fatal(err)
	}

	durationSec, suspect, reason, err := probeLocalDuration(context.Background(), p, fi.Size())
	if err != nil {
		t.Fatalf("probeLocalDuration: %v", err)
	}
	if suspect {
		t.Fatalf("suspect = true (reason=%q), want false for a healthy file", reason)
	}
	if durationSec < 11 || durationSec > 13 {
		t.Errorf("durationSec = %d, want ~12", durationSec)
	}
}
