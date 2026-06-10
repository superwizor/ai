// crm_handler.go — CRM relationship management endpoints for Marcin.
//
// Provides CRUD for notes, follow-ups, tags, and user exclusion.
// These endpoints are admin-only (same Cloud Run IAM + OIDC auth
// as the other admin handlers).
//
// Tables: crm_notes, crm_follow_ups, crm_tags, crm_excluded_users
// (migration 000051).

package http

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// CRMHandler — handles CRM relationship management endpoints.
type CRMHandler struct {
	pool   *pgxpool.Pool
	logger *slog.Logger
}

// NewCRMHandler creates a new CRM handler.
func NewCRMHandler(pool *pgxpool.Pool, logger *slog.Logger) *CRMHandler {
	return &CRMHandler{pool: pool, logger: logger}
}

// RegisterCRMRoutes registers CRM routes on the mux. Every route is
// wrapped in the SUPERWIZOR_ADMIN Firebase-token middleware — billing-svc
// is publicly invokable, so route-level auth is the ONLY gate here
// (the 2026-06-10 exposure: these endpoints were world-readable).
func (h *CRMHandler) RegisterCRMRoutes(mux *http.ServeMux, auth *AdminAuthMiddleware) {
	// Notes
	mux.HandleFunc("GET /admin/crm/user/{userId}/notes", auth.Require(h.handleListNotes))
	mux.HandleFunc("POST /admin/crm/notes", auth.Require(h.handleCreateNote))

	// Follow-ups
	mux.HandleFunc("GET /admin/crm/follow-ups", auth.Require(h.handleListFollowUps))
	mux.HandleFunc("POST /admin/crm/follow-ups", auth.Require(h.handleCreateFollowUp))
	mux.HandleFunc("PATCH /admin/crm/follow-ups/{id}/complete", auth.Require(h.handleCompleteFollowUp))

	// Tags
	mux.HandleFunc("GET /admin/crm/user/{userId}/tags", auth.Require(h.handleListTags))
	mux.HandleFunc("POST /admin/crm/tags", auth.Require(h.handleCreateTag))
	mux.HandleFunc("DELETE /admin/crm/tags/{id}", auth.Require(h.handleDeleteTag))

	// Exclusion
	mux.HandleFunc("POST /admin/crm/exclude", auth.Require(h.handleExcludeUser))
	mux.HandleFunc("DELETE /admin/crm/exclude/{userId}", auth.Require(h.handleIncludeUser))

	// Detail view (aggregated)
	mux.HandleFunc("GET /admin/crm/user/{userId}/detail", auth.Require(h.handleUserDetail))
}

// ──────────────────── Notes ────────────────────

type crmNote struct {
	ID        string `json:"id"`
	Body      string `json:"body"`
	CreatedAt string `json:"created_at"`
}

type createNoteRequest struct {
	TargetUserID string `json:"target_user_id"`
	Body         string `json:"body"`
}

func (h *CRMHandler) handleListNotes(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := r.PathValue("userId")
	if userID == "" {
		writeError(w, http.StatusBadRequest, "missing userId", nil)
		return
	}

	rows, err := h.pool.Query(ctx, `
		SELECT id, body, created_at
		FROM crm_notes
		WHERE target_user_id = $1
		ORDER BY created_at DESC
		LIMIT 100
	`, userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query notes", err)
		return
	}
	defer rows.Close()

	var notes []crmNote
	for rows.Next() {
		var n crmNote
		var ts time.Time
		if err := rows.Scan(&n.ID, &n.Body, &ts); err != nil {
			h.logger.ErrorContext(ctx, "crm: scan note", "error", err)
			continue
		}
		n.CreatedAt = ts.Format(time.RFC3339)
		notes = append(notes, n)
	}
	if notes == nil {
		notes = []crmNote{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"notes": notes})
}

