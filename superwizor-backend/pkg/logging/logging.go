// Package logging configures slog so that Cloud Logging actually
// understands what we emit.
//
// The problem it solves: slog's JSONHandler writes {"level":"ERROR"},
// but Cloud Logging reads severity from a field literally named
// "severity". Anything else is ignored, so every line — including
// logger.Error — lands as DEFAULT severity. Consequences, all silent:
//
//   - the Logs Explorer severity filter finds nothing,
//   - "errors only" views look clean while the service is on fire,
//   - log-based alert policies conditioned on severity never fire.
//
// Found 2026-07-31 while wiring the STT coverage guard: the guard logs
// stt_low_coverage at Error level, and that line would have been
// indistinguishable from an INFO line in Cloud Logging — a monitor for
// truncated transcripts that cannot be monitored.
//
// What this package deliberately does NOT do: rename slog's "msg" field
// to Cloud Logging's preferred "message". Existing dashboards and alert
// policies in infra/modules/monitoring match on jsonPayload.msg
// (status mirror written, invalidating fcm token, …). Renaming would
// break them silently, which is the same class of bug we are fixing.
package logging

import (
	"context"
	"log/slog"
	"os"
)

// severityKey is the field name Cloud Logging reads. Not configurable —
// any other value means no severity at all.
const severityKey = "severity"

// cloudSeverity maps a slog level onto the closest Cloud Logging
// severity string. slog levels are open-ended integers, so this brackets
// rather than switches on exact values: a custom level between Warn and
// Error still reports as WARNING instead of falling through to nothing.
func cloudSeverity(l slog.Level) string {
	switch {
	case l < slog.LevelInfo:
		return "DEBUG"
	case l < slog.LevelWarn:
		return "INFO"
	case l < slog.LevelError:
		return "WARNING"
	case l < slog.LevelError+4:
		return "ERROR"
	default:
		return "CRITICAL"
	}
}

// replace rewrites the level attribute into Cloud Logging's shape and
// leaves everything else alone.
func replace(_ []string, a slog.Attr) slog.Attr {
	if a.Key != slog.LevelKey {
		return a
	}
	lvl, ok := a.Value.Any().(slog.Level)
	if !ok {
		return a
	}
	return slog.String(severityKey, cloudSeverity(lvl))
}

// NewHandler builds a JSON handler whose output Cloud Logging parses
// correctly. level may be nil for the default (Info).
func NewHandler(level slog.Leveler) slog.Handler {
	return slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level:       level,
		ReplaceAttr: replace,
	})
}

// Setup installs the handler as the process default. Call it first thing
// in main/init, before anything logs.
func Setup(level slog.Leveler) *slog.Logger {
	l := slog.New(NewHandler(level))
	slog.SetDefault(l)
	return l
}

// SetupDefault is Setup at Info level — the common case.
func SetupDefault() *slog.Logger { return Setup(slog.LevelInfo) }

// Ensure the package compiles against the context-aware API surface
// callers use (slog.InfoContext and friends) without importing context
// only for the doc comment.
var _ = context.Background
