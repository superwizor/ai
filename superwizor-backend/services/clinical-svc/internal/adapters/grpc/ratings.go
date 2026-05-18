package grpc

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// ────────────────────────────────────────────────────────────
// Constants — closed allow-lists for chip categories + lifecycle.
// Keep these in sync with the design doc §5 + §6 and with the
// Flutter widget's chip definitions. If chips evolve, update both
// ends in the same PR.
// ────────────────────────────────────────────────────────────

var allowedRating = map[string]bool{
	"positive": true,
	"negative": true,
}

// Chip categories surface on the negative-rating modal. The set is
// the same as the Flutter widget renders. Each maps (potentially) to
// a preferences dimension that the suggestion engine can nudge.
var allowedIssues = map[string]bool{
	"za_dlugi":                   true, // length
	"za_krotki":                  true, // length
	"zly_ton":                    true, // tone
	"za_duzo_cytatow":            true, // quote_density
	"za_malo_cytatow":            true, // quote_density
	"niedokladna_interpretacja":  true, // hedging + diagnostic_language
	"brakuje_mocnych_stron":      true, // strengths_framing
	"brakuje_kontekstu":          true, // section_emphasis
	"inne":                       true, // free-text only
}

var allowedAction = map[string]bool{
	"shown":     true,
	"applied":   true,
	"dismissed": true,
}

// Note text cap. Free-form, sanitized like
// identity-svc.preferences.go::freeTextMaxLen but smaller because the
// rating modal is meant for a quick comment, not an essay.
const ratingNotesMaxLen = 200