func (h *CRMHandler) handleCreateNote(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var req createNoteRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json", err)
		return
	}
	if req.TargetUserID == "" || strings.TrimSpace(req.Body) == "" {
		writeError(w, http.StatusBadRequest, "target_user_id and body required", nil)
		return
	}

	var id string
	err := h.pool.QueryRow(ctx, `
		INSERT INTO crm_notes (admin_user_id, target_user_id, body)
		VALUES ('admin', $1, $2)
		RETURNING id
	`, req.TargetUserID, req.Body).Scan(&id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "insert note", err)
		return
	}

	h.logger.InfoContext(ctx, "crm: note created", "target", req.TargetUserID, "id", id)
	writeJSON(w, http.StatusCreated, map[string]string{"id": id, "message": "ok"})
}

// ──────────────────── Follow-ups ────────────────────

type crmFollowUp struct {
	ID           string `json:"id"`
	TargetUserID string `json:"target_user_id"`
	FirstName    string `json:"first_name"`
	LastName     string `json:"last_name"`
	Email        string `json:"email"`
	Phone        string `json:"phone"`
	DueDate      string `json:"due_date"`
	Note         string `json:"note"`
	Completed    bool   `json:"completed"`
	Overdue      bool   `json:"overdue"`
	CreatedAt    string `json:"created_at"`
}

type createFollowUpRequest struct {
	TargetUserID string `json:"target_user_id"`
	DueDate      string `json:"due_date"` // YYYY-MM-DD
	Note         string `json:"note"`
}

func (h *CRMHandler) handleListFollowUps(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	showCompleted := r.URL.Query().Get("completed") == "true"

	var completedFilter string
	if !showCompleted {
		completedFilter = "AND f.completed = false"
	}

	query := fmt.Sprintf(`
		SELECT f.id, f.target_user_id, f.due_date, COALESCE(f.note, ''),
		       f.completed, f.created_at,
		       COALESCE(u.first_name, ''), COALESCE(u.last_name, ''),
		       COALESCE(u.email, ''), COALESCE(u.phone_number, '')
		FROM crm_follow_ups f
		JOIN users u ON u.id = f.target_user_id
		WHERE true %s
		ORDER BY f.due_date ASC
		LIMIT 200
	`, completedFilter)

	rows, err := h.pool.Query(ctx, query)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query follow-ups", err)
		return
	}
	defer rows.Close()

	today := time.Now().Format("2006-01-02")
	var followUps []crmFollowUp
	for rows.Next() {
		var f crmFollowUp
		var dueDate time.Time
		var createdAt time.Time
		if err := rows.Scan(
			&f.ID, &f.TargetUserID, &dueDate, &f.Note,
			&f.Completed, &createdAt,
			&f.FirstName, &f.LastName, &f.Email, &f.Phone,
		); err != nil {
			h.logger.ErrorContext(ctx, "crm: scan follow-up", "error", err)
			continue
		}
		f.DueDate = dueDate.Format("2006-01-02")
		f.CreatedAt = createdAt.Format(time.RFC3339)
		f.Overdue = f.DueDate <= today && !f.Completed
		followUps = append(followUps, f)
	}
	if followUps == nil {
		followUps = []crmFollowUp{}
	}

	// Count today's + overdue for priority inbox
	todayCount := 0
	overdueCount := 0
	for _, f := range followUps {
		if f.DueDate == today && !f.Completed {
			todayCount++
		}
		if f.Overdue {
			overdueCount++
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"follow_ups":    followUps,
		"today_count":   todayCount,
		"overdue_count": overdueCount,
	})
}

func (h *CRMHandler) handleCreateFollowUp(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var req createFollowUpRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json", err)
		return
	}
	if req.TargetUserID == "" || req.DueDate == "" {
		writeError(w, http.StatusBadRequest, "target_user_id and due_date required", nil)
		return
	}

	var id string
	err := h.pool.QueryRow(ctx, `
		INSERT INTO crm_follow_ups (admin_user_id, target_user_id, due_date, note)
		VALUES ('admin', $1, $2, $3)
		ON CONFLICT (admin_user_id, target_user_id, due_date)
		DO UPDATE SET note = EXCLUDED.note
		RETURNING id
	`, req.TargetUserID, req.DueDate, req.Note).Scan(&id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "insert follow-up", err)
		return
	}

	h.logger.InfoContext(ctx, "crm: follow-up created", "target", req.TargetUserID, "due", req.DueDate)
	writeJSON(w, http.StatusCreated, map[string]string{"id": id, "message": "ok"})
}

