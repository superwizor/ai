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