// injectionPatterns mirrors identity-svc.preferences.go. Duplicated
// rather than imported to avoid a cross-service Go dep (clinical-svc
// already depends on identity-svc via gRPC client; importing the
// internal package would couple the two at the build layer).
var ratingInjectionPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)(ignore|disregard|forget)\s+.{0,30}(previous|above|prior|earlier|system)`),
	regexp.MustCompile(`(?i)system\s+prompt`),
	regexp.MustCompile(`(?i)you\s+are\s+now`),
	regexp.MustCompile(`(?i)new\s+instructions?:`),
	regexp.MustCompile(`(?i)act\s+as\s+(a|an)\s+\w+`),
}

// Suggestion engine thresholds. Tunable; current values per design
// doc §6: ≥3 negatives of same chip in the last 5 ratings (or 14
// days), 14-day cooldown on dismissed.
const (
	suggestionTriggerCount      = 3
	suggestionLookbackRatings   = 5
	suggestionDismissCooldown   = 14 * 24 * time.Hour
)

// dimensionForChip maps a chip category to the preference dimension
// the engine will propose to nudge. Some chips fan out to multiple
// dimensions (e.g. niedokladna_interpretacja → hedging OR
// diagnostic_language); the engine picks the first match for v1.
// "" means no actionable dimension (e.g. "inne" — free-text only).
var dimensionForChip = map[string]string{
	"za_dlugi":                  "length",
	"za_krotki":                 "length",
	"zly_ton":                   "tone",
	"za_duzo_cytatow":           "quote_density",
	"za_malo_cytatow":           "quote_density",
	"niedokladna_interpretacja": "hypothesis_hedging",
	"brakuje_mocnych_stron":     "strengths_framing",
	"brakuje_kontekstu":         "section_emphasis",
	"inne":                      "",
}

// reasonLabelForChip is what we surface to the Flutter banner copy.
// Kept here (server-side) so the wording is consistent across
// localizations and we don't depend on the client to look it up.
var reasonLabelForChip = map[string]string{
	"za_dlugi":                  "za długi",
	"za_krotki":                 "za krótki",
	"zly_ton":                   "zły ton",
	"za_duzo_cytatow":           "za dużo cytatów",
	"za_malo_cytatow":           "za mało cytatów",
	"niedokladna_interpretacja": "niedokładna interpretacja",
	"brakuje_mocnych_stron":     "brakuje mocnych stron pacjenta",
	"brakuje_kontekstu":         "brakuje kontekstu / złe akcenty",
}

// ────────────────────────────────────────────────────────────
// RPC: RateReport
// ────────────────────────────────────────────────────────────

func (s *Server) RateReport(ctx context.Context, req *clinicalv1.RateReportRequest) (*clinicalv1.RateReportResponse, error) {
	reportID, err := uuid.Parse(req.ReportId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid report_id")
	}
	therapistID, err := uuid.Parse(req.TherapistId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id")
	}
	if !allowedRating[req.Rating] {
		return nil, status.Error(codes.InvalidArgument, "rating must be 'positive' or 'negative'")
	}
	if req.IdempotencyKey == "" {
		return nil, status.Error(codes.InvalidArgument, "idempotency_key required")
	}

	// Validate chip categories. Positive rating with non-empty issues
	// is suspicious — clamp to empty rather than 400 because we don't
	// want a client bug to lose the thumbs-up signal.
	issues := req.Issues
	if req.Rating == "positive" {
		issues = []string{}
	} else {
		for _, iss := range issues {
			if !allowedIssues[iss] {
				return nil, status.Error(codes.InvalidArgument, fmt.Sprintf("unknown issue category: %q", iss))
			}
		}
	}
	// Normalize to non-nil slice. The DB column is `TEXT[] NOT NULL
	// DEFAULT '{}'` — the DEFAULT only kicks in when the column is
	// OMITTED from the INSERT, NOT when we explicitly pass nil. pgx
	// encodes Go nil as SQL NULL, which violates NOT NULL with SQLSTATE
	// 23502. Empty slice → SQL '{}' (the intended default).
	if issues == nil {
		issues = []string{}
	}

	notes, err := sanitizeRatingNotes(req.Notes)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	source := strings.TrimSpace(req.Source)
	if source == "" {
		source = "in_app"
	}

	rating, err := s.queries.UpsertReportRating(ctx, db.UpsertReportRatingParams{
		ReportID:    reportID,
		TherapistID: therapistID,
		Rating:      req.Rating,
		Issues:      issues,
		Notes:       notes,
		Source:      source,
	})
	if err != nil {
		// Don't leak DB error text to the client (gRPC convention),
		// but log the actual error so we can diagnose. Common
		// failure modes worth distinguishing here:
		//   - FK violation on report_id (report deleted between
		//     GetSessionDetails and RateReport — race)
		//   - FK violation on therapist_id (auth/session mismatch)
		//   - CHECK constraint (invalid rating value snuck past
		//     handler validation — shouldn't happen)
		// Cloud Logging filter:
		//   resource.labels.service_name="clinical-svc"
		//     AND jsonPayload.msg="UpsertReportRating"
		slog.Error("UpsertReportRating",
			"error", err.Error(),
			"report_id", reportID.String(),
			"therapist_id", therapistID.String(),
			"rating", req.Rating)
		return nil, status.Error(codes.Internal, "save rating")
	}

	return &clinicalv1.RateReportResponse{
		Rating: toProtoRating(rating),
	}, nil
}

// ────────────────────────────────────────────────────────────
// RPC: GetReportRating
// ────────────────────────────────────────────────────────────

func (s *Server) GetReportRating(ctx context.Context, req *clinicalv1.GetReportRatingRequest) (*clinicalv1.ReportRating, error) {
	reportID, err := uuid.Parse(req.ReportId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid report_id")
	}
	therapistID, err := uuid.Parse(req.TherapistId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id")
	}

	rating, err := s.queries.GetReportRating(ctx, db.GetReportRatingParams{
		ReportID:    reportID,
		TherapistID: therapistID,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "rating not found")
		}
		return nil, status.Error(codes.Internal, "load rating")
	}
	return toProtoRating(rating), nil
}

