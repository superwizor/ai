package storage

// Tests for repairZeroedFlacStreaminfo — the zeroed-STREAMINFO shape is
// a byte-exact reproduction of live session a1b09d6c (2026-07-22):
// `fLaC` magic, 38 zero bytes where the metadata block should be, then
// a valid first frame header (0xFFF8, blocksize/rate 0x55, mono 24-bit
// 0x0C).

import (
	"bytes"
	"encoding/binary"
	"os"
	"path/filepath"
	"testing"
)

func writeTemp(t *testing.T, name string, data []byte) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), name)
	if err := os.WriteFile(p, data, 0o600); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestRepairZeroedFlacStreaminfo_RepairsLiveShape(t *testing.T) {
	// fLaC + zeroed 38-byte metadata + frame header (16 kHz code 0x5,
	// mono, 24-bit code 0x6 → byte 0x0C) + payload noise.
	data := append([]byte("fLaC"), make([]byte, 38)...)
	data = append(data, 0xFF, 0xF8, 0x55, 0x0C)
	data = append(data, bytes.Repeat([]byte{0xAB}, 64)...)
	p := writeTemp(t, "broken.flac", data)

	repaired, err := repairZeroedFlacStreaminfo(p)
	if err != nil {
		t.Fatalf("repair: %v", err)
	}
	if !repaired {
		t.Fatal("expected repair to fire on zeroed STREAMINFO")
	}

	out, _ := os.ReadFile(p)
	// Block header: last=1|type=0, length 34.
	if out[4] != 0x80 || out[7] != 34 {
		t.Fatalf("bad metadata block header: % x", out[4:8])
	}
	if bs := binary.BigEndian.Uint16(out[8:10]); bs != 4608 {
		t.Fatalf("min blocksize = %d, want 4608", bs)
	}
	packed := binary.BigEndian.Uint64(out[18:26])
	if rate := packed >> 44; rate != 16000 {
		t.Fatalf("rate = %d, want 16000", rate)
	}
	if ch := (packed >> 41) & 0x7; ch != 0 { // channels-1
		t.Fatalf("channels-1 = %d, want 0", ch)
	}
	if bps := (packed >> 36) & 0x1F; bps != 23 { // bps-1 for 24-bit
		t.Fatalf("bps-1 = %d, want 23", bps)
	}
	// Frame bytes untouched.
	if out[42] != 0xFF || out[43] != 0xF8 {
		t.Fatalf("frame header clobbered: % x", out[42:46])
	}
}

func TestRepairZeroedFlacStreaminfo_LeavesHealthyFilesAlone(t *testing.T) {
	// A populated STREAMINFO (first byte of the block header non-zero).
	data := append([]byte("fLaC"), 0x80, 0x00, 0x00, 0x22)
	data = append(data, bytes.Repeat([]byte{0x11}, 34)...)
	data = append(data, 0xFF, 0xF8, 0x55, 0x0C)
	p := writeTemp(t, "healthy.flac", data)
	before, _ := os.ReadFile(p)

	repaired, err := repairZeroedFlacStreaminfo(p)
	if err != nil || repaired {
		t.Fatalf("healthy file must be untouched (repaired=%v err=%v)", repaired, err)
	}
	after, _ := os.ReadFile(p)
	if !bytes.Equal(before, after) {
		t.Fatal("healthy file bytes changed")
	}
}

func TestRepairZeroedFlacStreaminfo_IgnoresNonFlacAndShort(t *testing.T) {
	for name, data := range map[string][]byte{
		"not-flac.bin": append([]byte("RIFF"), make([]byte, 60)...),
		"short.flac":   []byte("fLaC\x00\x00"),
	} {
		p := writeTemp(t, name, data)
		repaired, err := repairZeroedFlacStreaminfo(p)
		if err != nil || repaired {
			t.Fatalf("%s: want no-op, got repaired=%v err=%v", name, repaired, err)
		}
	}
}

func TestRepairZeroedFlacStreaminfo_FallbackWithoutFrameSync(t *testing.T) {
	// Zeroed header but garbage where the frame sync should be — repair
	// still fires with the recording-config fallback (16 kHz mono 16-bit).
	data := append([]byte("fLaC"), make([]byte, 38)...)
	data = append(data, 0x00, 0x01, 0x02, 0x03)
	p := writeTemp(t, "nosync.flac", data)

	repaired, err := repairZeroedFlacStreaminfo(p)
	if err != nil || !repaired {
		t.Fatalf("want fallback repair, got repaired=%v err=%v", repaired, err)
	}
	out, _ := os.ReadFile(p)
	packed := binary.BigEndian.Uint64(out[18:26])
	if bps := (packed >> 36) & 0x1F; bps != 15 { // 16-bit fallback
		t.Fatalf("fallback bps-1 = %d, want 15", bps)
	}
}
