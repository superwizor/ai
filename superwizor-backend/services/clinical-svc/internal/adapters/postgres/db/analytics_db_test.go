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
		since := time.Now().AddDate(0, 0, -365)

		// Test each views query method
		_, err := q.GetActivationRate(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetWAU(ctx)
		assert.NoError(t, err)

		_, err = q.GetSessionsThisWeek(ctx)
		assert.NoError(t, err)

		_, err = q.GetOverallSatisfactionRate(ctx, since)
		assert.NoError(t, err)

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

		_, err = q.GetUnitEconomicsKPIs(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetAvgTokenUtilization(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetCostTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetTokenUtilizationHeatmap(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetRevenueTrend(ctx)
		assert.NoError(t, err)

		_, err = q.GetTokenUsageTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetAIQualityKPIs(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetRelabelRate(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetSatisfactionTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetIssueCategories(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetLatencyTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetFailureRateTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetFunnelSteps(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetCohortRetention(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetRetentionCohorts(ctx)
		assert.NoError(t, err)

		_, err = q.GetActivationTimeHistogram(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetHourlyHeatmap(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetUploadFailuresTrend(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetModalityDistribution(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetAvgSessionDuration(ctx, since)
		assert.NoError(t, err)

		_, err = q.GetSessionDurationTrend(ctx, since)
		assert.NoError(t, err)
	})

	// --- 2. Insert mock data and verify views calculations ---
	t.Run("Views aggregate mock data correctly", func(t *testing.T) {
		since := time.Now().AddDate(0, 0, -365)

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
		satisfactionRate, err := q.GetOverallSatisfactionRate(ctx, since)
		require.NoError(t, err)
		assert.True(t, satisfactionRate > 0)

		// Verify new analytics queries output correct aggregates
		modalities, err := q.GetModalityDistribution(ctx, since)
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

		avgDuration, err := q.GetAvgSessionDuration(ctx, since)
		require.NoError(t, err)
		assert.Greater(t, avgDuration, float64(0))

		sinceTrend := time.Now().AddDate(0, 0, -365)
		durationTrend, err := q.GetSessionDurationTrend(ctx, sinceTrend)
		require.NoError(t, err)
		assert.NotEmpty(t, durationTrend)
		assert.Greater(t, durationTrend[0].Value, float64(0))

		// Etykieta tygodnia musi być rokiem ISO + numerem tygodnia ISO
		// (migracja 000101/000102). Maska 'YYYY-IW' mieszała rok kalendarzowy
		// z tygodniem ISO i na przełomie roku sklejała dwa różne tygodnie.
		assert.Regexp(t, `^\d{4}-\d{2}$`, durationTrend[0].Label,
			"etykieta tygodnia powinna mieć format IYYY-IW")

		// Koszt sesji: jeden wiersz na SESJĘ, nie na raport. Regeneracja
		// raportu nie ma prawa doliczyć transkrypcji drugi raz.
		var costRows int
		err = tx.QueryRow(ctx, `
			SELECT count(*)::int FROM v_analytics_session_cost WHERE session_id = $1
		`, sessionID).Scan(&costRows)
		require.NoError(t, err)
		assert.Equal(t, 1, costRows, "widok kosztu ma zwracać jeden wiersz na sesję")

		// Stawka STT bierze się z transcripts.stt_model. Ten transkrypt ma
		// 'chirp-3', którego nie ma w cenniku, więc koszt musi być NULL —
		// nie zero. Zero cicho zaniżyłoby dashboard.
		var sttCost *float64
		err = tx.QueryRow(ctx, `
			SELECT stt_cost_usd::float FROM v_analytics_session_cost WHERE session_id = $1
		`, sessionID).Scan(&sttCost)
		require.NoError(t, err)
		assert.Nil(t, sttCost, "nieznany stt_model ma dawać NULL, nie 0")
	})

	// --- 3. Okno tygodniowe: WAU i sesje muszą pokrywać TE SAME tygodnie ---
	//
	// Regresja na rozjazd, który było widać w panelu: sparkline WAU rysował
	// jedną kropkę obok sparkline'u sesji z dwoma punktami. Powód: GetWauTrend
	// porównywał z `since` POCZĄTEK tygodnia z widoku, a GetSessionsTrend
	// porównuje każdą sesję — więc tydzień, w którym zaczyna się zakres,
	// wypadał z pierwszego, a w drugim zostawał obcięty.
	t.Run("Weekly window covers the same weeks in WAU and sessions", func(t *testing.T) {
		orgID := uuid.New()
		_, err := tx.Exec(ctx, `INSERT INTO organizations (id, legal_name, type) VALUES ($1, $2, 'SOLO')`, orgID, "Week Boundary Org")
		require.NoError(t, err)

		therapistID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO users (id, role, organization_id, firebase_uid, email, first_name, last_name, ui_language, timezone, has_accepted_tos)
			VALUES ($1, 'THERAPIST', $2, $3, $4, 'Week', 'Boundary', 'pl', 'Europe/Warsaw', true)
		`, therapistID, orgID, "fb-week-"+uuid.New().String()[:8], "week-"+uuid.New().String()[:8]+"@przyklad.pl")
		require.NoError(t, err)

		modalityID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO modalities (id, system_code, display_name, therapist_ai_general_prompt, therapist_ai_section_prompts, patient_ai_general_prompt, patient_ai_section_prompts, is_supported, modality_type)
			VALUES ($1, $2, 'Week Boundary', '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, true, 'therapy')
		`, modalityID, "WB_"+uuid.New().String()[:8])
		require.NoError(t, err)

		patientFileID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO patient_files (id, therapist_id, modality_id, working_alias, process_type)
			VALUES ($1, $2, $3, 'Patient WB', 'INDIVIDUAL')
		`, patientFileID, therapistID, modalityID)
		require.NoError(t, err)

		// Dwie sesje po obu stronach granicy tygodnia, zakotwiczone w poniedziałku,
		// żeby wynik nie zależał od dnia uruchomienia testu: sobota poprzedniego
		// tygodnia i poniedziałek bieżącego.
		// session_number jest unikalny w obrębie kartoteki (idx_sessions_patient_file_number).
		for i, offset := range []string{"-2 days", "1 hour"} {
			_, err = tx.Exec(ctx, `
				INSERT INTO sessions (id, therapist_id, patient_file_id, session_date, session_number,
				                      duration_seconds, contact_form, status, created_at)
				VALUES ($1, $2, $3, CURRENT_DATE, $4, 3000, 'ONLINE', 'COMPLETED',
				        date_trunc('week', now() AT TIME ZONE 'Europe/Warsaw') AT TIME ZONE 'Europe/Warsaw' + $5::interval)
			`, uuid.New(), therapistID, patientFileID, i+1, offset)
			require.NoError(t, err)
		}

		// `since` celowo NIE na granicy tygodnia — piątek poprzedniego tygodnia.
		var since time.Time
		err = tx.QueryRow(ctx, `
			SELECT date_trunc('week', now() AT TIME ZONE 'Europe/Warsaw') AT TIME ZONE 'Europe/Warsaw'
			       - interval '3 days'
		`).Scan(&since)
		require.NoError(t, err)

		wau, err := q.GetWauTrend(ctx, since)
		require.NoError(t, err)
		sessions, err := q.GetSessionsTrend(ctx, since)
		require.NoError(t, err)

		weeksOf := func(labels []string) map[string]bool {
			out := map[string]bool{}
			for _, l := range labels {
				out[l] = true
			}
			return out
		}
		var wauLabels, sessionLabels []string
		for _, r := range wau {
			wauLabels = append(wauLabels, r.Label)
		}
		for _, r := range sessions {
			sessionLabels = append(sessionLabels, r.Label)
		}

		assert.Len(t, sessionLabels, 2, "obie sesje leżą po wybranym `since`, więc trend sesji ma dwa tygodnie")
		assert.Equal(t, weeksOf(sessionLabels), weeksOf(wauLabels),
			"WAU i sesje muszą pokrywać ten sam zestaw tygodni — inaczej sparkline'y w kafelkach obok siebie mają różną liczbę punktów")
	})
}
