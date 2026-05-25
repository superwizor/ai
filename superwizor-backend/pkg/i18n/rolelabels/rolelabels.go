// Package rolelabels generates role-aware localized speaker labels
// for transcripts based on the modality type. Replaces the neutral
// "Osoba N" / "Person N" labels emitted by pkg/i18n/speakerlabels in
// the common dyadic case where exactly one participant plays the
// therapist/coach role and one plays the patient/client role.
//
// Conventions:
//
//   • therapy modality → "Terapeuta" (pl) / "Therapist" (en) for the
//     therapist role, "Pacjent" / "Patient" for the patient role.
//   • coaching modality → "Trener" / "Coach" for the therapist role
//     (the LLM's role-hint vocabulary keeps `therapist` as the
//     "professional" slot regardless of modality; modality_type just
//     reinterprets the slot at render time), "Klient" / "Client" for
//     the patient role.
//   • Multi-participant sessions (couples, family, group): the first
//     speaker classified into a role gets the bare role label; the
//     second-plus get a numeric suffix ("Pacjent 2", "Coach 3", …).
//     Caller owns the collision counter so the per-session state stays
//     in one place.
//   • Non-dyadic roles (couple_partner, family_member_*, third_party,
//     unknown, filler) fall through to pkg/i18n/speakerlabels — the
//     existing neutral "Osoba N" / "Person N" naming is preserved.
//
// Privacy: role descriptors ("Therapist", "Patient", "Coach",
// "Client") are NOT personal data — they describe the session-level
// relationship, not the participant's identity. Storing them in
// sessions.speaker_label_mapping is OK under ADR-IMPL-002 (amended
// 2026-05-25; see docs/agents/05_ai-pipeline-svc.md). Never put raw
// names (or anything the patient said about their own identity) into
// the label mapping.
package rolelabels

import (
	"fmt"
	"strings"

	"github.com/superwizor-ai/backend/pkg/i18n/speakerlabels"
)

// Generate returns the localized display label for one speaker in
// a transcript. The caller owns a per-session ledger (`takenRoles`
// keyed by role hint) so collisions are numbered consistently.
//
// Inputs:
//
//   - languageCode: BCP-47 or bare language ("pl-PL", "en-US",
//     "pl", "en"). Unknown locales fall through to "en".
//   - modalityType: "therapy" or "coaching". Anything else
//     (including empty string) → treated as "therapy" — the catalog
//     is overwhelmingly clinical.
//   - roleHint: the LLM's SpeakerGroup.RoleHint. Dyadic values
//     ("therapist", "patient") trigger role-aware labels; everything
//     else falls through to speakerlabels.Generate.
//   - tag: the numeric fallback (speakerlabels.Generate input) used
//     when we fall through.
//   - takenRoles: caller-owned counter, role-hint → count seen so
//     far this session. Mutated in place when a role is claimed:
//     incremented BEFORE returning. Passing nil is a programmer
//     error — Generate panics rather than silently losing collision
//     state.
//
// Outputs:
//
//   - label: what to write into sessions.speaker_label_mapping.
//   - claimedRole: the role-hint key that was consumed ("therapist"
//     or "patient"), or "" when Generate fell through to the
//     numeric helper. Useful for caller-side telemetry.
func Generate(
	languageCode, modalityType, roleHint string,
	tag int,
	takenRoles map[string]int,
) (label, claimedRole string) {
	if takenRoles == nil {
		panic("rolelabels.Generate: takenRoles map must not be nil")
	}

	// Normalize inputs. Lower-casing role + modality is defensive
	// against schema enum casing drift (Postgres returns enum text
	// in the source case but Go callers can still ship anything).
	role := strings.ToLower(strings.TrimSpace(roleHint))
	modality := strings.ToLower(strings.TrimSpace(modalityType))
	if modality != "therapy" && modality != "coaching" {
		modality = "therapy"
	}

	// Non-dyadic roles short-circuit to the neutral helper. Same
	// for any role we don't have a vocabulary entry for — adding a
	// new role hint upstream MUST be paired with extending the
	// table below, otherwise the new role silently gets "Osoba N".
	if role != "therapist" && role != "patient" {
		return speakerlabels.Generate(languageCode, tag), ""
	}

	base := lookupLabel(languageCode, modality, role)
	if base == "" {
		// Couldn't find a translation for the (modality, role) pair
		// in this locale. Fall through rather than ship an empty
		// string — better to show "Osoba 2" than nothing.
		return speakerlabels.Generate(languageCode, tag), ""
	}

	count := takenRoles[role]
	takenRoles[role] = count + 1
	if count == 0 {
		return base, role
	}
	// Second-plus speaker in this role. "Pacjent" → "Pacjent 2".
	// We use count+1 (1-indexed for the suffix, but the first
	// claimant got no suffix, so the second claimant displays "2").
	return fmt.Sprintf("%s %d", base, count+1), role
}

