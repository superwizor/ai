package storage

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"time"

	credentials "cloud.google.com/go/iam/credentials/apiv1"
	"cloud.google.com/go/iam/credentials/apiv1/credentialspb"
	"cloud.google.com/go/storage"
)

type Signer struct {
	client     *storage.Client
	bucketName string
}

func NewSigner(ctx context.Context, bucketName string) (*Signer, error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("create storage client: %w", err)
	}
	return &Signer{client: client, bucketName: bucketName}, nil
}

// GenerateUploadURL creates a V4 signed URL for PUT operation.
// Returns URL valid for 30 minutes.
func (s *Signer) GenerateUploadURL(ctx context.Context, objectPath, contentType string) (string, time.Time, error) {
	expires := time.Now().Add(30 * time.Minute)

	opts := &storage.SignedURLOptions{
		Scheme:      storage.SigningSchemeV4,
		Method:      http.MethodPut,
		Expires:     expires,
		ContentType: contentType,
		Headers: []string{
			"x-goog-meta-source: superwizor-mobile",
		},
	}

	// Use IAM API to sign bytes if we are running locally without a SA key
	saEmail := os.Getenv("SIGN_URL_SA_EMAIL")
	if saEmail != "" {
		opts.GoogleAccessID = saEmail
		opts.SignBytes = func(b []byte) ([]byte, error) {
			c, err := credentials.NewIamCredentialsClient(ctx)
			if err != nil {
				return nil, err
			}
			defer func() { _ = c.Close() }()
			req := &credentialspb.SignBlobRequest{
				Name:    fmt.Sprintf("projects/-/serviceAccounts/%s", saEmail),
				Payload: b,
			}
			resp, err := c.SignBlob(ctx, req)
			if err != nil {
				return nil, err
			}
			return resp.SignedBlob, nil
		}
	}

	url, err := s.client.Bucket(s.bucketName).SignedURL(objectPath, opts)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("failed to generate signed URL: %w", err)
	}

	return url, expires, nil
}
