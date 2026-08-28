package grpc

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/structpb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// TestClientEventAllowlist verifies that only designated client events
// are allowlisted to prevent PHI leakage.
func TestClientEventAllowlist(t *testing.T) {
	allowlisted := []string{
		"app.session_started",
		"screen.viewed",
		"report.read_started",
		"report.read_finished",
		"recording.started",
		"recording.stopped",
		"recording.cancelled",
		"file_upload.picked",
		"rating.tapped",
		"suggestion_banner.tapped",
		"upload_pill.tapped",
	}

	for _, name := range allowlisted {
		if !clientEventAllowlist[name] {
			t.Errorf("expected event %q to be allowlisted", name)
		}
	}

	blocked := []string{
		"therapist.password_changed",
		"patient.details_viewed",
		"transcript.raw_text_copied",
		"random_event",
	}

	for _, name := range blocked {
		if clientEventAllowlist[name] {
			t.Errorf("expected event %q to be blocked from allowlist", name)
		}
	}
}

// TestGetAdminAnalytics_RoleGate asserts that only users with the
// SUPERWIZOR_ADMIN role can query admin metrics.
func TestGetAdminAnalytics_RoleGate(t *testing.T) {
	// 1. Unauthenticated (no role)
	{
		s := &Server{}
		_, err := s.GetAdminAnalytics(context.Background(), &clinicalv1.GetAdminAnalyticsRequest{TimeRange: "12w"})
		if err == nil {
			t.Fatal("expected error for unauthenticated call")
		}
		if status.Code(err) != codes.Unauthenticated {
			t.Errorf("expected Unauthenticated, got %v", status.Code(err))
		}
	}

	// 2. Unauthorized role (e.g. THERAPIST)
	{
		s := &Server{}
		ctx := context.WithValue(context.Background(), UserRoleKey, "THERAPIST")
		_, err := s.GetAdminAnalytics(ctx, &clinicalv1.GetAdminAnalyticsRequest{TimeRange: "12w"})
		if err == nil {
			t.Fatal("expected error for unauthorized role")
		}
		if status.Code(err) != codes.PermissionDenied {
			t.Errorf("expected PermissionDenied, got %v", status.Code(err))
		}
	}

	// 3. Authorized role (SUPERWIZOR_ADMIN) - will pass auth gate and fail on database query (since queries are nil),
	// which verifies it successfully bypassed requireSuperwizorAdmin check.
	{
		s := &Server{}
		ctx := context.WithValue(context.Background(), UserRoleKey, "SUPERWIZOR_ADMIN")

		var panicked bool
		func() {
			defer func() {
				if r := recover(); r != nil {
					panicked = true
				}
			}()
			_, _ = s.GetAdminAnalytics(ctx, &clinicalv1.GetAdminAnalyticsRequest{TimeRange: "12w"})
		}()

		if !panicked {
			t.Fatal("expected query execution panic (nil s.queries), got nil")
		}
	}
}

type fakeAnalyticsQuerier struct {
	db.Querier
	sharingTrend []db.GetClientSharingTrendRow
	sharingErr   error
	funnelErr    error
	reading      db.GetReportReadingStatsRow
}

