package postgres_test

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// These tests read SQL as text rather than running it. That is the point:
// they must fail on a PR that WRITES the wrong query, before any database
// exists to run it against, and they must keep failing for anyone who
// later "tidies up" the retention rules without reading the ADR.

// stripSQLComments removes -- comment lines. The tests below reason about
// what the SQL DOES; prose that merely mentions a table or an interval
// must not trip them, or the first honest explanatory comment turns into
// a false failure and the test gets weakened to make it pass.
func stripSQLComments(sql string) string {
	var out []string
	for _, line := range strings.Split(sql, "\n") {
		if idx := strings.Index(line, "--"); idx >= 0 {
			line = line[:idx]
		}
		out = append(out, line)
	}
	return strings.Join(out, "\n")
}

func read(t *testing.T, rel string) string {
	t.Helper()
	b, err := os.ReadFile(rel)
	if err != nil {
		t.Fatalf("read %s: %v", rel, err)
	}
	return string(b)
}

// The load-bearing negative test from plan F4.
//
// guardrail_decisions is the MDR article 94 evidence pack with a 24-month
// obligation. The GDPR purger runs a 30/90-day cycle. If the table ever
// enters that cycle, the evidence disappears three months into a
// twenty-four month duty and nobody notices until it is needed.
func TestGuardrailDecisionsAreOutsideTheGDPRSweep(t *testing.T) {
	sql := stripSQLComments(read(t, "queries/purger.sql"))

	// Inspect each DELETE statement on its own. Splitting on the sqlc
	// name markers would not work here: stripSQLComments removed them
	// along with every other comment.
	for _, stmt := range strings.Split(sql, ";") {
		if !strings.Contains(strings.ToUpper(stmt), "DELETE") {
			continue
		}
		if !strings.Contains(stmt, "guardrail_decisions") {
			continue
		}
		if strings.Contains(stmt, "24 months") {
			continue // the sanctioned retention sweep
		}
		for _, gdprInterval := range []string{"30 days", "90 days", "7 days", "1 month", "3 months"} {
			if strings.Contains(stmt, gdprInterval) {
				t.Fatalf("guardrail_decisions is swept on a GDPR interval (%s). "+
					"It is the MDR article 94 evidence pack with a 24-month "+
					"retention and must stay out of that cycle — see migration "+
					"000085 and ADR 62 section 9.", gdprInterval)
			}
		}
		t.Fatalf("guardrail_decisions has a DELETE with no 24-month bound:%s", stmt)
	}
}

// The GDPR purge queries must not reach the table by any name.
func TestGDPRPurgeQueriesDoNotNameTheEvidenceLog(t *testing.T) {
	raw := read(t, "queries/purger.sql")
	for _, stmt := range strings.Split(raw, "-- name:") {
		name := strings.TrimSpace(strings.SplitN(stmt, " ", 2)[0])
		if !strings.HasPrefix(name, "Purge") || name == "PurgeExpiredGuardrailDecisions" {
			continue
		}
		if strings.Contains(stmt, "guardrail_decisions") {
			t.Errorf("GDPR purge query %s touches guardrail_decisions", name)
		}
	}
}

// The real cascade risk is not a DELETE in purger.sql — it is a foreign
// key. An FK from guardrail_decisions to patient_files would delete the
// evidence as a side effect of erasing a patient file, with nothing in
// the purger to review. The migration has no FKs on purpose; this test
// makes that a rule rather than a fact about today's file.
func TestEvidenceLogHasNoForeignKeys(t *testing.T) {
	path := filepath.Join("..", "..", "..", "..", "..", "migrations", "000085_guardrail_decisions.up.sql")
	sql := read(t, path)

	body := sql[strings.Index(sql, "CREATE TABLE guardrail_decisions"):]
	body = body[:strings.Index(body, ");")]

	if regexp.MustCompile(`(?i)\breferences\b`).MatchString(body) {
		t.Error("guardrail_decisions declares a foreign key. Any FK to patient " +
			"data creates a cascade path that erases the MDR evidence pack as a " +
			"side effect of a GDPR deletion.")
	}
	for _, forbidden := range []string{"patient_file_id", "therapist_id", "session_id", "user_id"} {
		if regexp.MustCompile(`(?i)\b` + forbidden + `\b`).MatchString(body) {
			t.Errorf("guardrail_decisions has column %q — the evidence log must not "+
				"join back to patient material (migration 000085 header)", forbidden)
		}
	}
}

// The evidence log must not accumulate conversation content. A column
// holding the question, the answer or the classifier's rationale would
// make it a second, less protected copy of clinical material.
func TestEvidenceLogHoldsNoConversationContent(t *testing.T) {
	path := filepath.Join("..", "..", "..", "..", "..", "migrations", "000085_guardrail_decisions.up.sql")
	sql := read(t, path)
	body := sql[strings.Index(sql, "CREATE TABLE guardrail_decisions"):]
	body = body[:strings.Index(body, ");")]

	for _, forbidden := range []string{"question", "answer", "rationale", "content", "quote_text", "prompt_text"} {
		if regexp.MustCompile(`(?i)^\s*`+forbidden+`\s`).MatchString(body) ||
			regexp.MustCompile(`(?i)\n\s*`+forbidden+`\s+(TEXT|VARCHAR|BYTEA|JSONB)`).MatchString(body) {
			t.Errorf("guardrail_decisions has a %q column — it must record the SHAPE "+
				"of decisions, never their content", forbidden)
		}
	}
}
