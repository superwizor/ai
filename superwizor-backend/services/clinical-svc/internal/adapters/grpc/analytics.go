package grpc

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

var clientEventAllowlist = map[string]bool{
	"app.session_started":      true,
	"screen.viewed":            true,
	"report.read_started":      true,
	"report.read_finished":     true,
	"recording.started":        true,
	"recording.stopped":        true,
	"recording.cancelled":      true,
	"file_upload.picked":       true,
	"rating.tapped":            true,
	"suggestion_banner.tapped": true,
	"upload_pill.tapped":       true,
}

// TrackEvents handles client-side batch analytics events.
// It enforces an event name allowlist to guarantee no PHI leaks to the database or BQ.
func (s *Server) TrackEvents(ctx context.Context, req *clinicalv1.TrackEventsRequest) (*clinicalv1.TrackEventsResponse, error) {
	therapistIDStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || therapistIDStr == "" {
		return nil, status.Error(codes.Unauthenticated, "unauthenticated")
	}
	therapistID, err := uuid.Parse(therapistIDStr)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid therapist_id: %v", err)
	}

	var orgIDPtr *uuid.UUID
	orgIDPg, errOrg := s.queries.GetUserOrganizationID(ctx, therapistID)
	if errOrg == nil && orgIDPg.Valid {
		id := uuid.UUID(orgIDPg.Bytes)
		orgIDPtr = &id
	}

	if s.collector == nil && s.pubsub == nil {
		return &clinicalv1.TrackEventsResponse{}, nil
	}

	for _, event := range req.Events {
		if !clientEventAllowlist[event.EventName] {
			slog.WarnContext(ctx, "skipping non-allowlisted client event to prevent PHI leak", "event_name", event.EventName)
			continue
		}

		var sessionIDPtr, patientFileIDPtr, reportIDPtr *uuid.UUID
		var props map[string]any
		if event.Properties != nil {
			props = event.Properties.AsMap()
			if sessVal, ok := props["session_id"].(string); ok && sessVal != "" {
				if id, err := uuid.Parse(sessVal); err == nil {
					sessionIDPtr = &id
				}
			}
			if pfVal, ok := props["patient_file_id"].(string); ok && pfVal != "" {
				if id, err := uuid.Parse(pfVal); err == nil {
					patientFileIDPtr = &id
				}
			}
			if repVal, ok := props["report_id"].(string); ok && repVal != "" {
				if id, err := uuid.Parse(repVal); err == nil {
					reportIDPtr = &id
				}
			}
		}

		occurredAt := time.Now()
		if event.OccurredAt != nil {
			occurredAt = event.OccurredAt.AsTime()
		}

		s.trackEvent(ctx, analytics.Event{
			Name:           event.EventName,
			TherapistID:    &therapistID,
			OrganizationID: orgIDPtr,
			SessionID:      sessionIDPtr,
			PatientFileID:  patientFileIDPtr,
			ReportID:       reportIDPtr,
			Properties:     props,
			Source:         "client",
			ClientPlatform: event.ClientPlatform,
			ClientVersion:  event.ClientVersion,
			OccurredAt:     occurredAt,
		})
	}

	return &clinicalv1.TrackEventsResponse{}, nil
}