func (q *fakeAnalyticsQuerier) GetWAU(ctx context.Context) (int64, error) { return 10, nil }
func (q *fakeAnalyticsQuerier) GetSessionsThisWeek(ctx context.Context) (int64, error) {
	return 42, nil
}
func (q *fakeAnalyticsQuerier) GetActivationRate(ctx context.Context, since time.Time) (float64, error) {
	return 12.5, nil
}
func (q *fakeAnalyticsQuerier) GetOverallSatisfactionRate(ctx context.Context, since time.Time) (float64, error) {
	return 95.0, nil
}
func (q *fakeAnalyticsQuerier) GetWauTrend(ctx context.Context, since time.Time) ([]db.GetWauTrendRow, error) {
	return []db.GetWauTrendRow{{Label: "2026-01", Value: 10.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetSessionsTrend(ctx context.Context, since time.Time) ([]db.GetSessionsTrendRow, error) {
	return []db.GetSessionsTrendRow{{Label: "2026-01", Value: 42.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetRegistrationsTrend(ctx context.Context, since time.Time) ([]db.GetRegistrationsTrendRow, error) {
	return []db.GetRegistrationsTrendRow{{Label: "2026-01", Value: 5.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetRegistrationsDetail(ctx context.Context, since time.Time) ([]db.GetRegistrationsDetailRow, error) {
	emailVal := "therapist@example.com"
	return []db.GetRegistrationsDetailRow{
		{
			ID:                  uuid.New(),
			Email:               &emailVal,
			FirstName:           "John",
			LastName:            "Doe",
			CreatedAt:           time.Now(),
			LoginCount:          5,
			SessionCount:        10,
			HasMarketingConsent: true,
		},
	}, nil
}
func (q *fakeAnalyticsQuerier) GetPlanDistribution(ctx context.Context) ([]db.GetPlanDistributionRow, error) {
	return []db.GetPlanDistributionRow{{PlanName: "Mistrzostwo", Count: 3}}, nil
}
func (q *fakeAnalyticsQuerier) GetUnitEconomicsKPIs(ctx context.Context, since time.Time) (db.GetUnitEconomicsKPIsRow, error) {
	return db.GetUnitEconomicsKPIsRow{AvgCostPerSession: 0.05, PeriodSttCost: 1.2, PeriodLlmCost: 3.4}, nil
}
func (q *fakeAnalyticsQuerier) GetAvgTokenUtilization(ctx context.Context, since time.Time) (float64, error) {
	return 75.5, nil
}
func (q *fakeAnalyticsQuerier) GetCostTrend(ctx context.Context, since time.Time) ([]db.GetCostTrendRow, error) {
	return []db.GetCostTrendRow{{Label: "2026-01", SttCost: 0.01, LlmCost: 0.04, TotalCost: 0.05}}, nil
}
func (q *fakeAnalyticsQuerier) GetTokenUtilizationHeatmap(ctx context.Context, since time.Time) ([]db.GetTokenUtilizationHeatmapRow, error) {
	return []db.GetTokenUtilizationHeatmapRow{{OrgName: "Org 1", Week: "2026-01", Value: 80.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetRevenueTrend(ctx context.Context) ([]db.GetRevenueTrendRow, error) {
	return []db.GetRevenueTrendRow{{Label: "Poznanie", SoloRevenue: 100.0, ProRevenue: 200.0, TotalRevenue: 300.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetTokenUsageTrend(ctx context.Context, since time.Time) ([]db.GetTokenUsageTrendRow, error) {
	return []db.GetTokenUsageTrendRow{{Label: "2026-01", InputTokens: 1000, OutputTokens: 500}}, nil
}
func (q *fakeAnalyticsQuerier) GetAIQualityKPIs(ctx context.Context, since time.Time) (db.GetAIQualityKPIsRow, error) {
	return db.GetAIQualityKPIsRow{AvgPipelineLatency: 120.0, FailureRate7d: 1.0}, nil
}
func (q *fakeAnalyticsQuerier) GetRelabelRate(ctx context.Context, since time.Time) (float64, error) { return 5.0, nil }
func (q *fakeAnalyticsQuerier) GetSatisfactionTrend(ctx context.Context, since time.Time) ([]db.GetSatisfactionTrendRow, error) {
	return []db.GetSatisfactionTrendRow{{Label: "2026-01", SatisfactionPct: 95.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetIssueCategories(ctx context.Context, since time.Time) ([]db.GetIssueCategoriesRow, error) {
	return []db.GetIssueCategoriesRow{{Category: "Diaryzacja", Count: 2}}, nil
}
func (q *fakeAnalyticsQuerier) GetLatencyTrend(ctx context.Context, since time.Time) ([]db.GetLatencyTrendRow, error) {
	return []db.GetLatencyTrendRow{{Label: "2026-01", P50: 100.0, P95: 200.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetFailureRateTrend(ctx context.Context, since time.Time) ([]db.GetFailureRateTrendRow, error) {
	return []db.GetFailureRateTrendRow{{Label: "2026-01", FailureRate: 1.0, Total: 100, Failed: 1}}, nil
}
func (q *fakeAnalyticsQuerier) GetFunnelSteps(ctx context.Context, since time.Time) (db.GetFunnelStepsRow, error) {
	return db.GetFunnelStepsRow{SignupCount: 10, PatientCreatedCount: 8, SessionCompletedCount: 5, ReportReadCount: 5, RatedCount: 4}, nil
}
func (q *fakeAnalyticsQuerier) GetCohortRetention(ctx context.Context, since time.Time) ([]db.GetCohortRetentionRow, error) {
	// Procenty 0-100, tak jak zwraca SQL od migracji 000101/000102.
	return []db.GetCohortRetentionRow{{Cohort: "2026-19", Week: "2026-20", Pct: 50.0}}, nil
}

// Kohorta z tygodnia 19 liczaca 4 osoby, z ktorych 1 wrocila w tygodniu +4
// (2026-23). Wazona retencja = 25%.
func (q *fakeAnalyticsQuerier) GetRetentionCohorts(ctx context.Context) ([]db.GetRetentionCohortsRow, error) {
	return []db.GetRetentionCohortsRow{
		{Cohort: "2026-19", Week: "2026-19", Pct: 100.0, CohortSize: 4},
		{Cohort: "2026-19", Week: "2026-23", Pct: 25.0, CohortSize: 4},
	}, nil
}
func (q *fakeAnalyticsQuerier) GetActivationTimeHistogram(ctx context.Context, since time.Time) ([]db.GetActivationTimeHistogramRow, error) {
	return []db.GetActivationTimeHistogramRow{{BucketLabel: "0-1h", Count: 5}}, nil
}
func (q *fakeAnalyticsQuerier) GetHourlyHeatmap(ctx context.Context, since time.Time) ([]db.GetHourlyHeatmapRow, error) {
	return []db.GetHourlyHeatmapRow{{DayOfWeek: 1, Hour: 12, Count: 3}}, nil
}
func (q *fakeAnalyticsQuerier) GetUploadFailuresTrend(ctx context.Context, since time.Time) ([]db.GetUploadFailuresTrendRow, error) {
	return []db.GetUploadFailuresTrendRow{{Label: "2026-01", FailureRate: 2.0, Total: 50, Failed: 1}}, nil
}
func (q *fakeAnalyticsQuerier) GetModalityDistribution(ctx context.Context, since time.Time) ([]db.GetModalityDistributionRow, error) {
	return []db.GetModalityDistributionRow{{ModalityName: "CBT", Count: 8}}, nil
}
func (q *fakeAnalyticsQuerier) GetAvgSessionDuration(ctx context.Context, since time.Time) (float64, error) {
	return 2400.0, nil
}
func (q *fakeAnalyticsQuerier) GetSessionDurationTrend(ctx context.Context, since time.Time) ([]db.GetSessionDurationTrendRow, error) {
	return []db.GetSessionDurationTrendRow{{Label: "2026-01", Value: 2400.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetPlatformFixedCosts(ctx context.Context) ([]db.GetPlatformFixedCostsRow, error) {
	return []db.GetPlatformFixedCostsRow{
		{
			ID:            uuid.MustParse("00000000-0000-0000-0000-000000000001"),
			Name:          "Test Cost",
			Provider:      "GCP",
			AmountUsd:     12.34,
			BillingPeriod: "monthly",
		},
	}, nil
}
func (q *fakeAnalyticsQuerier) GetRatingsKPIs(ctx context.Context, since time.Time) (db.GetRatingsKPIsRow, error) {
	return db.GetRatingsKPIsRow{Total: 42, Positive: 38, Negative: 4, WithNotes: 6}, nil
}

func TestGetAdminAnalytics_Success(t *testing.T) {
	s := &Server{
		queries: &fakeAnalyticsQuerier{},
	}

	ctx := context.WithValue(context.Background(), UserRoleKey, "SUPERWIZOR_ADMIN")
	resp, err := s.GetAdminAnalytics(ctx, &clinicalv1.GetAdminAnalyticsRequest{TimeRange: "12w"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}

	if resp.KpiWau != 10 {
		t.Errorf("expected KpiWau 10, got %d", resp.KpiWau)
	}
	if resp.KpiSessionsThisWeek != 42 {
		t.Errorf("expected KpiSessionsThisWeek 42, got %d", resp.KpiSessionsThisWeek)
	}
	if resp.KpiActivationRate != 12.5 {
		t.Errorf("expected KpiActivationRate 12.5, got %f", resp.KpiActivationRate)
	}
	if resp.KpiSatisfactionRate != 95.0 {
		t.Errorf("expected KpiSatisfactionRate 95.0, got %f", resp.KpiSatisfactionRate)
	}
	if resp.KpiAvgSessionDuration != 2400.0 {
		t.Errorf("expected KpiAvgSessionDuration 2400.0, got %f", resp.KpiAvgSessionDuration)
	}
	if len(resp.ModalityDistribution) != 1 || resp.ModalityDistribution[0].ModalityName != "CBT" || resp.ModalityDistribution[0].Count != 8 {
		t.Errorf("unexpected ModalityDistribution: %+v", resp.ModalityDistribution)
	}
	if len(resp.SessionDurationTrend) != 1 || resp.SessionDurationTrend[0].Label != "2026-01" || resp.SessionDurationTrend[0].Value != 2400.0 {
		t.Errorf("unexpected SessionDurationTrend: %+v", resp.SessionDurationTrend)
	}
	if len(resp.PlatformFixedCosts) != 1 || resp.PlatformFixedCosts[0].Name != "Test Cost" || resp.PlatformFixedCosts[0].AmountUsd != 12.34 {
		t.Errorf("unexpected PlatformFixedCosts: %+v", resp.PlatformFixedCosts)
	}

	// Lejek: pięć kroków, wszystkie z JEDNEGO zapytania. Krok 4 pochodził
	// kiedyś z osobnego zapytania po gołej tabeli zdarzeń, na innej populacji,
	// przez co lejek mógł się rozszerzać. Sprawdzamy monotoniczność.
	if len(resp.FunnelSteps) != 5 {
		t.Fatalf("expected 5 funnel steps, got %d", len(resp.FunnelSteps))
	}
	wantCounts := []int64{10, 8, 5, 5, 4}
	for i, st := range resp.FunnelSteps {
		if st.Count != wantCounts[i] {
			t.Errorf("funnel step %d (%s): expected %d, got %d", i+1, st.StepName, wantCounts[i], st.Count)
		}
		if i > 0 && st.Count > resp.FunnelSteps[i-1].Count {
			t.Errorf("funnel widened at step %d (%s): %d > %d",
				i+1, st.StepName, st.Count, resp.FunnelSteps[i-1].Count)
		}
	}

	// Retencja 30-dniowa idzie z GetRetentionCohorts (stałe okno), nie
	// z macierzy ciętej selektorem. Kohorta 4-osobowa z 25% w tygodniu +4
	// daje ważone 25%; wynik w procentach, nie w ułamku.
	if resp.Kpi_30DRetention != 25.0 {
		t.Errorf("expected Kpi_30DRetention 25.0, got %f", resp.Kpi_30DRetention)
	}
}

func TestTrackEvents_DualWrite(t *testing.T) {
	// Setup test IDs
	therapistID := uuid.New()
	orgID := uuid.New()
	sessionID := uuid.New()
	patientFileID := uuid.New()
	reportID := uuid.New()

	// Setup mock querier
	q := &fakeQuerier{
		getUserOrganizationIDFn: func(ctx context.Context, id uuid.UUID) (pgtype.UUID, error) {
			if id == therapistID {
				return pgtype.UUID{Bytes: orgID, Valid: true}, nil
			}
			return pgtype.UUID{}, nil
		},
	}

	// Setup fake publisher
	pub := &fakePublisher{}

	// Setup server
	s := NewServerWithDeps(q, nil, nil, nil, nil, pub, "test-1.0", nil)

	// Context with UserIDKey
	ctx := context.WithValue(context.Background(), UserIDKey, therapistID.String())

	// Build structpb Properties
	props, err := structpb.NewStruct(map[string]any{
		"session_id":      sessionID.String(),
		"patient_file_id": patientFileID.String(),
		"report_id":       reportID.String(),
		"custom_prop":     "value",
	})
	if err != nil {
		t.Fatalf("failed to create properties struct: %v", err)
	}

	occurredAt := time.Now().Truncate(time.Second)

	req := &clinicalv1.TrackEventsRequest{
		Events: []*clinicalv1.ClientEvent{
			{
				EventName:      "app.session_started", // Allowlisted
				Properties:     props,
				OccurredAt:     timestamppb.New(occurredAt),
				ClientPlatform: "ios",
				ClientVersion:  "1.0.0",
			},
			{
				EventName:      "patient.details_viewed", // Blocked
				Properties:     props,
				OccurredAt:     timestamppb.New(occurredAt),
				ClientPlatform: "ios",
				ClientVersion:  "1.0.0",
			},
		},
	}

	resp, err := s.TrackEvents(ctx, req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}

	// Verify that the allowlisted event was published
	if len(pub.analyticsEvents) != 1 {
		t.Fatalf("expected exactly 1 published analytics event, got %d", len(pub.analyticsEvents))
	}

	evt := pub.analyticsEvents[0]
	if evt.Name != "app.session_started" {
		t.Errorf("expected event name 'app.session_started', got %q", evt.Name)
	}
	if evt.TherapistID == nil || *evt.TherapistID != therapistID {
		t.Errorf("expected TherapistID %s, got %v", therapistID, evt.TherapistID)
	}
	if evt.OrganizationID == nil || *evt.OrganizationID != orgID {
		t.Errorf("expected OrganizationID %s, got %v", orgID, evt.OrganizationID)
	}
	if evt.SessionID == nil || *evt.SessionID != sessionID {
		t.Errorf("expected SessionID %s, got %v", sessionID, evt.SessionID)
	}
	if evt.PatientFileID == nil || *evt.PatientFileID != patientFileID {
		t.Errorf("expected PatientFileID %s, got %v", patientFileID, evt.PatientFileID)
	}
	if evt.ReportID == nil || *evt.ReportID != reportID {
		t.Errorf("expected ReportID %s, got %v", reportID, evt.ReportID)
	}
	if evt.ClientPlatform != "ios" {
		t.Errorf("expected ClientPlatform 'ios', got %q", evt.ClientPlatform)
	}
	if evt.ClientVersion != "1.0.0" {
		t.Errorf("expected ClientVersion '1.0.0', got %q", evt.ClientVersion)
	}
	if !evt.OccurredAt.Equal(occurredAt) {
		t.Errorf("expected OccurredAt %v, got %v", occurredAt, evt.OccurredAt)
	}
	if evt.Source != "client" {
		t.Errorf("expected Source 'client', got %q", evt.Source)
	}
}

// Metody zakładek "Użycie" i "Pętla z klientem". Atrapa ma pusty embed
// db.Querier, więc bez tych implementacji handler wywala się na nil
// pointerze zamiast pokazać brak danych.
//
// Zwracają pustkę z nil-error, czyli realny stan "jeszcze nic nie ma".
// Ścieżkę błędu pokrywa osobny test niżej.
func (f *fakeAnalyticsQuerier) GetClientSharingTrend(ctx context.Context, since time.Time) ([]db.GetClientSharingTrendRow, error) {
	return f.sharingTrend, f.sharingErr
}

func (f *fakeAnalyticsQuerier) GetClientInvitationFunnel(ctx context.Context, since time.Time) (db.GetClientInvitationFunnelRow, error) {
	return db.GetClientInvitationFunnelRow{}, f.funnelErr
}

func (f *fakeAnalyticsQuerier) GetPairingCodeFriction(ctx context.Context, since time.Time) ([]db.GetPairingCodeFrictionRow, error) {
	return nil, nil
}

func (f *fakeAnalyticsQuerier) GetReportReadingStats(ctx context.Context, since time.Time) (db.GetReportReadingStatsRow, error) {
	return f.reading, nil
}

func (f *fakeAnalyticsQuerier) GetReadingPlatformSplit(ctx context.Context, since time.Time) ([]db.GetReadingPlatformSplitRow, error) {
	return nil, nil
}

// Awaria pojedynczej metryki nie może wywrócić całego pulpitu.
//
// Pulpit ma sześć zakładek i ~30 wykresów zasilanych niezależnymi
// zapytaniami. Gdyby jedno z nich propagowało błąd, admin zobaczyłby
// pustą stronę zamiast 29 działających wykresów — a właśnie wtedy,
// gdy coś jest nie tak, panel jest najbardziej potrzebny.
func TestGetAdminAnalytics_JednaAwariaNieWywracaPulpitu(t *testing.T) {
	q := &fakeAnalyticsQuerier{
		sharingErr: errors.New("celowa awaria zapytania o udostepnienia"),
		funnelErr:  errors.New("celowa awaria lejka zaproszen"),
	}
	s := &Server{queries: q}

	ctx := context.WithValue(context.Background(), UserRoleKey, "SUPERWIZOR_ADMIN")
	resp, err := s.GetAdminAnalytics(ctx, &clinicalv1.GetAdminAnalyticsRequest{TimeRange: "12w"})
	if err != nil {
		t.Fatalf("awaria jednej metryki wywrocila caly pulpit: %v", err)
	}
	if resp == nil {
		t.Fatal("brak odpowiedzi")
	}
	// Sekcja z awarią pokazuje pustkę, nie błąd.
	if len(resp.ClientSharingTrend) != 0 {
		t.Errorf("oczekiwano pustej serii po awarii, jest %d punktow", len(resp.ClientSharingTrend))
	}
	if resp.ClientInvitationFunnel == nil {
		t.Error("lejek musi byc niepusty (zerowy), a nie nil — front nie sprawdza nil")
	}
}
