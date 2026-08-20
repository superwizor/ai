package cryptobox

import (
	"errors"
	"testing"
)

func TestGuardMock(t *testing.T) {
	cases := []struct {
		name      string
		kmsKeyURI string
		allowMock bool
		wantErr   bool
	}{
		{"kms set, mock disallowed -> ok (use real kms)", "projects/p/.../k", false, false},
		{"kms set, mock allowed -> ok", "projects/p/.../k", true, false},
		{"kms empty, mock allowed -> ok (dev)", "", true, false},
		{"kms empty, mock disallowed -> fail closed", "", false, true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := GuardMock(c.kmsKeyURI, c.allowMock)
			if c.wantErr {
				if !errors.Is(err, ErrMockNotAllowed) {
					t.Fatalf("want ErrMockNotAllowed, got %v", err)
				}
			} else if err != nil {
				t.Fatalf("want nil, got %v", err)
			}
		})
	}
}
