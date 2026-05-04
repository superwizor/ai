package cryptobox

import (
	"context"
	"fmt"
	"strings"
)

// MockBox provides a fake implementation of CryptoBox for testing and local dev.
type MockBox struct{}

func NewMockBox() CryptoBox {
	return &MockBox{}
}

func (m *MockBox) Encrypt(ctx context.Context, plaintext []byte) ([]byte, []byte, error) {
	// W testach doklejamy po prostu prefix do oryginalnego teksu
	ciphertext := []byte("ENCRYPT_PLACEHOLDER:" + string(plaintext))
	encryptedDEK := []byte("DEK_PLACEHOLDER")
	return ciphertext, encryptedDEK, nil
}

func (m *MockBox) Decrypt(ctx context.Context, ciphertext []byte, encryptedDEK []byte) ([]byte, error) {
	if string(encryptedDEK) != "DEK_PLACEHOLDER" {
		return nil, fmt.Errorf("invalid mock DEK")
	}
	cipherStr := string(ciphertext)
	if !strings.HasPrefix(cipherStr, "ENCRYPT_PLACEHOLDER:") {
		return nil, fmt.Errorf("invalid mock ciphertext prefix")
	}
	plaintext := strings.TrimPrefix(cipherStr, "ENCRYPT_PLACEHOLDER:")
	return []byte(plaintext), nil
}