// ────────────────────────────────────────────────────────────
// RPC: GetActiveSuggestion — suggestion engine read path.
// Returns PreferenceSuggestion with empty suggestion_id when no
// active suggestion. Flutter checks the empty ID and hides the
// banner. Never returns NotFound — empty is the "no banner" state.
// ────────────────────────────────────────────────────────────

func (s *Server) GetActiveSuggestion(ctx context.Context, req *clinicalv1.GetActiveSuggestionRequest) (*clinicalv1.PreferenceSuggestion, error) {
	therapistID, err := uuid.Parse(req.TherapistId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id")
	}

	// Pull the lookback window of negative ratings. The actual
	// trigger logic + cooldown checks live in pure Go (testable
	// without DB) — SQL just gives us the rows.
	rows, err := s.queries.ListRecentNegativeRatings(ctx, db.ListRecentNegativeRatingsParams{
		TherapistID: therapistID,
		Limit:       int32(suggestionLookbackRatings),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "scan recent ratings")
	}

	chip := pickTriggerChip(rows, suggestionTriggerCount)
	if chip == "" {
		return &clinicalv1.PreferenceSuggestion{}, nil
	}

	dimension := dimensionForChip[chip]
	if dimension == "" {
		// "inne" or unmapped chip — no actionable dimension. Treat as
		// no suggestion to keep the banner free of dead-end nudges.
		return &clinicalv1.PreferenceSuggestion{}, nil
	}

	// Cooldown check: did the therapist dismiss a banner for this
	// dimension in the last 14 days? If so, suppress.
	dismiss, err := s.queries.GetLatestSuggestionDismissForDimension(ctx,
		db.GetLatestSuggestionDismissForDimensionParams{
			TherapistID: therapistID,
			Dimension:   dimension,
		})
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, status.Error(codes.Internal, "scan dismissals")
	}
	if err == nil && time.Since(dismiss.CreatedAt) < suggestionDismissCooldown {
		return &clinicalv1.PreferenceSuggestion{}, nil
	}

	// We don't know the therapist's *current* preferences here (those
	// live in identity-svc). The Flutter client already has them
	// loaded — it can decide whether the proposed nudge is a no-op
	// based on its local state. Server-side we just say "this is the
	// next value down/up the scale we'd propose." Clients filter
	// no-op suggestions client-side before rendering.
	from, to := proposeNudge(dimension, chip)
	count := countChipOccurrences(rows, chip)

	return &clinicalv1.PreferenceSuggestion{
		SuggestionId: uuid.New().String(),
		Dimension:    dimension,
		FromValue:    from,
		ToValue:      to,
		ReasonLabel:  reasonLabelForChip[chip],
		TriggerCount: int32(count),
	}, nil
}

// ────────────────────────────────────────────────────────────
// RPC: LogPreferenceSuggestion — telemetry write.
// Fire-and-forget from the client's perspective; we INSERT a row
// per (shown / applied / dismissed) event. Returns Empty so a
// gRPC failure doesn't block the user's primary action (settings
// edit, banner dismiss, etc.).
// ────────────────────────────────────────────────────────────

func (s *Server) LogPreferenceSuggestion(ctx context.Context, req *clinicalv1.LogPreferenceSuggestionRequest) (*emptypb.Empty, error) {
	therapistID, err := uuid.Parse(req.TherapistId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id")
	}
	if !allowedAction[req.Action] {
		return nil, status.Error(codes.InvalidArgument, "action must be 'shown', 'applied', or 'dismissed'")
	}
	if req.Dimension == "" {
		return nil, status.Error(codes.InvalidArgument, "dimension required")
	}

	if err := s.queries.InsertPreferenceSuggestionLog(ctx,
		db.InsertPreferenceSuggestionLogParams{
			TherapistID:  therapistID,
			Dimension:    req.Dimension,
			FromValue:    req.FromValue,
			ToValue:      req.ToValue,
			TriggerCount: req.TriggerCount,
			Action:       req.Action,
		}); err != nil {
		return nil, status.Error(codes.Internal, "log suggestion")
	}
	return &emptypb.Empty{}, nil
}

