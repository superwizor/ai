package i18n

import (
	"strings"
	"testing"
)

// TestLoad_AllTemplates_BothLocales catches frontmatter / parse errors at
// compile-test time. Every (locale, template) pair we ship must load and
// render without leaving placeholder markers behind. We pass an
// intentionally-incomplete vars map for each — what we care about here is
// that the template files parse and Render() substitutes the keys we
// document in the proto.
func TestLoad_AllTemplates_BothLocales(t *testing.T) {
	cases := []struct {
		name string
		vars map[string]string
	}{
		{
			name: "invitation",
			vars: map[string]string{
				"recipient_email":    "x@example.com",
				"organization_name":  "Klinika Sosna",
				"inviter_first_name": "Anna",
				"accept_url":         "https://example.com/accept/abc",
				"expires_at":         "2026-06-01",
			},
		},
		{
			// docs/38: org-manager onboarding (AdminCreateOrganization).
			name: "org_manager_invite",
			vars: map[string]string{
				"organization_name": "Klinika Sosna",
				"accept_url":        "https://example.com/accept/abc",
				"expires_at":        "2026-06-01",
			},
		},
		{
			name: "email_verification",
			vars: map[string]string{
				"recipient_email": "x@example.com",
				"first_name":      "Anna",
				"verify_url":      "https://example.com/verify/xyz",
				"expires_at":      "2026-06-01",
			},
		},
		{
			name: "quota_warning",
			vars: map[string]string{
				"recipient_email":   "x@example.com",
				"first_name":        "Anna",
				"organization_name": "Klinika Sosna",
				"usage_percent":     "80",
				"tokens_remaining":  "12000",
				"plan_tier":         "PRO",
				"plan_cycle":        "MONTHLY",
				"period_end":        "2026-06-30",
				"billing_url":       "https://example.com/admin/billing",
			},
		},
	}

	for _, loc := range []string{"pl", "en"} {
		for _, c := range cases {
			t.Run(loc+"/"+c.name, func(t *testing.T) {
				tpl, err := Load(loc, c.name)
				if err != nil {
					t.Fatalf("Load(%q, %q): %v", loc, c.name, err)
				}
				if tpl.Subject == "" {
					t.Fatalf("Load(%q, %q): empty subject", loc, c.name)
				}
				subject, body := tpl.Render(c.vars)

				// Every {key} we PASSED must be substituted. Unknown
				// keys still in the body would be a template bug.
				for k := range c.vars {
					marker := "{" + k + "}"
					if strings.Contains(subject, marker) || strings.Contains(body, marker) {
						t.Errorf("Render(%q, %q): placeholder %s not substituted", loc, c.name, marker)
					}
				}
				// And the rendered output should be non-trivial.
				if len(body) < 20 {
					t.Errorf("Render(%q, %q): body suspiciously short: %q", loc, c.name, body)
				}
			})
		}
	}
}

// TestLoad_UnknownLocaleFallsBackToPL verifies the documented fallback
// in templater.go: an unsupported locale uses the PL template rather
// than failing the email send.
func TestLoad_UnknownLocaleFallsBackToPL(t *testing.T) {
	tpl, err := Load("de", "invitation")
	if err != nil {
		t.Fatalf("Load(de, invitation): %v", err)
	}
	// Should match the PL subject (the unsupported locale takes
	// normalizeLocale's default → "pl").
	if !strings.Contains(tpl.Subject, "zaprasza") {
		t.Errorf("expected PL fallback subject, got %q", tpl.Subject)
	}
}
