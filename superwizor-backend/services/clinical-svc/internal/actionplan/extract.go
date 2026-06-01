// Package actionplan ports the Flutter client-side action-plan extractor
// (flutter-app/superwizor/lib/utils/action_plan_extractor.dart) to Go so
// clinical-svc can resolve the "Plan działania klienta" (client action
// plan) section out of a session's report markdown server-side.
//
// The heuristic MUST stay in lockstep with the Dart version — the heading
// priority list and the same-or-higher-level capture rule are the
// contract. See docs/22.
package actionplan

import (
	"regexp"
	"strings"
)

// headingPriority is the list of heading names (already normalized to
// lowercase, accent-free) we look for, in priority order. The first
// heading whose text *contains* one of these phrases wins. Polish
// (primary) + English equivalents are interleaved by priority so the
// extractor works on reports generated in either language. Broad terms
// ("interventions"/"tasks") sit last so a more specific heading always
// wins first.
var headingPriority = []string{
	// P0 — explicit client action plan.
	"plan dzialania klienta",
	"client action plan",
	// P1 — action plan.
	"plan dzialania",
	"action plan",
	// P2 — proposed interventions.
	"propozycje interwencji",
	"proposed interventions",
	"intervention proposals",
	"suggested interventions",
	// P3 — agreed tasks / homework / next steps.
	"ustalone z klientem zadania",
	"agreed tasks",
	"next steps",
	"homework",
	// P4 — broad fallbacks.
	"zadania",
	"tasks",
	"interventions",
}

// diacriticReplacer lowercases-then-strips Polish diacritics so heading
// matching is both case- and accent-insensitive. Mirrors the Dart
// _normalize map.
var diacriticReplacer = strings.NewReplacer(
	"ą", "a",
	"ć", "c",
	"ę", "e",
	"ł", "l",
	"ń", "n",
	"ó", "o",
	"ś", "s",
	"ź", "z",
	"ż", "z",
)

// normalize lowercases and strips Polish diacritics.
func normalize(s string) string {
	return diacriticReplacer.Replace(strings.ToLower(s))
}

// headingLevel returns the markdown heading level (number of leading
// `#`) for line, or -1 if the line is not an ATX heading.
func headingLevel(line string) int {
	trimmed := strings.TrimLeft(line, " \t")
	if !strings.HasPrefix(trimmed, "#") {
		return -1
	}
	level := 0
	for level < len(trimmed) && trimmed[level] == '#' {
		level++
	}
	// A valid ATX heading needs whitespace (or end) after the hashes.
	if level < len(trimmed) && trimmed[level] != ' ' {
		return -1
	}
	return level
}

var headingHashPrefixRe = regexp.MustCompile(`^#+\s*`)

// headingText returns the heading text after the leading `#`s, trimmed.
func headingText(line string) string {
	trimmed := strings.TrimLeft(line, " \t")
	return strings.TrimSpace(headingHashPrefixRe.ReplaceAllString(trimmed, ""))
}

// Extract pulls the action-plan section out of report markdown and
// returns it as clean plain text, or "" when no matching heading is
// found.
//
// Heuristic (mirrors the Dart extractActionPlan body):
//  1. Scan ATX headings (`#`, `##`, …), case- and accent-insensitive,
//     against headingPriority.
//  2. For the first heading whose text contains a priority phrase,
//     capture every line after it up to (but excluding) the next heading
//     of the same-or-higher level (fewer-or-equal `#`).
//  3. Clean the captured markdown to readable plain text.
func Extract(markdown string) (text string) {
	lines := strings.Split(markdown, "\n")

	// Find the highest-priority matching heading.
	matchIndex := -1
	matchLevel := 0
	bestPriority := len(headingPriority) // lower == better

	for i := 0; i < len(lines); i++ {
		level := headingLevel(lines[i])
		if level < 0 {
			continue
		}
		normalized := normalize(headingText(lines[i]))
		for p := 0; p < len(headingPriority); p++ {
			if p >= bestPriority {
				break // can't improve
			}
			if strings.Contains(normalized, headingPriority[p]) {
				bestPriority = p
				matchIndex = i
				matchLevel = level
				break
			}
		}
		if bestPriority == 0 {
			break // top priority found, stop early
		}
	}

	if matchIndex < 0 {
		return ""
	}

	// Capture raw body lines until the next heading of same-or-higher
	// level.
	var raw []string
	for i := matchIndex + 1; i < len(lines); i++ {
		level := headingLevel(lines[i])
		if level >= 0 && level <= matchLevel {
			break
		}
		raw = append(raw, lines[i])
	}

	return toPlainText(raw)
}

var collapseBlankLinesRe = regexp.MustCompile(`\n{3,}`)

// toPlainText converts captured markdown body lines into clean, readable
// plain text: strips markdown emphasis, turns list bullets into "• ",
// unwraps links to their text, and inserts a blank line before each
// bullet so items breathe. Mirrors the Dart _toPlainText.
func toPlainText(rawLines []string) string {
	var out []string
	for _, line := range rawLines {
		cleaned := cleanInline(line)
		isBullet := strings.HasPrefix(strings.TrimLeft(cleaned, " \t"), "• ")
		if isBullet && len(out) > 0 && strings.TrimSpace(out[len(out)-1]) != "" {
			out = append(out, "") // paragraph spacing before a new bullet
		}
		out = append(out, cleaned)
	}
	joined := strings.Join(out, "\n")
	joined = collapseBlankLinesRe.ReplaceAllString(joined, "\n\n")
	return strings.TrimSpace(joined)
}

var (
	bulletRe   = regexp.MustCompile(`^(\s*)([-*+])\s+`)
	linkRe     = regexp.MustCompile(`\[([^\]]+)\]\([^)]*\)`)
	emphasisRe = regexp.MustCompile(`\*\*|__|\*|` + "`")
	leadHashRe = regexp.MustCompile(`^#{1,6}\s*`)
)

// cleanInline strips inline markdown from a single line. Mirrors the Dart
// _cleanInline. Single `_` is intentionally left alone to avoid mangling
// words.
func cleanInline(line string) string {
	s := line
	// List bullet → "• " (preserve indentation).
	s = bulletRe.ReplaceAllString(s, "$1• ")
	// Links [text](url) → text.
	s = linkRe.ReplaceAllString(s, "$1")
	// Emphasis / code markers: ** __ * `.
	s = emphasisRe.ReplaceAllString(s, "")
	// Defensive: any leading heading hashes.
	s = leadHashRe.ReplaceAllString(s, "")
	return strings.TrimRight(s, " \t")
}