// ────────────────────────────────────────────────────────────
// Pure helpers (no DB, no gRPC) — tested in ratings_test.go.
// ────────────────────────────────────────────────────────────

// pickTriggerChip returns the chip category that meets the trigger
// count, or "" if none does. Tie-break: whichever crossed the
// threshold first (i.e. has the most occurrences); pure max-count.
// Empty input → "".
func pickTriggerChip(rows []db.ListRecentNegativeRatingsRow, threshold int) string {
	counts := map[string]int{}
	for _, r := range rows {
		for _, iss := range r.Issues {
			counts[iss]++
		}
	}
	bestChip := ""
	bestCount := 0
	for chip, n := range counts {
		if n >= threshold && n > bestCount {
			bestChip = chip
			bestCount = n
		}
	}
	return bestChip
}

func countChipOccurrences(rows []db.ListRecentNegativeRatingsRow, chip string) int {
	n := 0
	for _, r := range rows {
		for _, iss := range r.Issues {
			if iss == chip {
				n++
			}
		}
	}
	return n
}

// proposeNudge returns the (from_value, to_value) for the
// suggestion banner. from_value is a reasonable middle-of-the-road
// guess — the Flutter app overrides with the actual current value
// before rendering the banner. We don't have access to the user's
// preferences here (those are in identity-svc) and the suggestion
// engine doesn't strictly need them to compute the right "to" — the
// chip itself encodes the direction.
func proposeNudge(dimension, chip string) (from string, to string) {
	switch chip {
	case "za_dlugi":
		return "standard", "brief"
	case "za_krotki":
		return "standard", "detailed"
	case "za_duzo_cytatow":
		return "selective", "few"
	case "za_malo_cytatow":
		return "selective", "many"
	case "niedokladna_interpretacja":
		return "balanced", "tentative"
	case "brakuje_mocnych_stron":
		return "balanced", "strengths_first"
	case "zly_ton":
		// Tone has no canonical "down a level" — propose the
		// alternate most-common tone. The actual choice is
		// therapist's call in the settings page.
		return "clinical_formal", "empathic_warm"
	case "brakuje_kontekstu":
		return "", "" // section_emphasis is multi-select; UI handles
	}
	return "", ""
}

// sanitizeRatingNotes — same hygiene as identity-svc's free_text
// (newlines stripped, length cap, injection patterns rejected) but
// with the rating-specific 200-char cap.
func sanitizeRatingNotes(in string) (string, error) {
	cleaned := strings.NewReplacer(
		"\n", " ",
		"\r", " ",
		"\u200B", "",
		"\u200C", "",
		"\u200D", "",
		"\uFEFF", "",
	).Replace(in)
	cleaned = strings.TrimSpace(cleaned)
	if len(cleaned) > ratingNotesMaxLen {
		return "", fmt.Errorf("notes exceed %d characters", ratingNotesMaxLen)
	}
	for _, re := range ratingInjectionPatterns {
		if re.MatchString(cleaned) {
			return "", fmt.Errorf("notes contain a disallowed pattern; please rephrase")
		}
	}
	return cleaned, nil
}

func toProtoRating(r db.ReportRating) *clinicalv1.ReportRating {
	out := &clinicalv1.ReportRating{
		Id:          r.ID.String(),
		ReportId:    r.ReportID.String(),
		TherapistId: r.TherapistID.String(),
		Rating:      r.Rating,
		Issues:      r.Issues,
		Notes:       r.Notes,
		Source:      r.Source,
		CreatedAt:   timestamppb.New(r.CreatedAt),
		UpdatedAt:   timestamppb.New(r.UpdatedAt),
	}
	return out
}
