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

// signedURLTTLFor picks an expiration window appropriate for an
// estimated upload size. The default 30 min covers ~95% of uploads
// (short sessions on healthy networks), but large files on poor
// connections can easily exceed it — empirically confirmed when
// Marcin's 111.7 MB upload hit HTTP 400 ExpiredToken (2026-05-22).
//
// Even with Flutter's signedUrlExpired classifier handling the
// 400+ExpiredToken body correctly, a longer TTL up-front reduces
// the bandwidth churn from re-issuing URLs + retrying from byte 0.
//
// Thresholds:
//   - default      30 min (existing behavior preserved for small uploads)
//   - >= 50 MB     2 h
//   - >= 200 MB    4 h
//
// Cap at 4 h to keep the leaked-credential blast radius bounded;
// GCS V4 signed URLs allow up to 7 days but we don't need that.
// `estimatedSizeBytes` may be 0 if the caller doesn't know — falls
// back to the default 30 min.
func signedURLTTLFor(estimatedSizeBytes int64) time.Duration {
	const (
		mediumThreshold = 50 * 1024 * 1024  // 50 MB
		largeThreshold  = 200 * 1024 * 1024 // 200 MB
	)
	switch {
	case estimatedSizeBytes >= largeThreshold:
		return 4 * time.Hour
	case estimatedSizeBytes >= mediumThreshold:
		return 2 * time.Hour
	default:
		return 30 * time.Minute
	}
}

// GenerateUploadURL creates a V4 signed URL for PUT operation.
// TTL scales with estimatedSizeBytes — see signedURLTTLFor.
func (s *Signer) GenerateUploadURL(ctx context.Context, objectPath, contentType string, estimatedSizeBytes int64) (string, time.Time, error) {
	expires := time.Now().Add(signedURLTTLFor(estimatedSizeBytes))

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
