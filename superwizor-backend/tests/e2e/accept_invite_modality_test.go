//go:build e2e

// Repro for "nurt z ekranu ustawiania hasła nie zapisuje się" —
// AcceptInvitation with default_modality_id must persist it AND
// GetMyProfile must return it (both halves of the bug surface).
package e2e_test

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

func TestAcceptInvitation_PersistsModality(t *testing.T) {
	if os.Getenv("DATABASE_URL") == "" {
		t.Skip("DATABASE_URL not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Minute)
	defer cancel()

	projectID := envOr("GCP_PROJECT_ID", "superwizor-ai-25ecd")
	region := envOr("GCP_REGION", "europe-central2")
	identityURL := os.Getenv("IDENTITY_SVC_URL")
	if identityURL == "" {
		identityURL = describeServiceURL(t, "identity-svc", region, projectID)
	}
	benv := loadBillingEnv(t)
	pool := benv.dbPool

	apiKey := os.Getenv("FIREBASE_API_KEY")
	if apiKey == "" {
		apiKey = autoDetectFirebaseAPIKey(t)
	}
	require.NotEmpty(t, apiKey)

	suffix := uuid.NewString()[:8]

	// Seed: org + inviter + invitation with a token we control.
	orgID := mustSeedOrg(t, ctx, pool, "E2E ModalityRepro "+suffix)
	t.Cleanup(func() { cleanupOrg(t, pool, orgID) })
	inviterID := mustSeedUser(t, ctx, pool, orgID, "e2e-inviter-"+suffix, "e2e-inviter-"+suffix+"@example.com", "ORG_ADMIN")
	_ = inviterID

	raw := make([]byte, 32)
	_, err := rand.Read(raw)
	require.NoError(t, err)
	token := base64.RawURLEncoding.EncodeToString(raw)
	hash := sha256.Sum256([]byte(token))
	_, err = pool.Exec(ctx, `
		INSERT INTO invitations (organization_id, invited_by_user, email, token_hash,
		                         expires_at, invited_role)
		VALUES ($1, $2, $3, $4, now() + interval '7 days', 'THERAPIST')`,
		orgID, inviterID, "e2e-nurt-"+suffix+"@example.com", hash[:])
	require.NoError(t, err)

	var modalityID string
	require.NoError(t, pool.QueryRow(ctx,
		`SELECT id::text FROM modalities LIMIT 1`).Scan(&modalityID))

	// Fresh Firebase TEST user = the invitee.
	sess, err := mintFirebaseSession(ctx, projectID, apiKey,
		"e2e-nurt-"+suffix, "e2e-nurt-"+suffix+"@example.com")
	require.NoError(t, err)
	t.Cleanup(func() { _ = sess.cleanup() })

	conn := dial(t, identityURL, sess.IDToken)
	defer conn.Close()
	identity := identityv1.NewIdentityServiceClient(conn)

	accepted, err := identity.AcceptInvitation(ctx, &identityv1.AcceptInvitationRequest{
		Token:             token,
		FirebaseUid:       sess.UID,
		FirstName:         "Nurt",
		LastName:          "Repro",
		DefaultModalityId: modalityID,
		HasAcceptedTos:    true,
	})
	require.NoError(t, err, "AcceptInvitation")

	// 1) The RPC response itself should carry the modality.
	t.Logf("response default_modality_id = %q", accepted.User.GetDefaultModalityId())

	// 2) DB truth.
	var dbModality *string
	require.NoError(t, pool.QueryRow(ctx,
		`SELECT default_modality_id::text FROM users WHERE firebase_uid = $1`,
		sess.UID).Scan(&dbModality))
	require.NotNil(t, dbModality, "default_modality_id must be persisted by AcceptInvitation")
	require.Equal(t, modalityID, *dbModality)

	// 3) GetMyProfile read path (what the dashboard's onboarding check uses).
	me, err := identity.GetMyProfile(ctx, &emptypb.Empty{})
	require.NoError(t, err, "GetMyProfile")
	require.Equal(t, modalityID, me.GetDefaultModalityId(),
		"GetMyProfile must return the modality chosen on the password screen")

	t.Logf("✓ modality persisted and readable: %s", modalityID)
}
