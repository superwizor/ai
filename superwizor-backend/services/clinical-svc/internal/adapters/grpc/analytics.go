package grpc

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

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

	activationRate, err := s.queries.GetActivationRate(ctx, since)
	if err != nil {
		activationRate = 0.0
	}

	satisfactionRate, err := s.queries.GetOverallSatisfactionRate(ctx, since)
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

	registrationsDetailRows, err := s.queries.GetRegistrationsDetail(ctx, since)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get registrations detail: %v", err)
	}
	registrationsDetail := make([]*clinicalv1.RegisteredUserDetail, len(registrationsDetailRows))
	for i, r := range registrationsDetailRows {
		emailStr := ""
		if r.Email != nil {
			emailStr = *r.Email
		}
		registrationsDetail[i] = &clinicalv1.RegisteredUserDetail{
			UserId:              r.ID.String(),
			Email:               emailStr,
			FirstName:           r.FirstName,
			LastName:            r.LastName,
			CreatedAt:           timestamppb.New(r.CreatedAt),
			LoginCount:          r.LoginCount,
			SessionCount:        r.SessionCount,
			HasMarketingConsent: r.HasMarketingConsent,
		}
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
	ueRow, err := s.queries.GetUnitEconomicsKPIs(ctx, since)
	if err != nil {
		ueRow = db.GetUnitEconomicsKPIsRow{}
	}

	avgTokenUtil, err := s.queries.GetAvgTokenUtilization(ctx, since)
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

	tokenUtilHeatmapRows, err := s.queries.GetTokenUtilizationHeatmap(ctx, since)
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

	// Fail-soft: migawka MRR nie jest renderowana przez panel, więc jej
	// awaria nie ma prawa wywracać całego Centrum Analitycznego.
	revenueTrendRows, err := s.queries.GetRevenueTrend(ctx)
	if err != nil {
		slog.WarnContext(ctx, "analytics: revenue trend failed (fail-soft)", "error", err)
		revenueTrendRows = nil
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
	aiRow, err := s.queries.GetAIQualityKPIs(ctx, since)
	if err != nil {
		aiRow = db.GetAIQualityKPIsRow{}
	}

	relabelRate, err := s.queries.GetRelabelRate(ctx, since)
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

	issueCategoriesRows, err := s.queries.GetIssueCategories(ctx, since)
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
	funnelRow, err := s.queries.GetFunnelSteps(ctx, since)
	if err != nil {
		funnelRow = db.GetFunnelStepsRow{}
	}

	cohortRetentionRows, err := s.queries.GetCohortRetention(ctx, since)
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

	// KPI retencji liczymy z osobnego zapytania o stalym oknie. Przy zakresie
	// „7 dni" macierz powyzej nie zawiera ANI JEDNEJ dojrzalej kohorty, wiec
	// wyliczony z niej wskaznik bylby zerem udajacym pomiar.
	var kpi30dRetention float64
	if retentionRows, err := s.queries.GetRetentionCohorts(ctx); err != nil {
		slog.WarnContext(ctx, "analytics: retention cohorts failed (fail-soft)", "error", err)
	} else {
		kpi30dRetention = retention30d(retentionRows, time.Now())
	}

	activationTimeHistogramRows, err := s.queries.GetActivationTimeHistogram(ctx, since)
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
		{"4. Przeczytanie raportu", funnelRow.ReportReadCount},
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
	hourlyHeatmapRows, err := s.queries.GetHourlyHeatmap(ctx, since)
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

	modalityDistRows, err := s.queries.GetModalityDistribution(ctx, since)
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

	avgDuration, err := s.queries.GetAvgSessionDuration(ctx, since)
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
	ratingsKPIs, err := s.queries.GetRatingsKPIs(ctx, since)
	if err != nil {
		ratingsKPIs = db.GetRatingsKPIsRow{}
	}

	// ── Użycie i pętla z klientem (14.08.2026) ──────────────────────
	//
	// Wszystkie pięć zapytań jest fail-soft: pojedyncza awaria nie może
	// wywrócić całego pulpitu, bo reszta metryk jest niezależna. Panel
	// pokaże wtedy zera w tej sekcji, a nie błąd na całej stronie.
	var sharingTrend []*clinicalv1.ClientSharingPoint
	if rows, err := s.queries.GetClientSharingTrend(ctx, since); err == nil {
		for _, r := range rows {
			sharingTrend = append(sharingTrend, &clinicalv1.ClientSharingPoint{
				Label:         r.Label,
				SessionsTotal: int64(r.SessionsTotal),
				Shared:        int64(r.Shared),
				Hidden:        int64(r.Hidden),
			})
		}
	} else {
		slog.WarnContext(ctx, "analytics: client sharing trend failed (fail-soft)", "error", err)
	}

	inviteFunnel := &clinicalv1.ClientInvitationFunnel{}
	if f, err := s.queries.GetClientInvitationFunnel(ctx, since); err == nil {
		inviteFunnel = &clinicalv1.ClientInvitationFunnel{
			Sent:                int64(f.Sent),
			Accepted:            int64(f.Accepted),
			Revoked:             int64(f.Revoked),
			Expired:             int64(f.Expired),
			MedianHoursToAccept: f.MedianHoursToAccept,
		}
	} else {
		slog.WarnContext(ctx, "analytics: invitation funnel failed (fail-soft)", "error", err)
	}

	var pairing []*clinicalv1.PairingAttemptBucket
	if rows, err := s.queries.GetPairingCodeFriction(ctx, since); err == nil {
		for _, r := range rows {
			pairing = append(pairing, &clinicalv1.PairingAttemptBucket{
				Attempts:    r.Attempts,
				Invitations: int64(r.Invitations),
			})
		}
	} else {
		slog.WarnContext(ctx, "analytics: pairing friction failed (fail-soft)", "error", err)
	}

	reading := &clinicalv1.ReportReadingStats{}
	if r, err := s.queries.GetReportReadingStats(ctx, since); err == nil {
		reading = &clinicalv1.ReportReadingStats{
			Started:       int64(r.Started),
			Finished:      int64(r.Finished),
			MedianSeconds: r.MedianSeconds,
			P90Seconds:    r.P90Seconds,
		}
	} else {
		slog.WarnContext(ctx, "analytics: reading stats failed (fail-soft)", "error", err)
	}

	var platforms []*clinicalv1.PlatformReads
	if rows, err := s.queries.GetReadingPlatformSplit(ctx, since); err == nil {
		for _, r := range rows {
			platforms = append(platforms, &clinicalv1.PlatformReads{
				Platform: r.Platform,
				Reads:    int64(r.Reads),
			})
		}
	} else {
		slog.WarnContext(ctx, "analytics: platform split failed (fail-soft)", "error", err)
	}

	return &clinicalv1.GetAdminAnalyticsResponse{
		KpiWau:               wau,
		KpiSessionsThisWeek:  sessionsThisWeek,
		KpiActivationRate:    activationRate,
		KpiSatisfactionRate:  satisfactionRate,
		WauTrend:             wauTrend,
		SessionsTrend:        sessionsTrend,
		RegistrationsTrend:   registrationsTrend,
		PlanDistribution:     planDistribution,
		KpiAvgCostPerSession: ueRow.AvgCostPerSession,
		// Nazwy pól proto (`kpi_monthly_*`) są historyczne: te kafelki liczyły
		// zaszyte 30 dni, a od tej zmiany idą z wybranego zakresu. Pola nie są
		// przemianowane celowo — numer pola trzyma zgodność wsteczną, a etykieta
		// widoczna dla użytkownika mówi już „w wybranym okresie".
		KpiMonthlySttCost:       ueRow.PeriodSttCost,
		KpiMonthlyLlmCost:       ueRow.PeriodLlmCost,
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
		RegistrationsDetail:     registrationsDetail,

		ClientSharingTrend:     sharingTrend,
		ClientInvitationFunnel: inviteFunnel,
		PairingAttempts:        pairing,
		ReportReading:          reading,
		ReadingPlatforms:       platforms,
	}, nil
}

// parseISOWeek rozkłada etykietę 'IYYY-IW' (np. "2026-34") na rok i numer
// tygodnia ISO. Zwraca ok=false dla wszystkiego, co nie jest taką etykietą —
// poprzednia wersja ignorowała błąd Sscanf i cicho zwracała (0, 0), przez co
// zepsuta etykieta wyglądała jak tydzień 0 roku 0 i wchodziła do rachunków.
func parseISOWeek(s string) (year, week int, ok bool) {
	n, err := fmt.Sscanf(s, "%d-%d", &year, &week)
	if err != nil || n != 2 {
		return 0, 0, false
	}
	if week < 1 || week > 53 {
		return 0, 0, false
	}
	return year, week, true
}

// isoWeekStart zwraca poniedziałek tygodnia (year, week) kalendarza ISO.
// Kotwicą jest 4 stycznia, który z definicji leży w tygodniu 1 danego roku ISO.
func isoWeekStart(year, week int) time.Time {
	jan4 := time.Date(year, time.January, 4, 0, 0, 0, 0, time.UTC)
	weekday := int(jan4.Weekday()) // niedziela = 0
	if weekday == 0 {
		weekday = 7
	}
	firstMonday := jan4.AddDate(0, 0, -(weekday - 1))
	return firstMonday.AddDate(0, 0, (week-1)*7)
}

// weekDiff liczy odległość w tygodniach między dwiema etykietami ISO.
//
// Poprzednia wersja robiła (wy-cy)*52 + (ww-cw), co zakłada 52 tygodnie w
// każdym roku. Rok ISO ma 52 ALBO 53 tygodnie (2026 ma 53), więc dla kohort
// przechodzących przez przełom roku punkt „+4 tygodnie" wskazywał zły tydzień.
// Liczymy więc po prawdziwych datach początków tygodni.
func weekDiff(cohort, week string) (int, bool) {
	cy, cw, ok := parseISOWeek(cohort)
	if !ok {
		return 0, false
	}
	wy, ww, ok := parseISOWeek(week)
	if !ok {
		return 0, false
	}
	delta := isoWeekStart(wy, ww).Sub(isoWeekStart(cy, cw))
	return int(delta.Hours() / (24 * 7)), true
}

// retention30d liczy KPI „Retencja 30-dniowa": jaki odsetek terapeutów jest
// nadal aktywny cztery tygodnie po rejestracji.
//
// Dwie rzeczy, które poprzednia wersja robiła źle i które są tu naprawione:
//
//   - WAGA. Było AVG po kohortach, więc kohorta jednoosobowa ze 100% ważyła
//     tyle samo, co pięćdziesięcioosobowa z 10%. Teraz to średnia ważona
//     liczebnością kohorty, czyli po prostu „ilu z ilu".
//
//   - KOHORTY ZEROWE. Kohorta bez ANI JEDNEJ aktywnej osoby w tygodniu +4 nie
//     ma wiersza w wyniku SQL, więc wypadała z mianownika i podbijała wynik.
//     Teraz kohorta dostatecznie stara, żeby jej tydzień +4 już minął, wchodzi
//     do rachunku z zerem, jeśli nie ma dla niej wiersza.
//
// `now` jest parametrem, żeby test nie zależał od dnia uruchomienia.
func retention30d(rows []db.GetRetentionCohortsRow, now time.Time) float64 {
	type cohort struct {
		size    int64
		pctAt4W float64
		mature  bool
	}
	cohorts := map[string]*cohort{}

	for _, r := range rows {
		cy, cw, ok := parseISOWeek(r.Cohort)
		if !ok {
			continue
		}
		c, seen := cohorts[r.Cohort]
		if !seen {
			// Tydzień +4 tej kohorty musi już się skończyć, inaczej brak
			// aktywności znaczy „jeszcze nie wiadomo", a nie „nie wrócili".
			endOfWeek4 := isoWeekStart(cy, cw).AddDate(0, 0, 5*7)
			c = &cohort{size: r.CohortSize, mature: !endOfWeek4.After(now)}
			cohorts[r.Cohort] = c
		}
		if d, ok := weekDiff(r.Cohort, r.Week); ok && d == 4 {
			c.pctAt4W = r.Pct
		}
	}

	var weighted, total float64
	for _, c := range cohorts {
		if !c.mature || c.size <= 0 {
			continue
		}
		weighted += c.pctAt4W * float64(c.size)
		total += float64(c.size)
	}
	if total == 0 {
		return 0
	}
	return weighted / total
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
