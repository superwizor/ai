package storage

import (
	"testing"
	"time"
)

func TestSignedURLTTLFor(t *testing.T) {
	cases := []struct {
		name string
		size int64
		want time.Duration
	}{
		{"unknown size → default", 0, 30 * time.Minute},
		{"tiny upload → default", 1024, 30 * time.Minute},
		{"49 MB → default", 49 * 1024 * 1024, 30 * time.Minute},
		{"50 MB → medium (boundary)", 50 * 1024 * 1024, 2 * time.Hour},
		// Marcin's regression: 111.7 MB = 117_125_120 bytes.
		{"111.7 MB (Marcin's regression) → medium", 117_125_120, 2 * time.Hour},
		{"199 MB → medium", 199 * 1024 * 1024, 2 * time.Hour},
		{"200 MB → large (boundary)", 200 * 1024 * 1024, 4 * time.Hour},
		{"500 MB → large", 500 * 1024 * 1024, 4 * time.Hour},
		{"1 GB → large (capped)", 1024 * 1024 * 1024, 4 * time.Hour},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := signedURLTTLFor(tc.size)
			if got != tc.want {
				t.Errorf("signedURLTTLFor(%d) = %v; want %v",
					tc.size, got, tc.want)
			}
		})
	}
}
