package sttworker

import "testing"

// TestBucketFromGCSURI codifies the gs:// stripping logic the
// watchdog uses to drive finalize manually after a stuck operation.
// The function is small but a typo here would silently break manual
// recovery — pin it.
func TestBucketFromGCSURI(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{"gs://my-bucket/path/chunk_0/", "my-bucket"},
		{"gs://my-bucket", "my-bucket"},
		{"gs://my-bucket/", "my-bucket"},
		{"gs://a-b-c/d/e/f", "a-b-c"},
		// Defense against malformed inputs — return empty rather than
		// crashing or returning bogus prefixes.
		{"https://my-bucket/foo", ""},
		{"my-bucket/foo", ""},
		{"", ""},
	}
	for _, tc := range cases {
		t.Run(tc.in, func(t *testing.T) {
			got := bucketFromGCSURI(tc.in)
			if got != tc.want {
				t.Errorf("bucketFromGCSURI(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}

func TestStripPrefix(t *testing.T) {
	cases := []struct {
		s, p, want string
	}{
		{"abcdef", "abc", "def"},
		{"transcript_xyz.json", "transcript_", "xyz.json"},
		{"foo", "bar", "foo"},    // no match → unchanged
		{"foo", "foobar", "foo"}, // prefix longer than input → unchanged
		{"", "", ""},
	}
	for _, tc := range cases {
		t.Run(tc.s+"|"+tc.p, func(t *testing.T) {
			got := stripPrefix(tc.s, tc.p)
			if got != tc.want {
				t.Errorf("stripPrefix(%q,%q) = %q, want %q", tc.s, tc.p, got, tc.want)
			}
		})
	}
}

// TestTruncateOpError validates the watchdog's helper for capping
// Chirp error messages we stash in stt_operations.finalize_error.
// Keep DB rows readable.
func TestTruncateOpError(t *testing.T) {
	short := "boom"
	if got := truncateOpError(short); got != short {
		t.Errorf("short message changed: %q", got)
	}

	long := make([]byte, 2048)
	for i := range long {
		long[i] = 'x'
	}
	got := truncateOpError(string(long))
	if len(got) >= 2048 {
		t.Errorf("expected truncation; got len=%d", len(got))
	}
	const suffix = "...(truncated)"
	if got[len(got)-len(suffix):] != suffix {
		t.Errorf("missing truncation suffix: tail=%q", got[len(got)-30:])
	}
}
