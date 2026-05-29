package firebase

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"

	"github.com/superwizor-ai/backend/services/identity-svc/internal/domain"
)

type AuthClient struct {
	client *auth.Client
}

func NewAuthClient(ctx context.Context, projectID string) (*AuthClient, error) {
	conf := &firebase.Config{ProjectID: projectID}
	// Use Application Default Credentials. On Cloud Run this resolves
	// via the metadata server to the runtime service account. ADC is
	// needed (vs option.WithoutAuthentication used previously) so
	// CustomToken can sign with the runtime SA's key via the IAM
	// Credentials API. VerifyIDToken doesn't need credentials — it
	// only fetches Google's public JWKS — so the upgrade is strict
	// superset. Local dev needs `gcloud auth application-default
	// login` or a SA JSON via GOOGLE_APPLICATION_CREDENTIALS.
	app, err := firebase.NewApp(ctx, conf)
	if err != nil {
		return nil, fmt.Errorf("init firebase app: %w", err)
	}

	authClient, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("init auth client: %w", err)
	}

	return &AuthClient{client: authClient}, nil
}

// VerifyToken validates Firebase ID token and returns Firebase UID + claims.
func (a *AuthClient) VerifyToken(ctx context.Context, idToken string) (string, map[string]any, error) {
	token, err := a.client.VerifyIDToken(ctx, idToken)
	if err != nil {
		// Firebase SDK returns specific error types
		if auth.IsIDTokenExpired(err) {
			return "", nil, domain.ErrTokenExpired
		}
		return "", nil, domain.ErrInvalidToken
	}

	return token.UID, token.Claims, nil
}

// CustomToken mints a Firebase custom token for the given Firebase UID.
// The receiving origin (Flutter web app) redeems it via
// signInWithCustomToken to establish a Firebase Auth session for the
// same uid. Custom tokens are valid for ~1h.
//
// Implementation note: under the hood the Admin SDK signs the JWT with
// the runtime SA's key. On Cloud Run that means the SA itself needs
// the `roles/iam.serviceAccountTokenCreator` role on itself so the
// signBlob call succeeds (private-key-less signing via IAM Credentials
// API). Verify before deploy.
func (a *AuthClient) CustomToken(ctx context.Context, uid string) (string, error) {
	tok, err := a.client.CustomToken(ctx, uid)
	if err != nil {
		return "", fmt.Errorf("mint custom token: %w", err)
	}
	return tok, nil
}
