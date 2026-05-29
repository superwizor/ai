// AdminListSessions — cross-org session activity for the
// /admin/sessions page on superwizor.web.app. SUPERWIZOR_ADMIN only.
//
// Filters AND-combine: created_at window, free-text on therapist
// name + email. Pagination is offset-based; the handler reads
// page_limit+1 rows so it can return has_more without a COUNT(*).
//
// Role gate reads x-superwizor-role from ctx (populated by the
// existing ConnectAuthInterceptor and UnaryAuthInterceptor) — no
// extra DB hop. Tokens whose role isn't SUPERWIZOR_ADMIN get
// PermissionDenied.

package grpc

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

const (
	// adminSessionsDefaultPageSize is what the handler picks when the
	// request leaves page_size at zero. Matches the UI's first-load
	// page size on the /admin/sessions table.
	adminSessionsDefaultPageSize = 100
	// adminSessionsMaxPageSize caps the per-call limit. The CSV
	// export client sets page_size to this value; UI pagination uses
	// a smaller size. 5000 keeps a single response body well under
	// Connect's default 32 MiB message limit even with verbose
	// metadata.
	adminSessionsMaxPageSize = 5000
	// adminSessionsDefaultWindowHours is the default created_at
	// window when the request omits start_time/end_time. 24h matches
	// the "last day by default" UX requirement.
	adminSessionsDefaultWindowHours = 24
)

// adminSessionsSortAllowlist gates the dynamic ORDER BY in the SQL —
// anything not on this list falls back to "created_at". The SQL has
// matching CASE branches for each entry; keep these in lockstep with
// queries/sessions.sql::AdminListRecentSessions ORDER BY.
var adminSessionsSortAllowlist = map[string]struct{}{
	"created_at":       {},
	"session_date":     {},
	"duration_seconds": {},
	"status":           {},
	"therapist":        {},
	"organization":     {},
	"plan_name":        {},
	"period_end":       {},
	"tokens_used":      {},
}

// AdminListSessions returns recent session activity across every
// organization. SUPERWIZOR_ADMIN only.
func (s *Server) AdminListSessions(ctx context.Context, req *clinicalv1.AdminListSessionsRequest) (*clinicalv1.AdminListSessionsResponse, error) {
	if err := requireSuperwizorAdmin(ctx); err != nil {
		return nil, err
	}

	end := time.Now().UTC()
	if req.GetEndTime() != nil {
		end = req.GetEndTime().AsTime()
	}
	start := end.Add(-adminSessionsDefaultWindowHours * time.Hour)
	if req.GetStartTime() != nil {
		start = req.GetStartTime().AsTime()
	}
	if !end.After(start) {
		return nil, status.Error(codes.InvalidArgument, "end_time must be after start_time")
	}

	pageSize := req.GetPageSize()
	if pageSize <= 0 {
		pageSize = adminSessionsDefaultPageSize
	}
	if pageSize > adminSessionsMaxPageSize {
		pageSize = adminSessionsMaxPageSize
	}
	page := req.GetPage()
	if page < 0 {
		page = 0
	}

	sortBy := req.GetSortBy()
	if _, ok := adminSessionsSortAllowlist[sortBy]; !ok {
		sortBy = "created_at"
	}
	sortOrder := req.GetSortOrder()
	if sortOrder != "asc" {
		sortOrder = "desc"
	}

	rows, err := s.queries.AdminListRecentSessions(ctx, db.AdminListRecentSessionsParams{
		StartTime:       start,
		EndTime:         end,
		TherapistFilter: req.GetTherapistFilter(),
		SortBy:          sortBy,
		SortOrder:       sortOrder,
		PageOffset:      page * pageSize,
		PageLimit:       pageSize + 1, // read one extra to compute has_more
	})
	if err != nil {
		slog.ErrorContext(ctx, "AdminListSessions: query failed",
			"sort_by", sortBy,
			"sort_order", sortOrder,
			"err", err.Error())
		return nil, status.Errorf(codes.Internal, "list sessions: %v", err)
	}

	hasMore := false
	if int32(len(rows)) > pageSize {
		hasMore = true
		rows = rows[:pageSize]
	}

	out := make([]*clinicalv1.AdminSessionRow, 0, len(rows))
	for _, r := range rows {
		row := &clinicalv1.AdminSessionRow{
			SessionId:            r.ID.String(),
			TherapistId:          r.TherapistID.String(),
			TherapistFirstName:   r.TherapistFirstName,
			TherapistLastName:    r.TherapistLastName,
			TherapistEmail:       r.TherapistEmail,
			OrganizationId:       stringifyInterface(r.OrganizationID),
			OrganizationName:     r.OrganizationName,
			CreatedAt:            timestamppb.New(r.CreatedAt),
			Status:               r.Status,
			SubscriptionPlanName: r.SubscriptionPlanName,
		}
		if r.SessionDate.Valid {
			// session_date is a DATE — surface as a Timestamp at
			// 00:00 UTC. Calls who want the calendar date format
			// it client-side.
			row.SessionDate = timestamppb.New(r.SessionDate.Time)
		}
		if r.DurationSeconds != nil {
			row.DurationSeconds = *r.DurationSeconds
		}
		// Subscription columns come back as `interface{}` because the
		// LATERAL-JOIN-with-CASE-wrapper trick keeps sqlc honest about
		// nullability but loses the concrete Go type. At runtime
		// it's a time.Time or int32, or nil when there's no
		// subscription / counter for the therapist's org.
		if t, ok := r.SubscriptionPeriodEnd.(time.Time); ok {
			row.SubscriptionPeriodEnd = timestamppb.New(t)
		}
		if n, ok := r.SubscriptionTokensUsed.(int32); ok {
			row.SubscriptionTokensUsed = n
		}
		out = append(out, row)
	}

	return &clinicalv1.AdminListSessionsResponse{
		Sessions: out,
		HasMore:  hasMore,
	}, nil
}

// requireSuperwizorAdmin reads the role injected by
// {Unary,Connect}AuthInterceptor and rejects anything that isn't
// SUPERWIZOR_ADMIN. Returns a status.Error suitable for direct
// `return nil, err` from the caller.
func requireSuperwizorAdmin(ctx context.Context) error {
	role, _ := ctx.Value(UserRoleKey).(string)
	if role == "" {
		// Should never happen for a Connect/gRPC RPC that traversed
		// the auth interceptor — defensive belt for misconfigured
		// anonymous-method allowlists.
		return status.Error(codes.Unauthenticated, "missing role in context")
	}
	if role != "SUPERWIZOR_ADMIN" {
		return status.Errorf(codes.PermissionDenied,
			"role %s not authorised for SUPERWIZOR_ADMIN RPC", role)
	}
	return nil
}

// stringifyInterface flattens sqlc's `interface{}` return type for the
// COALESCE-then-::text expression we use on `users.organization_id` in
// AdminListRecentSessions. At runtime the value is always either a
// string or nil (when there's no org row).
func stringifyInterface(v any) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	// Best-effort fallback — surface the type so future bugs are
	// debuggable rather than silently empty.
	return fmt.Sprintf("%v", v)
}
