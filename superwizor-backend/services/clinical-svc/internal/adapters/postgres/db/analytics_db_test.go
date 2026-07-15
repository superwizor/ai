package db

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIntegration_AnalyticsViews(t *testing.T) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		t.Skip("Skipping DB integration test: DATABASE_URL is not set")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	require.NoError(t, err)
	defer pool.Close()

	// Begin a transaction to ensure zero-pollution and isolated runs
	tx, err := pool.Begin(ctx)
	require.NoError(t, err)
	defer func() {
		_ = tx.Rollback(ctx)
	}()

	q := New(tx)

	// --- 1. Test Querying Views on Empty/Existing Database (Ensure NO division-by-zero crashes) ---
	t.Run("Views query without errors on empty or existing database", func(t *testing.T) {
		// Test each views query method
		_, err := q.GetActivationRate(ctx)
		assert.NoError(t, err)

		_, err = q.GetWAU(ctx)
		assert.NoError(t, err)

		_, err = q.GetSessionsThisWeek(ctx)
		assert.NoError(t, err)

		_, err = q.GetOverallSatisfactionRate(ctx)
		assert.NoError(t, err)

		since := time.Now().AddDate(0, 0, -365)

		_, err = q.GetWauTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetSessionsTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetRegistrationsTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetRegistrationsDetail(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetPlanDistribution(ctx)
		assert.NoError(t, err)

		_, err = q.GetUnitEconomicsKPIs(ctx)
		assert.NoError(t, err)

		_, err = q.GetAvgTokenUtilization(ctx)
		assert.NoError(t, err)

		_, err = q.GetCostTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetTokenUtilizationHeatmap(ctx)
		assert.NoError(t, err)

		_, err = q.GetRevenueTrend(ctx)
		assert.NoError(t, err)

		_, err = q.GetTokenUsageTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetAIQualityKPIs(ctx)
		assert.NoError(t, err)

		_, err = q.GetRelabelRate(ctx)
		assert.NoError(t, err)

		_, err = q.GetSatisfactionTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetIssueCategories(ctx)
		assert.NoError(t, err)

		_, err = q.GetLatencyTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetFailureRateTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetFunnelSteps(ctx)
		assert.NoError(t, err)

		_, err = q.GetReadReportCount(ctx)
		assert.NoError(t, err)

		_, err = q.GetCohortRetention(ctx)
		assert.NoError(t, err)

		_, err = q.GetActivationTimeHistogram(ctx)
		assert.NoError(t, err)

		_, err = q.GetHourlyHeatmap(ctx)
		assert.NoError(t, err)

		_, err = q.GetUploadFailuresTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetModalityDistribution(ctx)
		assert.NoError(t, err)

		_, err = q.GetAvgSessionDuration(ctx)
		assert.NoError(t, err)

		_, err = q.GetSessionDurationTrend(ctx, since)
		assert.NoError(t, err)
	})

	// --- 2. Insert mock data and verify views calculations ---
	t.Run("Views aggregate mock data correctly", func(t *testing.T) {
		initialWAU, err := q.GetWAU(ctx)
		require.NoError(t, err)

		// Create mock organization
		orgID := uuid.New()
		_, err = tx.Exec(ctx, `INSERT INTO organizations (id, legal_name, type) VALUES ($1, $2, 'SOLO')`, orgID, "Test Org")
		require.NoError(t, err)

		// Create mock therapist user
		therapistID := uuid.New()
		firebaseUID := "fb-uid-" + uuid.New().String()[:8]
		email := "therapist-" + uuid.New().String()[:8] + "@superwizor.ai"
		_, err = tx.Exec(ctx, `
			INSERT INTO users (id, role, organization_id, firebase_uid, email, first_name, last_name, ui_language, timezone, has_accepted_tos)
			VALUES ($1, 'THERAPIST', $2, $3, $4, 'Test', 'Therapist', 'pl', 'Europe/Warsaw', true)
		`, therapistID, orgID, firebaseUID, email)
		require.NoError(t, err)

		// Create mock modality
		modalityID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO modalities (id, system_code, display_name, therapist_ai_general_prompt, therapist_ai_section_prompts, patient_ai_general_prompt, patient_ai_section_prompts, is_supported, modality_type)
			VALUES ($1, $2, $3, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, true, 'therapy')
		`, modalityID, "CBT_TEST_"+uuid.New().String()[:8], "CBT Test")
		require.NoError(t, err)

		// Create mock patient file
		patientFileID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO patient_files (id, therapist_id, modality_id, working_alias, process_type)
			VALUES ($1, $2, $3, 'Patient A', 'INDIVIDUAL')
		`, patientFileID, therapistID, modalityID)
		require.NoError(t, err)

		// Create mock completed session
		sessionID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO sessions (id, therapist_id, patient_file_id, session_date, session_number, duration_seconds, contact_form, status)
			VALUES ($1, $2, $3, CURRENT_DATE, 1, 3000, 'ONLINE', 'COMPLETED')
		`, sessionID, therapistID, patientFileID)
		require.NoError(t, err)

		// Verify WAU incremented
		newWAU, err := q.GetWAU(ctx)
		require.NoError(t, err)
		assert.Equal(t, initialWAU+1, newWAU)

		// Insert report rating
		ratingID := uuid.New()
		reportID := uuid.New()
		transcriptID := uuid.New()
		
		// Create mock transcript
		_, err = tx.Exec(ctx, `
			INSERT INTO transcripts (id, session_id, language_code, stt_model, transcript_ciphertext, transcript_encrypted_dek)
			VALUES ($1, $2, 'pl-PL', 'chirp-3', '\x00', '\x00')
		`, transcriptID, sessionID)
		require.NoError(t, err)

		// Create mock report
		_, err = tx.Exec(ctx, `
			INSERT INTO reports (id, session_id, transcript_id, modality_id, report_ciphertext, report_encrypted_dek, llm_model, llm_input_tokens, llm_output_tokens, llm_total_cost_usd)
			VALUES ($1, $2, $3, $4, '\x00', '\x00', 'gemini-2.5-pro', 1000, 500, 0.025)
		`, reportID, sessionID, transcriptID, modalityID)
		require.NoError(t, err)

		_, err = tx.Exec(ctx, `
			INSERT INTO report_ratings (id, report_id, therapist_id, rating, issues, notes, source)
			VALUES ($1, $2, $3, 'positive', '{}', 'Great report', 'web')
		`, ratingID, reportID, therapistID)
		require.NoError(t, err)

		// Verify satisfaction view returns valid satisfactionRate
		satisfactionRate, err := q.GetOverallSatisfactionRate(ctx)
		require.NoError(t, err)
		assert.True(t, satisfactionRate > 0)

		// Verify new analytics queries output correct aggregates
		modalities, err := q.GetModalityDistribution(ctx)
		require.NoError(t, err)
		
		var found bool
		for _, m := range modalities {
			if m.ModalityName == "CBT Test" {
				assert.Equal(t, int64(1), m.Count)
				found = true
				break
			}
		}
		assert.True(t, found, "CBT Test modality should be present in distribution")

		avgDuration, err := q.GetAvgSessionDuration(ctx)
		require.NoError(t, err)
		assert.Greater(t, avgDuration, float64(0))

		sinceTrend := time.Now().AddDate(0, 0, -365)
		durationTrend, err := q.GetSessionDurationTrend(ctx, sinceTrend)
		require.NoError(t, err)
		assert.NotEmpty(t, durationTrend)
		assert.Greater(t, durationTrend[0].Value, float64(0))
	})
}
