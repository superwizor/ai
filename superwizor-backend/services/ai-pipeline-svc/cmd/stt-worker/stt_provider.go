package sttworker

// stt_provider.go — which STT engine transcribes a given session.
//
// Lived in deepgram_path.go until docs/59; moved out when a third
// provider arrived and the function stopped being Deepgram-specific.

import (
	"context"
	"log/slog"
	"os"
	"strings"
)

// Provider names as they appear in STT_PROVIDER and in
// stt_operations.provider.
const (
	providerChirp      = "chirp"
	providerDeepgram   = "deepgram"
	providerElevenLabs = "elevenlabs"
)

// providerAvailable reports whether a provider can actually run. A
// provider whose client never got wired (no API key mounted) is not
// selectable no matter what the flag says — the flag must never be the
// reason a session doesn't transcribe.
func providerAvailable(p string) bool {
	switch p {
	case providerChirp:
		return true // always available; it is the fallback of last resort
	case providerDeepgram:
		return dgClient != nil
	case providerElevenLabs:
		return elClient != nil
	}
	return false
}

// normalizeProvider maps the raw env value onto a known provider.
// Empty means "unset" → chirp. An unrecognised value returns "" so the
// caller can log it before falling back.
func normalizeProvider(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "", providerChirp:
		return providerChirp
	case providerDeepgram:
		return providerDeepgram
	case providerElevenLabs:
		return providerElevenLabs
	}
	return ""
}

// resolveSTTProvider picks the STT engine for a session:
//
//	STT_PROVIDER=<name>              → that provider for everyone
//	STT_PROVIDER_CANARY=<name> +
//	  STT_PROVIDER_ALLOWLIST=<uuids> → the canary provider when the
//	                                   session's therapist or org is listed
//	otherwise                        → STT_PROVIDER (default chirp)
//
// STT_PROVIDER_CANARY is new in docs/59 and closes a trap: the allowlist
// branch used to `return "deepgram"` literally, so switching the default
// to a third provider would have sent canary traffic to Deepgram — the
// very engine being migrated away from. The canary target is now
// explicit, and an allowlist without a canary target is inert (logged).
//
// Any resolution failure falls back to the configured default, and an
// unavailable provider falls back to chirp.
func resolveSTTProvider(ctx context.Context, sessionID string) string {
	def := normalizeProvider(os.Getenv("STT_PROVIDER"))
	if def == "" {
		slog.Warn("unknown STT_PROVIDER value; defaulting to chirp",
			"value", os.Getenv("STT_PROVIDER"))
		return providerChirp
	}
	if !providerAvailable(def) {
		slog.Warn("configured STT_PROVIDER has no client wired; defaulting to chirp",
			"provider", def)
		return providerChirp
	}

	allow := strings.TrimSpace(os.Getenv("STT_PROVIDER_ALLOWLIST"))
	if allow == "" || dbPool == nil {
		return def
	}

	canary := normalizeProvider(os.Getenv("STT_PROVIDER_CANARY"))
	switch {
	case os.Getenv("STT_PROVIDER_CANARY") == "":
		// Allowlist set but nothing to route it to. Louder than Debug on
		// purpose: someone believes a canary is running and it is not.
		slog.Warn("STT_PROVIDER_ALLOWLIST set without STT_PROVIDER_CANARY; allowlist is inert",
			"default_provider", def)
		return def
	case canary == "":
		slog.Warn("unknown STT_PROVIDER_CANARY value; ignoring allowlist",
			"value", os.Getenv("STT_PROVIDER_CANARY"))
		return def
	case canary == def:
		return def // canary equals default — nothing to route
	case !providerAvailable(canary):
		slog.Warn("STT_PROVIDER_CANARY has no client wired; ignoring allowlist",
			"canary", canary)
		return def
	}

	listed := map[string]bool{}
	for _, id := range strings.Split(allow, ",") {
		if id = strings.TrimSpace(strings.ToLower(id)); id != "" {
			listed[id] = true
		}
	}

	var therapistID, orgID string
	err := dbPool.QueryRow(ctx, `
		SELECT s.therapist_id::text, COALESCE(u.organization_id::text, '')
		FROM sessions s JOIN users u ON u.id = s.therapist_id
		WHERE s.id = $1`, sessionID).Scan(&therapistID, &orgID)
	if err != nil {
		slog.Warn("provider allowlist lookup failed; using default provider",
			"session_id", sessionID, "default_provider", def, "error", err)
		return def
	}
	if listed[strings.ToLower(therapistID)] || (orgID != "" && listed[strings.ToLower(orgID)]) {
		return canary
	}
	return def
}
