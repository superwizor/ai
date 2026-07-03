package grpc

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// GetOrgTherapistMetrics — per-therapist metadata aggregates for the
// ORG_ADMIN analytics tab (docs/38 §7).
//
// Privacy boundary (§7.3, HARD): the response carries counts,
// durations and dates only. No transcript/report/note content and no
// patient identifiers — patient-side metrics are pure cardinalities.
// Same restriction the SUPERWIZOR_ADMIN panel obeys, and the condition
// under which the consent template's "dostęp do materiałów ma
// wyłącznie terapeuta" holds.
//
// Gate: ORG_ADMIN (own org only — resolved from the auth context) or
// SUPERWIZOR_ADMIN. Therapists get PermissionDenied.
func (s *Server) GetOrgTherapistMetrics(ctx context.Context, req *clinicalv1.GetOrgTherapistMetricsRequest) (*clinicalv1.OrgTherapistMetricsResponse, error) {
	role, _ := ctx.Value(UserRoleKey).(string)
	if role != "ORG_ADMIN" && role != "SUPERWIZOR_ADMIN" {
		return nil, status.Error(codes.PermissionDenied,
			"org analytics is available to organization managers only")
	}
	orgIDStr, _ := ctx.Value(OrganizationIDKey).(string)
	if orgIDStr == "" {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	orgID, err := uuid.Parse(orgIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid organization id in context")
	}

	periodDays := req.GetPeriodDays()
	switch periodDays {
	case 7, 30, 90:
	default:
		periodDays = 30
	}
	since := time.Now().AddDate(0, 0, -int(periodDays))

	rows, err := s.queries.GetOrgTherapistMetrics(ctx, db.GetOrgTherapistMetricsParams{
		OrganizationID: pgtype.UUID{Bytes: orgID, Valid: true},
		CreatedAt:      since,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "org metrics query: %v", err)
	}

	resp := &clinicalv1.OrgTherapistMetricsResponse{
		PeriodDays: periodDays,
		Totals:     &clinicalv1.TherapistMetrics{},
	}
	tot := resp.Totals
	for _, r := range rows {
		m := &clinicalv1.TherapistMetrics{
			TherapistId:          r.TherapistID.String(),
			FirstName:            r.FirstName,
			LastName:             r.LastName,
			IsActive:             r.IsActive,
			SessionsCompleted:    r.SessionsCompleted,
			SessionsFailed:       r.SessionsFailed,
			SessionsCancelled:    r.SessionsCancelled,
			TotalDurationSeconds: r.TotalDurationSeconds,
			SessionsReportViewed: r.SessionsReportViewed,
			ActivePatients:       r.ActivePatients,
			NewPatients:          r.NewPatients,
			RatingsPositive:      r.RatingsPositive,
			RatingsNegative:      r.RatingsNegative,
		}
		if r.SessionsCompleted > 0 {
			m.AvgDurationSeconds = int32(r.TotalDurationSeconds / int64(r.SessionsCompleted))
		}
		if r.LastSessionDate.Valid {
			m.LastSessionDate = r.LastSessionDate.Time.Format("2006-01-02")
		}
		resp.Therapists = append(resp.Therapists, m)

		tot.SessionsCompleted += m.SessionsCompleted
		tot.SessionsFailed += m.SessionsFailed
		tot.SessionsCancelled += m.SessionsCancelled
		tot.TotalDurationSeconds += m.TotalDurationSeconds
		tot.SessionsReportViewed += m.SessionsReportViewed
		tot.ActivePatients += m.ActivePatients
		tot.NewPatients += m.NewPatients
		tot.RatingsPositive += m.RatingsPositive
		tot.RatingsNegative += m.RatingsNegative
	}
	if tot.SessionsCompleted > 0 {
		tot.AvgDurationSeconds = int32(tot.TotalDurationSeconds / int64(tot.SessionsCompleted))
	}
	return resp, nil
}

// GetOrgAnalytics — chart data for the /org Analityka tab (docs/38
// §7.2): KPI strip, weekly trends, day×hour heatmap, per-therapist
// token utilization, and the session counts behind the "time saved on
// reporting" KPI (client multiplies by 20 min/session). Same gate and
// §7.3 privacy boundary as GetOrgTherapistMetrics.
func (s *Server) GetOrgAnalytics(ctx context.Context, _ *clinicalv1.GetOrgAnalyticsRequest) (*clinicalv1.GetOrgAnalyticsResponse, error) {
	role, _ := ctx.Value(UserRoleKey).(string)
	if role != "ORG_ADMIN" && role != "SUPERWIZOR_ADMIN" {
		return nil, status.Error(codes.PermissionDenied,
			"org analytics is available to organization managers only")
	}
	orgIDStr, _ := ctx.Value(OrganizationIDKey).(string)
	if orgIDStr == "" {
		return nil, status.Error(codes.FailedPrecondition, "caller has no organization")
	}
	orgID, err := uuid.Parse(orgIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid organization id in context")
	}
	pgOrg := pgtype.UUID{Bytes: orgID, Valid: true}

	kpis, err := s.queries.OrgAnalyticsKPIs(ctx, pgOrg)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "org kpis: %v", err)
	}
	weekly, err := s.queries.OrgWeeklySessionTrend(ctx, pgOrg)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "weekly trend: %v", err)
	}
	heat, err := s.queries.OrgHourlyHeatmap(ctx, pgOrg)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "hourly heatmap: %v", err)
	}
	util, err := s.queries.OrgTherapistUtilization(ctx, orgID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "therapist utilization: %v", err)
	}

	resp := &clinicalv1.GetOrgAnalyticsResponse{
		KpiWau:                int64(kpis.KpiWau),
		KpiSessionsThisWeek:   int64(kpis.KpiSessionsThisWeek),
		KpiAvgSessionDuration: kpis.KpiAvgSessionDuration,
		SessionsThisMonth:     int64(kpis.SessionsThisMonth),
		SessionsThisYear:      int64(kpis.SessionsThisYear),
	}
	for _, w := range weekly {
		resp.SessionsTrend = append(resp.SessionsTrend,
			&clinicalv1.TrendPoint{Label: w.Week, Value: float64(w.Sessions)})
		resp.WauTrend = append(resp.WauTrend,
			&clinicalv1.TrendPoint{Label: w.Week, Value: float64(w.ActiveTherapists)})
		resp.SessionDurationTrend = append(resp.SessionDurationTrend,
			&clinicalv1.TrendPoint{Label: w.Week, Value: w.AvgDurationMin})
	}
	for _, h := range heat {
		resp.HourlyHeatmap = append(resp.HourlyHeatmap, &clinicalv1.HourlyHeatmapPoint{
			DayOfWeek: h.DayOfWeek,
			Hour:      h.Hour,
			Count:     h.Count,
		})
	}
	for _, u := range util {
		resp.TherapistUtilization = append(resp.TherapistUtilization,
			&clinicalv1.TokenUtilizationHeatmapPoint{
				OrgName: u.TherapistName,
				Week:    u.Week,
				Value:   u.Value,
			})
	}
	return resp, nil
}
