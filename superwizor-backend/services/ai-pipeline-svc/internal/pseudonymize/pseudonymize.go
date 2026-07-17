// Package pseudonymize implements the deterministic redaction engine of
// docs/41_PSEUDONIMIZACJA_RAPORTOW.md (revised scope 2026-07-17):
// FIRST NAMES STAY; redacted are surnames, structural identifiers
// (PESEL, phones, e-mails, postal codes, document numbers — regex
// layer, LLM-independent), addresses, employers/schools and localities
// (entity layer, forms supplied by call-1's `# PII` section).
//
// Design constraints (docs/41 §3.3):
//   - longest-match-first so "Anna Nowak" wins over "Nowak";
//   - unicode word boundaries — never match inside a word;
//   - case-insensitive matching, placeholder emitted literally;
//   - form collisions: first entity wins, counted for observability;
//   - pure package: no logging, no I/O — callers log the Stats.
package pseudonymize

import (
	"regexp"
	"sort"
	"strings"
	"unicode"
)

// Entity mirrors diarization.PIIEntity without importing it (keeps this
// package dependency-free and independently testable).
type Entity struct {
	Placeholder string
	Forms       []string
}

// Stats summarizes one Apply run for the caller's observability log.
type Stats struct {
	EntityCount       int
	Replacements      int // entity-form replacements performed
	RegexReplacements int // structural-identifier replacements
	// UnmatchedForms lists forms that never matched — a non-empty list
	// suggests the model hallucinated forms absent from the text.
	UnmatchedForms []string
	// Collisions counts forms claimed by more than one entity.
	Collisions int
}

// Replacer is an immutable redaction plan built once per session and
// applied to many texts (transcript, Title, Summary, RAG lines).
type Replacer struct {
	// forms sorted longest-first; parallel arrays.
	forms        []string
	placeholders []string
	matched      []bool
	collisions   int
}

// NewReplacer builds the plan. Duplicate forms across entities keep the
// FIRST entity's placeholder (docs/41: first wins + counter).
func NewReplacer(entities []Entity) *Replacer {
	r := &Replacer{}
	seen := map[string]bool{}
	for _, e := range entities {
		if e.Placeholder == "" {
			continue
		}
		for _, f := range e.Forms {
			f = strings.TrimSpace(f)
			if f == "" {
				continue
			}
			key := strings.ToLower(f)
			if seen[key] {
				r.collisions++
				continue
			}
			seen[key] = true
			r.forms = append(r.forms, f)
			r.placeholders = append(r.placeholders, e.Placeholder)
		}
	}
	// Longest-first: "Anna Nowak" must be consumed before "Nowak".
	idx := make([]int, len(r.forms))
	for i := range idx {
		idx[i] = i
	}
	sort.SliceStable(idx, func(a, b int) bool {
		return len(r.forms[idx[a]]) > len(r.forms[idx[b]])
	})
	sortedForms := make([]string, len(idx))
	sortedPh := make([]string, len(idx))
	for i, j := range idx {
		sortedForms[i] = r.forms[j]
		sortedPh[i] = r.placeholders[j]
	}
	r.forms = sortedForms
	r.placeholders = sortedPh
	r.matched = make([]bool, len(r.forms))
	return r
}

// Apply redacts text: regex layer first (deterministic, independent of
// the entity list), then entity forms longest-first with unicode word
// boundaries. Returns the redacted text and per-call stats (the
// Replacer accumulates matched-form state across calls so
// UnmatchedForms in the FINAL call's stats reflects the whole session).
func (r *Replacer) Apply(text string) (string, Stats) {
	var st Stats
	st.Collisions = r.collisions
	if text == "" {
		st.UnmatchedForms = r.unmatched()
		return text, st
	}

	text, n := applyRegexLayer(text)
	st.RegexReplacements = n

	for i, form := range r.forms {
		replaced := 0
		text, replaced = replaceWordBounded(text, form, r.placeholders[i])
		if replaced > 0 {
			r.matched[i] = true
			st.Replacements += replaced
		}
	}

	// Collapse "Imię [NAZWISKO-n]" → "Imię" (docs/41 §3.1: full
	// name reads naturally as the bare first name). Removing only the
	// token can never leak — the surname is already gone.
	text = collapseNameToken(text)

	st.EntityCount = len(r.forms)
	st.UnmatchedForms = r.unmatched()
	return text, st
}