// GetAdminAnalytics collects high-level analytics for the admin panel tabs.
func (s *Server) GetAdminAnalytics(ctx context.Context, req *clinicalv1.GetAdminAnalyticsRequest) (*clinicalv1.GetAdminAnalyticsResponse, error) {
	if err := requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}

	since := getStartTimeForRange(req.TimeRange)

	// 1. Executive Overview KPIs
	wau, err := s.queries.GetWAU(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get WAU: %v", err)
	}

	sessionsThisWeek, err := s.queries.GetSessionsThisWeek(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get sessions this week: %v", err)
	}

	activationRate, err := s.queries.GetActivationRate(ctx)
	if err != nil {
		activationRate = 0.0
	}

	satisfactionRate, err := s.queries.GetOverallSatisfactionRate(ctx)
	if err != nil {
		satisfactionRate = 0.0
	}

	// Trends
	wauTrendRows, err := s.queries.GetWauTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get WAU trend: %v", err)
	}
	wauTrend := make([]*clinicalv1.TrendPoint, len(wauTrendRows))
	for i, r := range wauTrendRows {
		wauTrend[i] = &clinicalv1.TrendPoint{Label: r.Label, Value: r.Value}
	}

	sessionsTrendRows, err := s.queries.GetSessionsTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get sessions trend: %v", err)
	}
	sessionsTrend := make([]*clinicalv1.TrendPoint, len(sessionsTrendRows))
	for i, r := range sessionsTrendRows {
		sessionsTrend[i] = &clinicalv1.TrendPoint{Label: r.Label, Value: r.Value}
	}

	registrationsTrendRows, err := s.queries.GetRegistrationsTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get registrations trend: %v", err)
	}
	registrationsTrend := make([]*clinicalv1.TrendPoint, len(registrationsTrendRows))
	for i, r := range registrationsTrendRows {
		registrationsTrend[i] = &clinicalv1.TrendPoint{Label: r.Label, Value: r.Value}
	}

	planDistRows, err := s.queries.GetPlanDistribution(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get plan distribution: %v", err)
	}
	planDistribution := make([]*clinicalv1.PlanDistribution, len(planDistRows))
	for i, r := range planDistRows {
		planDistribution[i] = &clinicalv1.PlanDistribution{PlanName: r.PlanName, Count: r.Count}
	}

	// 2. Unit Economics
	ueRow, err := s.queries.GetUnitEconomicsKPIs(ctx)
	if err != nil {
		ueRow = db.GetUnitEconomicsKPIsRow{}
	}

	avgTokenUtil, err := s.queries.GetAvgTokenUtilization(ctx)
	if err != nil {
		avgTokenUtil = 0.0
	}

	costTrendRows, err := s.queries.GetCostTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get cost trend: %v", err)
	}
	costTrend := make([]*clinicalv1.CostTrendPoint, len(costTrendRows))
	for i, r := range costTrendRows {
		costTrend[i] = &clinicalv1.CostTrendPoint{
			Label:     r.Label,
			SttCost:   r.SttCost,
			LlmCost:   r.LlmCost,
			TotalCost: r.TotalCost,
		}
	}

	tokenUtilHeatmapRows, err := s.queries.GetTokenUtilizationHeatmap(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get token utilization heatmap: %v", err)
	}
	tokenUtilizationHeatmap := make([]*clinicalv1.TokenUtilizationHeatmapPoint, len(tokenUtilHeatmapRows))
	for i, r := range tokenUtilHeatmapRows {
		tokenUtilizationHeatmap[i] = &clinicalv1.TokenUtilizationHeatmapPoint{
			OrgName: r.OrgName,
			Week:    r.Week,
			Value:   r.Value,
		}
	}

	revenueTrendRows, err := s.queries.GetRevenueTrend(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get revenue trend: %v", err)
	}
	revenueTrend := make([]*clinicalv1.RevenueTrendPoint, len(revenueTrendRows))
	for i, r := range revenueTrendRows {
		revenueTrend[i] = &clinicalv1.RevenueTrendPoint{
			Label:        r.Label,
			SoloRevenue:  r.SoloRevenue,
			ProRevenue:   r.ProRevenue,
			TotalRevenue: r.TotalRevenue,
		}
	}

	tokenUsageTrendRows, err := s.queries.GetTokenUsageTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get token usage trend: %v", err)
	}
	tokenUsageTrend := make([]*clinicalv1.TokenUsageTrendPoint, len(tokenUsageTrendRows))
	for i, r := range tokenUsageTrendRows {
		tokenUsageTrend[i] = &clinicalv1.TokenUsageTrendPoint{
			Label:        r.Label,
			InputTokens:  r.InputTokens,
			OutputTokens: r.OutputTokens,
		}
	}

	// 3. AI Quality
	aiRow, err := s.queries.GetAIQualityKPIs(ctx)
	if err != nil {
		aiRow = db.GetAIQualityKPIsRow{}
	}

	relabelRate, err := s.queries.GetRelabelRate(ctx)
	if err != nil {
		relabelRate = 0.0
	}

	satisfactionTrendRows, err := s.queries.GetSatisfactionTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get satisfaction trend: %v", err)
	}
	satisfactionTrend := make([]*clinicalv1.SatisfactionTrendPoint, len(satisfactionTrendRows))
	for i, r := range satisfactionTrendRows {
		satisfactionTrend[i] = &clinicalv1.SatisfactionTrendPoint{
			Label:           r.Label,
			SatisfactionPct: r.SatisfactionPct,
		}
	}

	issueCategoriesRows, err := s.queries.GetIssueCategories(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get issue categories: %v", err)
	}
	issueCategories := make([]*clinicalv1.IssueCategory, len(issueCategoriesRows))
	for i, r := range issueCategoriesRows {
		issueCategories[i] = &clinicalv1.IssueCategory{
			Category: r.Category,
			Count:    r.Count,
		}
	}

	latencyTrendRows, err := s.queries.GetLatencyTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get latency trend: %v", err)
	}
	latencyTrend := make([]*clinicalv1.LatencyTrendPoint, len(latencyTrendRows))
	for i, r := range latencyTrendRows {
		latencyTrend[i] = &clinicalv1.LatencyTrendPoint{
			Label: r.Label,
			P50:   r.P50,
			P95:   r.P95,
		}
	}

	failureRateTrendRows, err := s.queries.GetFailureRateTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get failure rate trend: %v", err)
	}
	failureRateTrend := make([]*clinicalv1.FailureRatePoint, len(failureRateTrendRows))
	for i, r := range failureRateTrendRows {
		failureRateTrend[i] = &clinicalv1.FailureRatePoint{
			Label:       r.Label,
			FailureRate: r.FailureRate,
			Total:       r.Total,
			Failed:      r.Failed,
		}
	}

	// 4. Funnel & Retention
	funnelRow, err := s.queries.GetFunnelSteps(ctx)
	if err != nil {
		funnelRow = db.GetFunnelStepsRow{}
	}

	readReportCount, err := s.queries.GetReadReportCount(ctx)
	if err != nil {
		readReportCount = 0
	}

	cohortRetentionRows, err := s.queries.GetCohortRetention(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get cohort retention: %v", err)
	}
	cohortRetention := make([]*clinicalv1.CohortRetentionPoint, len(cohortRetentionRows))
	for i, r := range cohortRetentionRows {
		cohortRetention[i] = &clinicalv1.CohortRetentionPoint{
			Cohort: r.Cohort,
			Week:   r.Week,
			Pct:    r.Pct,
		}
	}

	// Calculate average 30d (4-week) retention
	var kpi30dRetention float64
	var retentionSum float64
	var retentionCount int
	for _, r := range cohortRetentionRows {
		if weekDiff(r.Cohort, r.Week) == 4 {
			retentionSum += r.Pct
			retentionCount++
		}
	}
	if retentionCount > 0 {
		kpi30dRetention = (retentionSum / float64(retentionCount)) * 100.0
	}

	activationTimeHistogramRows, err := s.queries.GetActivationTimeHistogram(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get activation time histogram: %v", err)
	}
	activationTimeHistogram := make([]*clinicalv1.HistogramBucket, len(activationTimeHistogramRows))
	for i, r := range activationTimeHistogramRows {
		activationTimeHistogram[i] = &clinicalv1.HistogramBucket{
			BucketLabel: r.BucketLabel,
			Count:       r.Count,
		}
	}

	// Funnel steps mapping
	var funnelSteps []*clinicalv1.FunnelStep
	steps := []struct {
		name  string
		count int64
	}{
		{"1. Rejestracja", funnelRow.SignupCount},
		{"2. Utworzenie pacjenta", funnelRow.PatientCreatedCount},
		{"3. Zakończenie sesji", funnelRow.SessionCompletedCount},
		{"4. Przeczytanie raportu", readReportCount},
		{"5. Ocena raportu", funnelRow.RatedCount},
	}
	var prevCount int64 = 0
	for i, st := range steps {
		pct := 100.0
		if i > 0 && prevCount > 0 {
			pct = (float64(st.count) / float64(prevCount)) * 100.0
		}
		funnelSteps = append(funnelSteps, &clinicalv1.FunnelStep{
			StepName:      st.name,
			Count:         st.count,
			PctOfPrevious: pct,
		})
		prevCount = st.count
	}

	// 5. Operations
	hourlyHeatmapRows, err := s.queries.GetHourlyHeatmap(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get hourly heatmap: %v", err)
	}
	hourlyHeatmap := make([]*clinicalv1.HourlyHeatmapPoint, len(hourlyHeatmapRows))
	for i, r := range hourlyHeatmapRows {
		hourlyHeatmap[i] = &clinicalv1.HourlyHeatmapPoint{
			DayOfWeek: r.DayOfWeek,
			Hour:      r.Hour,
			Count:     r.Count,
		}
	}

	uploadFailuresTrendRows, err := s.queries.GetUploadFailuresTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get upload failures trend: %v", err)
	}
	uploadFailuresTrend := make([]*clinicalv1.FailureRatePoint, len(uploadFailuresTrendRows))
	for i, r := range uploadFailuresTrendRows {
		uploadFailuresTrend[i] = &clinicalv1.FailureRatePoint{
			Label:       r.Label,
			FailureRate: r.FailureRate,
			Total:       r.Total,
			Failed:      r.Failed,
		}
	}

	modalityDistRows, err := s.queries.GetModalityDistribution(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get modality distribution: %v", err)
	}
	modalityDistribution := make([]*clinicalv1.ModalityDistribution, len(modalityDistRows))
	for i, r := range modalityDistRows {
		modalityDistribution[i] = &clinicalv1.ModalityDistribution{
			ModalityName: r.ModalityName,
			Count:        r.Count,
		}
	}

	avgDuration, err := s.queries.GetAvgSessionDuration(ctx)
	if err != nil {
		avgDuration = 0.0
	}

	sessionDurationTrendRows, err := s.queries.GetSessionDurationTrend(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get session duration trend: %v", err)
	}
	sessionDurationTrend := make([]*clinicalv1.TrendPoint, len(sessionDurationTrendRows))
	for i, r := range sessionDurationTrendRows {
		sessionDurationTrend[i] = &clinicalv1.TrendPoint{
			Label: r.Label,
			Value: r.Value,
		}
	}

	fixedCostsRows, err := s.queries.GetPlatformFixedCosts(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get platform fixed costs: %v", err)
	}
	platformFixedCosts := make([]*clinicalv1.PlatformFixedCost, len(fixedCostsRows))
	for i, r := range fixedCostsRows {
		platformFixedCosts[i] = &clinicalv1.PlatformFixedCost{
			Id:            r.ID.String(),
			Name:          r.Name,
			Provider:      r.Provider,
			AmountUsd:     r.AmountUsd,
			BillingPeriod: r.BillingPeriod,
		}
	}

	// 6. Report Feedback KPIs
	ratingsKPIs, err := s.queries.GetRatingsKPIs(ctx)
	if err != nil {
		ratingsKPIs = db.GetRatingsKPIsRow{}
	}

	return &clinicalv1.GetAdminAnalyticsResponse{
		KpiWau:                  wau,
		KpiSessionsThisWeek:     sessionsThisWeek,
		KpiActivationRate:       activationRate,
		KpiSatisfactionRate:     satisfactionRate,
		WauTrend:                wauTrend,
		SessionsTrend:           sessionsTrend,
		RegistrationsTrend:      registrationsTrend,
		PlanDistribution:        planDistribution,
		KpiAvgCostPerSession:    ueRow.AvgCostPerSession,
		KpiMonthlySttCost:       ueRow.MonthlySttCost,
		KpiMonthlyLlmCost:       ueRow.MonthlyLlmCost,
		KpiAvgTokenUtilization:  avgTokenUtil,
		CostTrend:               costTrend,
		TokenUtilizationHeatmap: tokenUtilizationHeatmap,
		RevenueTrend:            revenueTrend,
		TokenUsageTrend:         tokenUsageTrend,
		KpiAvgPipelineLatency:   aiRow.AvgPipelineLatency,
		KpiFailureRate_7D:       aiRow.FailureRate7d,
		KpiRelabelRate:          relabelRate,
		SatisfactionTrend:       satisfactionTrend,
		IssueCategories:         issueCategories,
		LatencyTrend:            latencyTrend,
		FailureRateTrend:        failureRateTrend,
		Kpi_30DRetention:        kpi30dRetention,
		FunnelSteps:             funnelSteps,
		CohortRetention:         cohortRetention,
		ActivationTimeHistogram: activationTimeHistogram,
		HourlyHeatmap:           hourlyHeatmap,
		UploadFailuresTrend:     uploadFailuresTrend,
		ModalityDistribution:    modalityDistribution,
		KpiAvgSessionDuration:   avgDuration,
		SessionDurationTrend:    sessionDurationTrend,
		PlatformFixedCosts:      platformFixedCosts,
		KpiRatingsTotal:         ratingsKPIs.Total,
		KpiRatingsPositive:      ratingsKPIs.Positive,
		KpiRatingsNegative:      ratingsKPIs.Negative,
		KpiRatingsWithNotes:     ratingsKPIs.WithNotes,
	}, nil
}

func parseISOWeek(s string) (year, week int) {
	_, _ = fmt.Sscanf(s, "%d-%d", &year, &week)
	return
}

func weekDiff(cohort, week string) int {
	cy, cw := parseISOWeek(cohort)
	wy, ww := parseISOWeek(week)
	return (wy-cy)*52 + (ww - cw)
}

func getStartTimeForRange(timeRange string) time.Time {
	now := time.Now()
	switch timeRange {
	case "7d":
		return now.AddDate(0, 0, -7)
	case "30d":
		return now.AddDate(0, 0, -30)
	case "90d":
		return now.AddDate(0, 0, -90)
	case "12w":
		return now.AddDate(0, 0, -12*7)
	case "24w":
		return now.AddDate(0, 0, -24*7)
	case "52w":
		return now.AddDate(0, 0, -52*7)
	default:
		// Default to 12 weeks
		return now.AddDate(0, 0, -12*7)
	}
}