func (h *CRMHandler) handleCompleteFollowUp(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := r.PathValue("id")
	if id == "" {
		writeError(w, http.StatusBadRequest, "missing id", nil)
		return
	}

	_, err := h.pool.Exec(ctx, `
		UPDATE crm_follow_ups SET completed = true, completed_at = now()
		WHERE id = $1
	`, id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "complete follow-up", err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "ok"})
}

// ──────────────────── Tags ────────────────────

type crmTag struct {
	ID  string `json:"id"`
	Tag string `json:"tag"`
}

type createTagRequest struct {
	TargetUserID string `json:"target_user_id"`
	Tag          string `json:"tag"`
}

func (h *CRMHandler) handleListTags(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := r.PathValue("userId")
	if userID == "" {
		writeError(w, http.StatusBadRequest, "missing userId", nil)
		return
	}

	rows, err := h.pool.Query(ctx, `
		SELECT id, tag FROM crm_tags
		WHERE target_user_id = $1
		ORDER BY created_at
	`, userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query tags", err)
		return
	}
	defer rows.Close()

	var tags []crmTag
	for rows.Next() {
		var t crmTag
		if err := rows.Scan(&t.ID, &t.Tag); err != nil {
			continue
		}
		tags = append(tags, t)
	}
	if tags == nil {
		tags = []crmTag{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"tags": tags})
}

func (h *CRMHandler) handleCreateTag(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var req createTagRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json", err)
		return
	}
	tag := strings.TrimSpace(strings.ToLower(req.Tag))
	if req.TargetUserID == "" || tag == "" {
		writeError(w, http.StatusBadRequest, "target_user_id and tag required", nil)
		return
	}

	var id string
	err := h.pool.QueryRow(ctx, `
		INSERT INTO crm_tags (target_user_id, tag)
		VALUES ($1, $2)
		ON CONFLICT (target_user_id, tag) DO NOTHING
		RETURNING id
	`, req.TargetUserID, tag).Scan(&id)
	if err != nil {
		// ON CONFLICT DO NOTHING means scan may fail if already exists
		writeJSON(w, http.StatusOK, map[string]string{"message": "already exists"})
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"id": id, "message": "ok"})
}

func (h *CRMHandler) handleDeleteTag(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := r.PathValue("id")
	if id == "" {
		writeError(w, http.StatusBadRequest, "missing id", nil)
		return
	}

	_, err := h.pool.Exec(ctx, `DELETE FROM crm_tags WHERE id = $1`, id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "delete tag", err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "ok"})
}

// ──────────────────── Exclusion ────────────────────

type excludeRequest struct {
	UserID string `json:"user_id"`
	Reason string `json:"reason"`
}

func (h *CRMHandler) handleExcludeUser(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var req excludeRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json", err)
		return
	}
	if req.UserID == "" {
		writeError(w, http.StatusBadRequest, "user_id required", nil)
		return
	}

	_, err := h.pool.Exec(ctx, `
		INSERT INTO crm_excluded_users (user_id, reason)
		VALUES ($1, $2)
		ON CONFLICT (user_id) DO NOTHING
	`, req.UserID, req.Reason)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "exclude user", err)
		return
	}

	h.logger.InfoContext(ctx, "crm: user excluded", "user", req.UserID)
	writeJSON(w, http.StatusOK, map[string]string{"message": "ok"})
}

func (h *CRMHandler) handleIncludeUser(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := r.PathValue("userId")
	if userID == "" {
		writeError(w, http.StatusBadRequest, "missing userId", nil)
		return
	}

	_, err := h.pool.Exec(ctx, `DELETE FROM crm_excluded_users WHERE user_id = $1`, userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "include user", err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "ok"})
}

