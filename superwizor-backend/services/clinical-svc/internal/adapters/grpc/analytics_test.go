package grpc

import (
	"context"
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
}

func (q *fakeAnalyticsQuerier) GetWAU(ctx context.Context) (int64, error) { return 10, nil }
func (q *fakeAnalyticsQuerier) GetSessionsThisWeek(ctx context.Context) (int64, error) { return 42, nil }
func (q *fakeAnalyticsQuerier) GetActivationRate(ctx context.Context) (float64, error) { return 12.5, nil }
func (q *fakeAnalyticsQuerier) GetOverallSatisfactionRate(ctx context.Context) (float64, error) { return 95.0, nil }
func (q *fakeAnalyticsQuerier) GetWauTrend(ctx context.Context, since time.Time) ([]db.GetWauTrendRow, error) {
	return []db.GetWauTrendRow{{Label: "2026-01", Value: 10.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetSessionsTrend(ctx context.Context, since time.Time) ([]db.GetSessionsTrendRow, error) {
	return []db.GetSessionsTrendRow{{Label: "2026-01", Value: 42.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetRegistrationsTrend(ctx context.Context, since time.Time) ([]db.GetRegistrationsTrendRow, error) {
	return []db.GetRegistrationsTrendRow{{Label: "2026-01", Value: 5.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetPlanDistribution(ctx context.Context) ([]db.GetPlanDistributionRow, error) {
	return []db.GetPlanDistributionRow{{PlanName: "Mistrzostwo", Count: 3}}, nil
}
func (q *fakeAnalyticsQuerier) GetUnitEconomicsKPIs(ctx context.Context) (db.GetUnitEconomicsKPIsRow, error) {
	return db.GetUnitEconomicsKPIsRow{AvgCostPerSession: 0.05, MonthlySttCost: 1.2, MonthlyLlmCost: 3.4}, nil
}
func (q *fakeAnalyticsQuerier) GetAvgTokenUtilization(ctx context.Context) (float64, error) { return 75.5, nil }
func (q *fakeAnalyticsQuerier) GetCostTrend(ctx context.Context, since time.Time) ([]db.GetCostTrendRow, error) {
	return []db.GetCostTrendRow{{Label: "2026-01", SttCost: 0.01, LlmCost: 0.04, TotalCost: 0.05}}, nil
}
func (q *fakeAnalyticsQuerier) GetTokenUtilizationHeatmap(ctx context.Context) ([]db.GetTokenUtilizationHeatmapRow, error) {
	return []db.GetTokenUtilizationHeatmapRow{{OrgName: "Org 1", Week: "2026-01", Value: 80.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetRevenueTrend(ctx context.Context) ([]db.GetRevenueTrendRow, error) {
	return []db.GetRevenueTrendRow{{Label: "Poznanie", SoloRevenue: 100.0, ProRevenue: 200.0, TotalRevenue: 300.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetTokenUsageTrend(ctx context.Context, since time.Time) ([]db.GetTokenUsageTrendRow, error) {
	return []db.GetTokenUsageTrendRow{{Label: "2026-01", InputTokens: 1000, OutputTokens: 500}}, nil
}
func (q *fakeAnalyticsQuerier) GetAIQualityKPIs(ctx context.Context) (db.GetAIQualityKPIsRow, error) {
	return db.GetAIQualityKPIsRow{AvgPipelineLatency: 120.0, FailureRate7d: 0.01}, nil
}
func (q *fakeAnalyticsQuerier) GetRelabelRate(ctx context.Context) (float64, error) { return 0.05, nil }
func (q *fakeAnalyticsQuerier) GetSatisfactionTrend(ctx context.Context, since time.Time) ([]db.GetSatisfactionTrendRow, error) {
	return []db.GetSatisfactionTrendRow{{Label: "2026-01", SatisfactionPct: 95.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetIssueCategories(ctx context.Context) ([]db.GetIssueCategoriesRow, error) {
	return []db.GetIssueCategoriesRow{{Category: "Diaryzacja", Count: 2}}, nil
}
func (q *fakeAnalyticsQuerier) GetLatencyTrend(ctx context.Context, since time.Time) ([]db.GetLatencyTrendRow, error) {
	return []db.GetLatencyTrendRow{{Label: "2026-01", P50: 100.0, P95: 200.0}}, nil
}
func (q *fakeAnalyticsQuerier) GetFailureRateTrend(ctx context.Context, since time.Time) ([]db.GetFailureRateTrendRow, error) {
	return []db.GetFailureRateTrendRow{{Label: "2026-01", FailureRate: 0.01, Total: 100, Failed: 1}}, nil
}
func (q *fakeAnalyticsQuerier) GetFunnelSteps(ctx context.Context) (db.GetFunnelStepsRow, error) {
	return db.GetFunnelStepsRow{SignupCount: 10, PatientCreatedCount: 8, SessionCompletedCount: 5, RatedCount: 4}, nil
}
func (q *fakeAnalyticsQuerier) GetReadReportCount(ctx context.Context) (int64, error) { return 4, nil }
func (q *fakeAnalyticsQuerier) GetCohortRetention(ctx context.Context) ([]db.GetCohortRetentionRow, error) {
	return []db.GetCohortRetentionRow{{Cohort: "2026-19", Week: "2026-20", Pct: 0.5}}, nil
}
func (q *fakeAnalyticsQuerier) GetActivationTimeHistogram(ctx context.Context) ([]db.GetActivationTimeHistogramRow, error) {
	return []db.GetActivationTimeHistogramRow{{BucketLabel: "0-1h", Count: 5}}, nil
}
func (q *fakeAnalyticsQuerier) GetHourlyHeatmap(ctx context.Context) ([]db.GetHourlyHeatmapRow, error) {
	return []db.GetHourlyHeatmapRow{{DayOfWeek: 1, Hour: 12, Count: 3}}, nil
}
func (q *fakeAnalyticsQuerier) GetUploadFailuresTrend(ctx context.Context, since time.Time) ([]db.GetUploadFailuresTrendRow, error) {
	return []db.GetUploadFailuresTrendRow{{Label: "2026-01", FailureRate: 0.02, Total: 50, Failed: 1}}, nil
}
func (q *fakeAnalyticsQuerier) GetModalityDistribution(ctx context.Context) ([]db.GetModalityDistributionRow, error) {
	return []db.GetModalityDistributionRow{{ModalityName: "CBT", Count: 8}}, nil
}
func (q *fakeAnalyticsQuerier) GetAvgSessionDuration(ctx context.Context) (float64, error) { return 2400.0, nil }
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
