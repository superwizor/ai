package cryptobox

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"fmt"
	"hash/crc32"
	"io"

	kms "cloud.google.com/go/kms/apiv1"
	"cloud.google.com/go/kms/apiv1/kmspb"
	"google.golang.org/protobuf/types/known/wrapperspb"
)

// CryptoBox provides envelope encryption using Google Cloud KMS.
type CryptoBox interface {
	Encrypt(ctx context.Context, plaintext []byte) (ciphertext []byte, encryptedDEK []byte, err error)
	Decrypt(ctx context.Context, ciphertext []byte, encryptedDEK []byte) (plaintext []byte, err error)
}

type cloudKMSBox struct {
	client *kms.KeyManagementClient
	keyURI string // e.g., projects/.../locations/.../keyRings/.../cryptoKeys/...
}

// NewCloudKMSBox creates a new CryptoBox backed by Google Cloud KMS
func NewCloudKMSBox(client *kms.KeyManagementClient, keyURI string) CryptoBox {
	return &cloudKMSBox{
		client: client,
		keyURI: keyURI,
	}
}

func (c *cloudKMSBox) Encrypt(ctx context.Context, plaintext []byte) ([]byte, []byte, error) {
	// 1. Generate local DEK (32 bytes for AES-256)
	dek := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, dek); err != nil {
		return nil, nil, fmt.Errorf("failed to generate dek: %w", err)
	}

	// 2. Encrypt DEK with KMS KEK
	crc32c := func(data []byte) uint32 {
		t := crc32.MakeTable(crc32.Castagnoli)
		return crc32.Checksum(data, t)
	}
	
	req := &kmspb.EncryptRequest{
		Name:            c.keyURI,
		Plaintext:       dek,
		PlaintextCrc32C: wrapperspb.Int64(int64(crc32c(dek))),
	}

	resp, err := c.client.Encrypt(ctx, req)
	if err != nil {
		return nil, nil, fmt.Errorf("kms encrypt dek: %w", err)
	}
	if !resp.VerifiedPlaintextCrc32C {
		return nil, nil, fmt.Errorf("kms encrypt: request corrupted in-transit")
	}
	if int64(crc32c(resp.Ciphertext)) != resp.CiphertextCrc32C.Value {
		return nil, nil, fmt.Errorf("kms encrypt: response corrupted in-transit")
	}

	encryptedDEK := resp.Ciphertext

	// 3. Encrypt data with DEK using AES-GCM
	block, err := aes.NewCipher(dek)
	if err != nil {
		return nil, nil, fmt.Errorf("aes new cipher: %w", err)
	}
	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, nil, fmt.Errorf("cipher new gcm: %w", err)
	}
	nonce := make([]byte, aesgcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, nil, fmt.Errorf("generate nonce: %w", err)
	}

	ciphertext := aesgcm.Seal(nonce, nonce, plaintext, nil)

	// Clean up DEK from memory (best effort)
	for i := range dek {
		dek[i] = 0
	}

	return ciphertext, encryptedDEK, nil
}

func (c *cloudKMSBox) Decrypt(ctx context.Context, ciphertext []byte, encryptedDEK []byte) ([]byte, error) {
	// 1. Decrypt DEK with KMS KEK
	crc32c := func(data []byte) uint32 {
		t := crc32.MakeTable(crc32.Castagnoli)
		return crc32.Checksum(data, t)
	}

	req := &kmspb.DecryptRequest{
		Name:             c.keyURI,
		Ciphertext:       encryptedDEK,
		CiphertextCrc32C: wrapperspb.Int64(int64(crc32c(encryptedDEK))),
	}

	resp, err := c.client.Decrypt(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("kms decrypt dek: %w", err)
	}
	if int64(crc32c(resp.Plaintext)) != resp.PlaintextCrc32C.Value {
		return nil, fmt.Errorf("kms decrypt: response corrupted in-transit")
	}

	dek := resp.Plaintext

	// 2. Decrypt data with DEK using AES-GCM
	block, err := aes.NewCipher(dek)
	if err != nil {
		return nil, fmt.Errorf("aes new cipher: %w", err)
	}
	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("cipher new gcm: %w", err)
	}

	nonceSize := aesgcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, fmt.Errorf("ciphertext too short")
	}
	nonce, cipherBody := ciphertext[:nonceSize], ciphertext[nonceSize:]

	plaintext, err := aesgcm.Open(nil, nonce, cipherBody, nil)
	if err != nil {
		return nil, fmt.Errorf("aesgcm open: %w", err)
	}

	// Clean up DEK from memory
	for i := range dek {
		dek[i] = 0
	}

	return plaintext, nil
}