// ──────────────────── User Detail ────────────────────

type userDetail struct {
	// User
	UserID            string    `json:"user_id"`
	FirstName         string    `json:"first_name"`
	LastName          string    `json:"last_name"`
	Email             string    `json:"email"`
	Phone             string    `json:"phone"`
	ProfessionalTitle string    `json:"professional_title"`
	CreatedAt         string    `json:"created_at"`
	// Subscription
	PlanTier         string `json:"plan_tier"`
	SubStatus        string `json:"sub_status"`
	TokensRemaining  int32  `json:"tokens_remaining"`
	TokensLimit      int32  `json:"tokens_limit"`
	TokensUsed       int32  `json:"tokens_used"`
	PeriodEnd        string `json:"period_end"`
	DaysUntilRenewal int    `json:"days_until_renewal"`
	TotalSessions    int32  `json:"total_sessions"`
	// CRM data
	Notes      []crmNote    `json:"notes"`
	Tags       []crmTag     `json:"tags"`
	FollowUps  []crmFollowUp `json:"follow_ups"`
	Excluded   bool         `json:"excluded"`
	// Lifecycle
	LifecycleStage string `json:"lifecycle_stage"`
	LastSessionAt  string `json:"last_session_at"`
}

func (h *CRMHandler) handleUserDetail(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := r.PathValue("userId")
	if userID == "" {
		writeError(w, http.StatusBadRequest, "missing userId", nil)
		return
	}

	var detail userDetail
	detail.UserID = userID

	// User + subscription
	var periodEnd *time.Time
	var daysUntilRenewal *int
	var userCreated time.Time
	err := h.pool.QueryRow(ctx, `
		SELECT
			COALESCE(u.first_name, ''), COALESCE(u.last_name, ''),
			COALESCE(u.email, ''), COALESCE(u.phone_number, ''),
			COALESCE(u.professional_title, ''), u.created_at,
			COALESCE(p.tier::text, ''), COALESCE(s.status::text, ''),
			COALESCE(uc.tokens_limit, p.tokens_per_period, 0),
			COALESCE(uc.tokens_used, 0),
			GREATEST(0, COALESCE(uc.tokens_limit, p.tokens_per_period, 0) - COALESCE(uc.tokens_used, 0)),
			s.current_period_end,
			EXTRACT(DAY FROM s.current_period_end - now())::int,
			COALESCE(sess_count.cnt, 0)
		FROM users u
		LEFT JOIN organizations o ON o.id = u.organization_id
		LEFT JOIN subscriptions s ON s.organization_id = o.id AND s.status IN ('ACTIVE', 'TRIALING', 'PAST_DUE', 'CANCELED')
		LEFT JOIN subscription_plans p ON p.id = s.plan_id
		LEFT JOIN usage_counters uc ON uc.subscription_id = s.id AND uc.period_start = s.current_period_start
		LEFT JOIN LATERAL (
			SELECT COUNT(*)::int AS cnt FROM sessions sess WHERE sess.therapist_id = u.id
		) sess_count ON true
		WHERE u.id = $1
		LIMIT 1
	`, userID).Scan(
		&detail.FirstName, &detail.LastName,
		&detail.Email, &detail.Phone,
		&detail.ProfessionalTitle, &userCreated,
		&detail.PlanTier, &detail.SubStatus,
		&detail.TokensLimit, &detail.TokensUsed, &detail.TokensRemaining,
		&periodEnd, &daysUntilRenewal,
		&detail.TotalSessions,
	)
	if err != nil {
		writeError(w, http.StatusNotFound, "user not found", err)
		return
	}
	detail.CreatedAt = userCreated.Format("2006-01-02")
	if periodEnd != nil {
		detail.PeriodEnd = periodEnd.Format("2006-01-02")
	}
	if daysUntilRenewal != nil {
		detail.DaysUntilRenewal = *daysUntilRenewal
	}

	// Last session
	var lastSession time.Time
	_ = h.pool.QueryRow(ctx, `
		SELECT MAX(created_at) FROM sessions WHERE therapist_id = $1
	`, userID).Scan(&lastSession)
	if !lastSession.IsZero() {
		detail.LastSessionAt = lastSession.Format("2006-01-02")
	}

	// Lifecycle stage
	detail.LifecycleStage = computeLifecycleStage(
		detail.SubStatus, detail.PlanTier, detail.TotalSessions,
		lastSession, detail.DaysUntilRenewal,
	)

	// Notes
	notesRows, _ := h.pool.Query(ctx, `
		SELECT id, body, created_at FROM crm_notes
		WHERE target_user_id = $1 ORDER BY created_at DESC LIMIT 50
	`, userID)
	if notesRows != nil {
		defer notesRows.Close()
		for notesRows.Next() {
			var n crmNote
			var ts time.Time
			if err := notesRows.Scan(&n.ID, &n.Body, &ts); err == nil {
				n.CreatedAt = ts.Format(time.RFC3339)
				detail.Notes = append(detail.Notes, n)
			}
		}
	}
	if detail.Notes == nil {
		detail.Notes = []crmNote{}
	}

	// Tags
	tagRows, _ := h.pool.Query(ctx, `
		SELECT id, tag FROM crm_tags WHERE target_user_id = $1
	`, userID)
	if tagRows != nil {
		defer tagRows.Close()
		for tagRows.Next() {
			var t crmTag
			if err := tagRows.Scan(&t.ID, &t.Tag); err == nil {
				detail.Tags = append(detail.Tags, t)
			}
		}
	}
	if detail.Tags == nil {
		detail.Tags = []crmTag{}
	}

	// Follow-ups
	today := time.Now().Format("2006-01-02")
	fuRows, _ := h.pool.Query(ctx, `
		SELECT id, due_date, COALESCE(note, ''), completed, created_at
		FROM crm_follow_ups WHERE target_user_id = $1 ORDER BY due_date ASC LIMIT 20
	`, userID)
	if fuRows != nil {
		defer fuRows.Close()
		for fuRows.Next() {
			var f crmFollowUp
			var dueDate, createdAt time.Time
			if err := fuRows.Scan(&f.ID, &dueDate, &f.Note, &f.Completed, &createdAt); err == nil {
				f.TargetUserID = userID
				f.DueDate = dueDate.Format("2006-01-02")
				f.CreatedAt = createdAt.Format(time.RFC3339)
				f.Overdue = f.DueDate <= today && !f.Completed
				detail.FollowUps = append(detail.FollowUps, f)
			}
		}
	}
	if detail.FollowUps == nil {
		detail.FollowUps = []crmFollowUp{}
	}

	// Excluded?
	var exCount int
	_ = h.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM crm_excluded_users WHERE user_id = $1
	`, userID).Scan(&exCount)
	detail.Excluded = exCount > 0

	writeJSON(w, http.StatusOK, detail)
}

// computeLifecycleStage determines the user's lifecycle stage.
func computeLifecycleStage(subStatus, planTier string, totalSessions int32, lastSession time.Time, daysUntilRenewal int) string {
	if subStatus == "CANCELED" {
		return "churned"
	}
	if totalSessions == 0 {
		if planTier == "" || subStatus == "" {
			return "new"
		}
		return "onboarding"
	}
	if totalSessions == 1 {
		return "first_session"
	}

	daysSinceLastSession := 999
	if !lastSession.IsZero() {
		daysSinceLastSession = int(time.Since(lastSession).Hours() / 24)
	}

	if daysSinceLastSession > 14 {
		return "at_risk"
	}
	if totalSessions >= 20 {
		return "power_user"
	}
	return "active"
}

// readJSON decodes JSON body.
func readJSON(r *http.Request, v any) error {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20)) // 1MB limit
	if err != nil {
		return err
	}
	return json.Unmarshal(body, v)
}
