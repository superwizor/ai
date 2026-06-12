package storage

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
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
