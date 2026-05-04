package cryptobox

import (
	"context"
	"strings"
	"testing"
)

func TestMockBox(t *testing.T) {
	box := NewMockBox()
	ctx := context.Background()

	plaintext := []byte("secret clinical data")

	ciphertext, dek, err := box.Encrypt(ctx, plaintext)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if string(dek) != "DEK_PLACEHOLDER" {
		t.Errorf("expected DEK_PLACEHOLDER, got %s", string(dek))
	}

	if !strings.HasPrefix(string(ciphertext), "ENCRYPT_PLACEHOLDER:") {
		t.Errorf("expected ENCRYPT_PLACEHOLDER prefix, got %s", string(ciphertext))
	}

	decrypted, err := box.Decrypt(ctx, ciphertext, dek)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if string(decrypted) != string(plaintext) {
		t.Errorf("expected %s, got %s", string(plaintext), string(decrypted))
	}

	// Test invalid DEK
	_, err = box.Decrypt(ctx, ciphertext, []byte("INVALID_DEK"))
	if err == nil {
		t.Errorf("expected error for invalid DEK, got nil")
	}

	// Test invalid ciphertext
	_, err = box.Decrypt(ctx, []byte("NOT_PLACEHOLDER:something"), dek)
	if err == nil {
		t.Errorf("expected error for invalid ciphertext, got nil")
	}
}