func (r *Replacer) unmatched() []string {
	var out []string
	for i, ok := range r.matched {
		if !ok {
			out = append(out, r.forms[i])
		}
	}
	return out
}

// replaceWordBounded replaces case-insensitive, whole-word occurrences
// of form with placeholder. Word characters are unicode letters/digits;
// everything else is a boundary (so "Nowak," and "(Nowak)" match, but
// "Nowakowski" does not).
func replaceWordBounded(text, form, placeholder string) (string, int) {
	lowText := strings.ToLower(text)
	lowForm := strings.ToLower(form)
	var b strings.Builder
	count := 0
	i := 0
	for {
		j := strings.Index(lowText[i:], lowForm)
		if j < 0 {
			b.WriteString(text[i:])
			break
		}
		start := i + j
		end := start + len(form)
		if isWordBoundary(text, start, end) {
			b.WriteString(text[i:start])
			b.WriteString(placeholder)
			count++
		} else {
			b.WriteString(text[i:end])
		}
		i = end
	}
	if count == 0 {
		return text, 0
	}
	return b.String(), count
}

func isWordBoundary(text string, start, end int) bool {
	beforeOK := start == 0
	if !beforeOK {
		r := decodeLastRune(text[:start])
		beforeOK = !unicode.IsLetter(r) && !unicode.IsDigit(r)
	}
	afterOK := end >= len(text)
	if !afterOK {
		r := decodeFirstRune(text[end:])
		afterOK = !unicode.IsLetter(r) && !unicode.IsDigit(r)
	}
	return beforeOK && afterOK
}

func decodeFirstRune(s string) rune {
	for _, r := range s {
		return r
	}
	return 0
}

func decodeLastRune(s string) rune {
	var last rune
	for _, r := range s {
		last = r
	}
	return last
}

// ── regex layer: structural identifiers ─────────────────────────────

var (
	reEmail = regexp.MustCompile(`[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}`)
	// PESEL: exactly 11 digits, not embedded in a longer digit run.
	rePESEL = regexp.MustCompile(`(^|\D)(\d{11})(\D|$)`)
	// Polish phone: optional +48 / 0048, then 9 digits with optional
	// separators (spaces/dashes) in common 3-3-3 / 2-3-2-2 groupings.
	rePhone = regexp.MustCompile(`(?:\+?48[\s\-]?)?\d{3}[\s\-]?\d{3}[\s\-]?\d{3}(^|\b)`)
	// Postal code dd-ddd.
	rePostal = regexp.MustCompile(`\b\d{2}-\d{3}\b`)
	// Polish ID documents: dowód AAA######, paszport AA#######.
	reDocNum = regexp.MustCompile(`\b[A-Z]{2,3}[\s]?\d{6,7}\b`)
)

// applyRegexLayer redacts structural identifiers to a generic token.
// Runs BEFORE the entity layer so an entity form can never split a
// digit sequence first. Deterministic and always on — the privacy
// floor that holds even when the LLM lists nothing.
func applyRegexLayer(text string) (string, int) {
	n := 0
	count := func(re *regexp.Regexp, repl string) {
		text = re.ReplaceAllStringFunc(text, func(m string) string {
			n++
			return repl
		})
	}
	count(reEmail, "[IDENTYFIKATOR]")
	text = rePESEL.ReplaceAllStringFunc(text, func(m string) string {
		n++
		// Keep the non-digit context captured around the 11 digits.
		return rePESEL.ReplaceAllString(m, "${1}[IDENTYFIKATOR]${3}")
	})
	count(rePhone, "[IDENTYFIKATOR]")
	count(rePostal, "[ADRES]")
	count(reDocNum, "[IDENTYFIKATOR]")
	return text, n
}

// collapseNameToken removes a surname token that directly follows a
// capitalized word (the first name we deliberately kept):
// "Anna [NAZWISKO-1]" → "Anna". Removing the token cannot leak — the
// surname text was already replaced; worst case we lose the reference
// marker after a sentence-initial word, which is cosmetic.
var reNameToken = regexp.MustCompile(`(\p{Lu}\p{Ll}+)\s+\[NAZWISKO-?\d*\]`)

func collapseNameToken(text string) string {
	return reNameToken.ReplaceAllString(text, "$1")
}
