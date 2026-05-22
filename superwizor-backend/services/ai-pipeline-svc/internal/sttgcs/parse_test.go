package sttgcs

import "testing"

func TestParseOutputObjectPath(t *testing.T) {
	cases := []struct {
		name        string
		input       string
		wantOK      bool
		wantChunk   int
	}{
		// Happy paths.
		{
			"valid chunk_0",
			"30e28aaf-7c87-4c63-a90e-107ab841cf1f/chunk_0/transcript_abc.json",
			true, 0,
		},
		{
			"valid chunk_3",
			"30e28aaf-7c87-4c63-a90e-107ab841cf1f/chunk_3/transcript_xyz_123.json",
			true, 3,
		},
		{
			"leading slash tolerated (Eventarc payload variant)",
			"/30e28aaf-7c87-4c63-a90e-107ab841cf1f/chunk_0/transcript_a.json",
			true, 0,
		},

		// Rejects — wrong segment count.
		{"empty", "", false, 0},
		{"only session", "30e28aaf-7c87-4c63-a90e-107ab841cf1f", false, 0},
		{"deeply nested", "a/chunk_0/sub/transcript_x.json", false, 0},

		// Rejects — bad session UUID.
		{"non-uuid session", "not-a-uuid/chunk_0/transcript_x.json", false, 0},
		{"truncated uuid", "30e28aaf/chunk_0/transcript_x.json", false, 0},

		// Rejects — bad chunk segment.
		{
			"missing chunk_ prefix",
			"30e28aaf-7c87-4c63-a90e-107ab841cf1f/0/transcript_x.json",
			false, 0,
		},
		{
			"non-numeric chunk index",
			"30e28aaf-7c87-4c63-a90e-107ab841cf1f/chunk_abc/transcript_x.json",
			false, 0,
		},
		{
			"negative chunk index",
			"30e28aaf-7c87-4c63-a90e-107ab841cf1f/chunk_-1/transcript_x.json",
			false, 0,
		},

		// Rejects — bad leaf filename.
		{
			"wrong leaf prefix (metadata sidecar)",
			"30e28aaf-7c87-4c63-a90e-107ab841cf1f/chunk_0/metadata_abc.json",
			false, 0,
		},
		{
			"wrong extension",
			"30e28aaf-7c87-4c63-a90e-107ab841cf1f/chunk_0/transcript_abc.txt",
			false, 0,
		},
		{
			"bare transcript no underscore suffix",
			"30e28aaf-7c87-4c63-a90e-107ab841cf1f/chunk_0/transcript.json",
			// Has the transcript_ prefix? No — "transcript." not "transcript_".
			false, 0,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, ok := ParseOutputObjectPath(tc.input)
			if ok != tc.wantOK {
				t.Fatalf("ParseOutputObjectPath(%q) ok=%v, want %v", tc.input, ok, tc.wantOK)
			}
			if !tc.wantOK {
				return
			}
			if got.ChunkIndex != tc.wantChunk {
				t.Errorf("chunk_index = %d, want %d", got.ChunkIndex, tc.wantChunk)
			}
		})
	}
}

func TestOutputPrefixFor_RoundTripsThroughParse(t *testing.T) {
	// Round-trip property: a prefix written by stt-submit + Chirp's
	// transcript filename appended must parse back to the same
	// (session_id, chunk_index).
	cases := []struct {
		sessionID  string
		chunkIndex int
	}{
		{"30e28aaf-7c87-4c63-a90e-107ab841cf1f", 0},
		{"00000000-0000-0000-0000-000000000001", 7},
	}
	for _, tc := range cases {
		sid := mustUUID(t, tc.sessionID)
		prefix := OutputPrefixFor(sid, tc.chunkIndex)
		full := prefix + "transcript_op_hash.json"
		parsed, ok := ParseOutputObjectPath(full)
		if !ok {
			t.Fatalf("round-trip failed for %q", full)
		}
		if parsed.SessionID != sid || parsed.ChunkIndex != tc.chunkIndex {
			t.Errorf("round-trip mismatch: in=(%s,%d) out=(%s,%d)",
				sid, tc.chunkIndex, parsed.SessionID, parsed.ChunkIndex)
		}
	}
}