// lookupLabel resolves a (locale, modality, role) tuple to the
// localized base label (no numeric suffix). Returns "" when the
// tuple isn't in the table — caller decides the fallback.
//
// Match order: full BCP-47 tag → language prefix → empty. Mirrors
// the lookup discipline in pkg/i18n/speakerlabels.
func lookupLabel(languageCode, modality, role string) string {
	key := modality + "|" + role
	table, ok := vocab[key]
	if !ok {
		return ""
	}
	if v, ok := table[languageCode]; ok {
		return v
	}
	// Trim "pl-PL" → "pl".
	if idx := strings.Index(languageCode, "-"); idx > 0 {
		if v, ok := table[languageCode[:idx]]; ok {
			return v
		}
	}
	// English is the universal fallback.
	if v, ok := table["en"]; ok {
		return v
	}
	return ""
}

// vocab is keyed by "<modality>|<role>" → locale → label. Adding a
// new language: add an entry per (modality, role) combination
// you want it to cover. Missing entries fall through to English.
//
// Translation rules:
//   - therapy is the clinical setting; use the standard clinical
//     vocabulary in each language.
//   - coaching is the non-clinical setting; use the professional
//     loanword if that's how the local industry refers to it
//     (Polish coaching industry uses "Trener"/"Klient";
//     English-language coaching is "Coach"/"Client").
var vocab = map[string]map[string]string{
	"therapy|therapist": {
		"en": "Therapist",
		"pl": "Terapeuta",
		"de": "Therapeut",
		"es": "Terapeuta",
		"fr": "Thérapeute",
		"it": "Terapeuta",
		"pt": "Terapeuta",
		"nl": "Therapeut",
		"cs": "Terapeut",
		"sk": "Terapeut",
		"sv": "Terapeut",
		"da": "Terapeut",
		"no": "Terapeut",
		"fi": "Terapeutti",
	},
	"therapy|patient": {
		"en": "Patient",
		"pl": "Pacjent",
		"de": "Patient",
		"es": "Paciente",
		"fr": "Patient",
		"it": "Paziente",
		"pt": "Paciente",
		"nl": "Patiënt",
		"cs": "Pacient",
		"sk": "Pacient",
		"sv": "Patient",
		"da": "Patient",
		"no": "Pasient",
		"fi": "Potilas",
	},
	"coaching|therapist": {
		"en": "Coach",
		"pl": "Trener",
		"de": "Coach",
		"es": "Coach",
		"fr": "Coach",
		"it": "Coach",
		"pt": "Coach",
		"nl": "Coach",
		"cs": "Kouč",
		"sk": "Kouč",
		"sv": "Coach",
		"da": "Coach",
		"no": "Coach",
		"fi": "Valmentaja",
	},
	"coaching|patient": {
		"en": "Client",
		"pl": "Klient",
		"de": "Klient",
		"es": "Cliente",
		"fr": "Client",
		"it": "Cliente",
		"pt": "Cliente",
		"nl": "Cliënt",
		"cs": "Klient",
		"sk": "Klient",
		"sv": "Klient",
		"da": "Klient",
		"no": "Klient",
		"fi": "Asiakas",
	},
}
