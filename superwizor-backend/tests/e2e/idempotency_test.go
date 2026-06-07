//go:build e2e
// +build e2e

package e2e_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
)

// TestIdempotency_CommitUsage validates that CommitUsage (or IncrementUsage) is idempotent
// and does not charge tokens twice for the same session.
func TestIdempotency_CommitUsage(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)
	t.Cleanup(func() { env.resetCounter(t) })

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	// Call 1: Commit 10-minute session usage (should consume 1 token)
	t.Log("Sending first CommitUsage request...")
	res1, err := c.CommitUsage(ctx, &billingv1.CommitUsageRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		DurationSeconds: 600, // 10 minutes
		UsageType:       "session_analysis",
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), res1.TokensConsumed)

	// Call 2: Retry same CommitUsage request
	t.Log("Retrying same CommitUsage request (idempotency check)...")
	res2, err := c.CommitUsage(ctx, &billingv1.CommitUsageRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		DurationSeconds: 600,
		UsageType:       "session_analysis",
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), res2.TokensConsumed)

	// Verify DB state: exactly one usage event exists for this session
	var eventCount int
	err = env.dbPool.QueryRow(ctx, `
		SELECT COUNT(*) FROM usage_events WHERE session_id = $1`,
		sessionID).Scan(&eventCount)
	require.NoError(t, err)
	assert.Equal(t, 1, eventCount)

	// Verify DB state: organization's tokens_used is exactly 1
	var tokensUsed int32
	err = env.dbPool.QueryRow(ctx, `
		SELECT tokens_used FROM usage_counters 
		WHERE subscription_id IN (
			SELECT id FROM subscriptions WHERE organization_id = $1 AND status = 'ACTIVE'
		)
		AND period_start <= now() AND period_end > now()`,
		env.orgID).Scan(&tokensUsed)
	require.NoError(t, err)
	assert.Equal(t, int32(1), tokensUsed)
}

// TestIdempotency_CreateAudioUpload validates that CreateAudioUpload in ingestion-svc is idempotent
// and does not create duplicate sessions or audio upload rows when retried.
func TestIdempotency_CreateAudioUpload(t *testing.T) {
	cfg := loadConfig(t)
	env := loadBillingEnv(t) // for DB pool access

	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("idemp_uid_%d", runID)
	firebaseEmail := fmt.Sprintf("idemp_%d@example.com", runID)
	idempotencyKey := fmt.Sprintf("idemp-upload-key-%d", runID)

	t.Logf("══════════════════════════════════════════════════════════════")
	t.Logf("  E2E CreateAudioUpload Idempotency Test")
	t.Logf("  Run ID: %d", runID)
	t.Logf("══════════════════════════════════════════════════════════════")

	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer tokenCancel()
	fbSession, err := mintFirebaseSession(tokenCtx, cfg.projectID, cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
	require.NoError(t, err, "mint Firebase token")
	t.Cleanup(func() { _ = fbSession.cleanup() })

	identityConn := dial(t, cfg.identityURL, fbSession.IDToken)
	t.Cleanup(func() { _ = identityConn.Close() })
	clinicalConn := dial(t, cfg.clinicalURL, fbSession.IDToken)
	t.Cleanup(func() { _ = clinicalConn.Close() })
	ingestionConn := dial(t, cfg.ingestionURL, fbSession.IDToken)
	t.Cleanup(func() { _ = ingestionConn.Close() })

	identityClient := identityv1.NewIdentityServiceClient(identityConn)
	clinicalClient := clinicalv1.NewClinicalServiceClient(clinicalConn)
	ingestionClient := ingestionv1.NewIngestionServiceClient(ingestionConn)

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	// 1. Create therapist
	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid:    firebaseUID,
		Email:          firebaseEmail,
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName:      "Idemp",
		LastName:       "Therapist",
		UiLanguage:     "pl",
		Timezone:       "Europe/Warsaw",
		HasAcceptedTos: true,
	})
	require.NoError(t, err, "CreateUser")

	// 2. Create patient file
	patient, err := clinicalClient.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId:         therapist.Id,
		ModalityCode:        "CBT",
		WorkingAlias:        fmt.Sprintf("Idemp Patient %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("idemp-patient-key-%d", runID),
		PatientFirstName:    "Idemp",
		PatientLastName:     "Patient",
		PatientLanguageCode: "pl",
	})
	require.NoError(t, err, "CreatePatientFile")
	t.Cleanup(func() {
		bgCtx, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgCancel()
		_, _ = clinicalClient.DeletePatientFile(bgCtx, &clinicalv1.DeletePatientFileRequest{PatientFileId: patient.Id})
	})

	patientUUID := uuid.MustParse(patient.Id)

	// 3. Call CreateAudioUpload (Call 1)
	t.Log("Sending first CreateAudioUpload request...")
	upload1, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId:              therapist.Id,
		PatientFileId:            patient.Id,
		ContentType:              "audio/flac",
		EstimatedSizeBytes:       100_000,
		EstimatedDurationSeconds: 60,
		IdempotencyKey:           idempotencyKey,
		ClientAppVersion:         "e2e-idemp-1.0",
		ClientPlatform:           "test",
	})
	require.NoError(t, err)
	require.NotEmpty(t, upload1.SessionId)
	require.NotEmpty(t, upload1.UploadId)

	sessionUUID := uuid.MustParse(upload1.SessionId)
	t.Cleanup(func() {
		bgCtx, bgCancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer bgCancel()
		_, _ = env.dbPool.Exec(bgCtx, `DELETE FROM pending_reservations WHERE session_id = $1`, sessionUUID)
		_, _ = env.dbPool.Exec(bgCtx, `DELETE FROM audio_uploads WHERE session_id = $1`, sessionUUID)
		_, _ = env.dbPool.Exec(bgCtx, `DELETE FROM sessions WHERE id = $1`, sessionUUID)
	})

	// 4. Call CreateAudioUpload (Call 2) with exact same idempotency key
	t.Log("Retrying CreateAudioUpload request (idempotency check)...")
	upload2, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId:              therapist.Id,
		PatientFileId:            patient.Id,
		ContentType:              "audio/flac",
		EstimatedSizeBytes:       100_000,
		EstimatedDurationSeconds: 60,
		IdempotencyKey:           idempotencyKey,
		ClientAppVersion:         "e2e-idemp-1.0",
		ClientPlatform:           "test",
	})
	require.NoError(t, err)

	// Both calls must return identical IDs
	assert.Equal(t, upload1.SessionId, upload2.SessionId)
	assert.Equal(t, upload1.UploadId, upload2.UploadId)

	// Verify only one session was created in DB
	var sessionCount int
	err = env.dbPool.QueryRow(ctx, `
		SELECT COUNT(*) FROM sessions WHERE patient_file_id = $1`,
		patientUUID).Scan(&sessionCount)
	require.NoError(t, err)
	assert.Equal(t, 1, sessionCount)

	// Verify only one audio upload was created in DB
	var uploadCount int
	err = env.dbPool.QueryRow(ctx, `
		SELECT COUNT(*) FROM audio_uploads WHERE session_id = $1`,
		sessionUUID).Scan(&uploadCount)
	require.NoError(t, err)
	assert.Equal(t, 1, uploadCount)
}
