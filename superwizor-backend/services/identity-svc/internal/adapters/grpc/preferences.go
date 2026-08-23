package grpc

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// preferencesPayload mirrors the JSONB shape stored on
// users.report_preferences. Field tags match the proto field names
// 1:1 so the Flutter app, the proto layer, and the DB blob all agree
// on key strings. Empty strings / nil slices represent "use default
// for this dimension" — the renderer in ai-pipeline-svc skips them.
//
// Whenever a new dimension is added: update this struct + the
// validators + the renderer in ai-pipeline-svc.internal/reportprefs.
type preferencesPayload struct {
	Version            int32    `json:"version"`
	Length             string   `json:"length,omitempty"`
	Tone               string   `json:"tone,omitempty"`
	QuoteDensity       string   `json:"quote_density,omitempty"`
	DiagnosticLanguage string   `json:"diagnostic_language,omitempty"`
	HypothesisHedging  string   `json:"hypothesis_hedging,omitempty"`
	SectionEmphasis    []string `json:"section_emphasis,omitempty"`
	StrengthsFraming   string   `json:"strengths_framing,omitempty"`
	FreeText           string   `json:"free_text,omitempty"`
	// ExperimentalDualRun to NIE jest preferencja stylu jak pozostale
	// pola — decyduje, ILE raportow powstaje (plan 16 §2.5), i celowo NIE
	// wchodzi do renderera promptu w ai-pipeline-svc/internal/reportprefs.
	// Dlatego tez nie ma dla niej listy dozwolonych wartosci: bool nie ma
	// czego walidowac.
	ExperimentalDualRun bool      `json:"experimental_dual_run,omitempty"`
	UpdatedAt           time.Time `json:"updated_at"`
}

// Closed allow-lists. The renderer in ai-pipeline-svc trusts whatever
// gets through to the DB, so input validation is the only defense.
// Any value not in the allow-list is rejected with InvalidArgument.
var (
	allowedLength = map[string]bool{
		"":      true, // empty = use default
		"brief": true, "standard": true, "detailed": true,
	}
	allowedTone = map[string]bool{
		"":                true,
		"clinical_formal": true, "empathic_warm": true,
		"pragmatic_direct": true, "academic_rigorous": true,
	}
	allowedQuoteDensity = map[string]bool{
		"":    true,
		"few": true, "selective": true, "many": true,
	}
	allowedDiagnosticLanguage = map[string]bool{
		"":            true,
		"descriptive": true, "clinical_labels": true, "dsm_icd": true,
	}
	allowedHypothesisHedging = map[string]bool{
		"":          true,
		"tentative": true, "balanced": true, "assertive": true,
	}
	allowedSectionEmphasis = map[string]bool{
		"clinical_picture":            true,
		"interventions":               true,
		"case_formulation":            true,
		"supervisory_recommendations": true,
		"homework_between_sessions":   true,
		"cultural_context":            true,
		"safety_and_risk":             true,
	}
	allowedStrengthsFraming = map[string]bool{
		"":                true,
		"problem_focused": true, "balanced": true, "strengths_first": true,
	}
)

// Free-text guardrails. The 500-char cap is hard; the regex set
// matches patterns that look like prompt-injection attempts. We
// REJECT (not strip) on match so the therapist sees that their text
// was problematic — silent stripping is worse than failing loud.
//
// The patterns are intentionally English+Polish because injection
// prompts in the wild are mostly English even when the rest of the
// text is local. False-positive rate on legitimate Polish therapy
// notes is essentially zero — none of these phrases come up in
// describing therapist style.
const freeTextMaxLen = 500

var injectionPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)(ignore|disregard|forget)\s+.{0,30}(previous|above|prior|earlier|system)`),
	regexp.MustCompile(`(?i)system\s+prompt`),
	regexp.MustCompile(`(?i)you\s+are\s+now`),
	regexp.MustCompile(`(?i)new\s+instructions?:`),
	regexp.MustCompile(`(?i)act\s+as\s+(a|an)\s+\w+`),
}

// schemaVersion is the version we write to new payloads. Bump when
// renderer semantics change in a non-backward-compatible way.
const schemaVersion = 1

// GetReportPreferences returns the therapist's saved style
// preferences. Empty/missing → all-defaults blob (rendered as a
// no-op fragment by ai-pipeline-svc).
func (s *Server) GetReportPreferences(ctx context.Context, req *identityv1.GetReportPreferencesRequest) (*identityv1.ReportPreferences, error) {
	id, err := uuid.Parse(req.TherapistId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id")
	}

	raw, err := s.queries.GetReportPreferences(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		// Don't leak DB error text per pkg/errors guidance.
		return nil, status.Error(codes.Internal, "load preferences")
	}

	payload, err := unmarshalPreferences(raw)
	if err != nil {
		// A corrupt JSONB column shouldn't crash the client — fall
		// back to defaults and log. Logged via slog default; the
		// concrete logger sink is set up in main.go.
		payload = preferencesPayload{Version: schemaVersion}
	}

	out := toProtoPreferences(payload)
	out.ExperimentalAvailable = s.experimentalAvailable(ctx, id)
	return out, nil
}

// experimentalAvailable mowi, czy organizacja terapeuty ma wlaczony tryb
// eksperymentalny (plan 16 §2.5).
//
// Czytane WPROST z app_config, bez czytnika appconfig: identity-svc nie
// uzywa go nigdzie indziej, a wciagniecie calego cache'u z 30-sekundowym
// TTL dla jednego bool na ekranie ustawien byloby wieksza zaleznoscia niz
// korzyscia. Rozstrzygniecie jest tu WYLACZNIE kosmetyczne — decyduje o
// widocznosci przelacznika. Bramka faktyczna siedzi w clinical-svc i
// llm-workerze, ktore sprawdzaja flage przy kazdym zamowieniu.
//
// Blad odczytu -> false: ukryty przelacznik jest lepszy niz widoczny
// przelacznik, ktory po klikniciu zwroci PermissionDenied.
func (s *Server) experimentalAvailable(ctx context.Context, therapistID uuid.UUID) bool {
	if s.pool == nil {
		return false
	}
	var wartosc *string
	err := s.pool.QueryRow(ctx, `
		SELECT c.value
		  FROM users u
		  LEFT JOIN app_config c
		         ON c.key = 'REPORT_EXPERIMENTAL_ENABLED'
		        AND (c.organization_id = u.organization_id OR c.organization_id IS NULL)
		 WHERE u.id = $1
		 ORDER BY c.organization_id NULLS LAST
		 LIMIT 1`, therapistID).Scan(&wartosc)
	if err != nil || wartosc == nil {
		return false
	}
	return *wartosc == "true"
}

// UpdateReportPreferences validates and persists a new preference
// blob. Idempotent on (therapist, idempotency_key) — same key with
// same payload is a no-op (well, an UPDATE writing the same bytes);
// same key with a *different* payload would normally be an
// AlreadyExists error per global idempotency contract, but since
// preferences are a single-row UPSERT-style operation (replace whole
// blob), we treat "same key + different payload" as the user changing
// their mind mid-flight and just accept the new payload. Document
// this exception explicitly because it diverges from the
// CreatePatientFile-style contract elsewhere.
func (s *Server) UpdateReportPreferences(ctx context.Context, req *identityv1.UpdateReportPreferencesRequest) (*identityv1.ReportPreferences, error) {
	id, err := uuid.Parse(req.TherapistId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id")
	}
	if req.IdempotencyKey == "" {
		return nil, status.Error(codes.InvalidArgument, "idempotency_key required")
	}
	if req.Preferences == nil {
		return nil, status.Error(codes.InvalidArgument, "preferences required")
	}

	payload, err := protoToPayload(req.Preferences)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}
	// validatePayload mutates the free-text field in place
	// (sanitization). Pass a pointer so the mutation is visible to
	// the caller for the subsequent Marshal.
	if err := validatePayload(&payload); err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	// Always stamp the version + updated_at server-side; client
	// values for these fields are ignored to keep them
	// monotonically meaningful.
	payload.Version = schemaVersion
	payload.UpdatedAt = time.Now().UTC()

	encoded, err := json.Marshal(payload)
	if err != nil {
		return nil, status.Error(codes.Internal, "encode preferences")
	}

	// Pobranie starych preferencji do wyznaczenia diff dla analityki
	var oldPayload preferencesPayload
	oldRaw, errGet := s.queries.GetReportPreferences(ctx, id)
	if errGet == nil {
		oldPayload, _ = unmarshalPreferences(oldRaw)
	} else {
		oldPayload = preferencesPayload{Version: schemaVersion}
	}

	raw, err := s.queries.UpdateReportPreferences(ctx, db.UpdateReportPreferencesParams{
		ID:                id,
		ReportPreferences: encoded,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Error(codes.Internal, "save preferences")
	}

	final, err := unmarshalPreferences(raw)
	if err != nil {
		return nil, status.Error(codes.Internal, "decode saved preferences")
	}

	// Emisja zdarzeń analitycznych o zmianie preferencji
	if s.collector != nil {
		compareAndTrack := func(dimension, from, to string) {
			if from != to {
				s.collector.Track(ctx, analytics.Event{
					Name:        "preferences.updated",
					TherapistID: &id,
					Properties: map[string]any{
						"dimension":  dimension,
						"from_value": from,
						"to_value":   to,
					},
					Source: "server",
				})
			}
		}

		compareAndTrack("length", oldPayload.Length, payload.Length)
		compareAndTrack("tone", oldPayload.Tone, payload.Tone)
		compareAndTrack("quote_density", oldPayload.QuoteDensity, payload.QuoteDensity)
		compareAndTrack("diagnostic_language", oldPayload.DiagnosticLanguage, payload.DiagnosticLanguage)
		compareAndTrack("hypothesis_hedging", oldPayload.HypothesisHedging, payload.HypothesisHedging)
		compareAndTrack("strengths_framing", oldPayload.StrengthsFraming, payload.StrengthsFraming)
		compareAndTrack("free_text", oldPayload.FreeText, payload.FreeText)
		compareAndTrack("experimental_dual_run",
			boolLabel(oldPayload.ExperimentalDualRun), boolLabel(payload.ExperimentalDualRun))

		oldSections := strings.Join(oldPayload.SectionEmphasis, ",")
		newSections := strings.Join(payload.SectionEmphasis, ",")
		compareAndTrack("section_emphasis", oldSections, newSections)
	}

	return toProtoPreferences(final), nil
}

// ─── helpers ────────────────────────────────────────────────

func unmarshalPreferences(raw []byte) (preferencesPayload, error) {
	if len(raw) == 0 || string(raw) == "{}" {
		return preferencesPayload{Version: schemaVersion}, nil
	}
	var p preferencesPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return preferencesPayload{}, err
	}
	return p, nil
}

func protoToPayload(p *identityv1.ReportPreferences) (preferencesPayload, error) {
	// Defensive copy of section_emphasis so the proto slice can be
	// GC'd. Trim spaces while we're at it — protect against
	// whitespace-only "values".
	sections := make([]string, 0, len(p.SectionEmphasis))
	for _, s := range p.SectionEmphasis {
		s = strings.TrimSpace(s)
		if s != "" {
			sections = append(sections, s)
		}
	}
	return preferencesPayload{
		Length:              strings.TrimSpace(p.Length),
		Tone:                strings.TrimSpace(p.Tone),
		QuoteDensity:        strings.TrimSpace(p.QuoteDensity),
		DiagnosticLanguage:  strings.TrimSpace(p.DiagnosticLanguage),
		HypothesisHedging:   strings.TrimSpace(p.HypothesisHedging),
		SectionEmphasis:     sections,
		StrengthsFraming:    strings.TrimSpace(p.StrengthsFraming),
		FreeText:            p.FreeText, // intentional: don't trim — see sanitizeFreeText
		ExperimentalDualRun: p.ExperimentalDualRun,
	}, nil
}

func toProtoPreferences(p preferencesPayload) *identityv1.ReportPreferences {
	out := &identityv1.ReportPreferences{
		Version:             p.Version,
		Length:              p.Length,
		Tone:                p.Tone,
		QuoteDensity:        p.QuoteDensity,
		DiagnosticLanguage:  p.DiagnosticLanguage,
		HypothesisHedging:   p.HypothesisHedging,
		SectionEmphasis:     p.SectionEmphasis,
		StrengthsFraming:    p.StrengthsFraming,
		FreeText:            p.FreeText,
		ExperimentalDualRun: p.ExperimentalDualRun,
	}
	if !p.UpdatedAt.IsZero() {
		out.UpdatedAt = timestamppb.New(p.UpdatedAt)
	}
	return out
}

// validatePayload enforces enum allow-lists + free-text rules. All
// invalid-input errors map to InvalidArgument upstream. Takes a
// pointer because sanitizeFreeText mutates p.FreeText in place
// (newlines stripped, etc.) — caller MUST observe the cleaned value.
func validatePayload(p *preferencesPayload) error {
	if !allowedLength[p.Length] {
		return fmt.Errorf("invalid length: %q", p.Length)
	}
	if !allowedTone[p.Tone] {
		return fmt.Errorf("invalid tone: %q", p.Tone)
	}
	if !allowedQuoteDensity[p.QuoteDensity] {
		return fmt.Errorf("invalid quote_density: %q", p.QuoteDensity)
	}
	if !allowedDiagnosticLanguage[p.DiagnosticLanguage] {
		return fmt.Errorf("invalid diagnostic_language: %q", p.DiagnosticLanguage)
	}
	if !allowedHypothesisHedging[p.HypothesisHedging] {
		return fmt.Errorf("invalid hypothesis_hedging: %q", p.HypothesisHedging)
	}
	if !allowedStrengthsFraming[p.StrengthsFraming] {
		return fmt.Errorf("invalid strengths_framing: %q", p.StrengthsFraming)
	}
	for _, s := range p.SectionEmphasis {
		if !allowedSectionEmphasis[s] {
			return fmt.Errorf("invalid section_emphasis: %q", s)
		}
	}
	if err := sanitizeFreeText(p); err != nil {
		return err
	}
	return nil
}

// sanitizeFreeText caps length, strips newlines + carriage returns,
// and rejects content matching injection patterns. Mutates p.
func sanitizeFreeText(p *preferencesPayload) error {
	// Newline / CR / zero-width stripped silently — those are
	// formatting artifacts, not adversarial. Unicode escapes used
	// instead of literal chars so the Go file itself is BOM-free
	// (Go compiler rejects BOMs mid-file).
	cleaned := strings.NewReplacer(
		"\n", " ",
		"\r", " ",
		"\u200B", "", // zero-width space
		"\u200C", "", // zero-width non-joiner
		"\u200D", "", // zero-width joiner
		"\uFEFF", "", // zero-width no-break space / BOM
	).Replace(p.FreeText)
	cleaned = strings.TrimSpace(cleaned)

	if len(cleaned) > freeTextMaxLen {
		return fmt.Errorf("free_text exceeds %d characters", freeTextMaxLen)
	}
	for _, re := range injectionPatterns {
		if re.MatchString(cleaned) {
			return fmt.Errorf("free_text contains a disallowed pattern; please rephrase")
		}
	}
	p.FreeText = cleaned
	return nil
}

// boolLabel zapisuje przelacznik tak, jak reszta pol sledzenia zmian —
// tekstem, zeby audyt mial jednolity ksztalt.
func boolLabel(b bool) string {
	if b {
		return "on"
	}
	return "off"
}
