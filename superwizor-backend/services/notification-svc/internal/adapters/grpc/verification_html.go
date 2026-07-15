package grpc

import (
	"strings"

	"github.com/superwizor-ai/backend/services/notification-svc/internal/i18n"
)

// verificationEmailStrings holds locale-specific strings for the branded
// HTML verification email.
type verificationEmailStrings struct {
	Lang          string
	Heading       string
	Greeting      string
	BodyText      string
	CTAText       string
	FallbackLabel string
	SafetyNote    string
	SignOff       string
	TeamName      string
}

func verificationStringsFor(locale, firstName string) verificationEmailStrings {
	loc := strings.ToLower(strings.TrimSpace(locale))
	if loc == "" || strings.HasPrefix(loc, "pl") {
		return verificationEmailStrings{
			Lang:          "pl",
			Heading:       "Potwierdź adres e-mail",
			Greeting:      "Cześć " + firstName + ".",
			BodyText:      "Został ostatni krok. Kliknij przycisk, aby zweryfikować konto i przejść do konfiguracji i instalacji aplikacji.",
			CTAText:       "Potwierdź adres e-mail",
			FallbackLabel: "Przycisk nie działa? Skopiuj i wklej ten link w przeglądarce:",
			SafetyNote:    "Nie zakładałeś tu konta? Zignoruj tę wiadomość.",
			SignOff:       "Pozdrawiamy,",
			TeamName:      "Zespół Superwizor AI",
		}
	}
	return verificationEmailStrings{
		Lang:          "en",
		Heading:       "Confirm your email address",
		Greeting:      "Hi " + firstName + ".",
		BodyText:      "One last step. Click the button below to verify your account and continue to app installation and setup.",
		CTAText:       "Confirm email address",
		FallbackLabel: "Button not working? Copy and paste this link in your browser:",
		SafetyNote:    "Didn't create an account here? You can ignore this message.",
		SignOff:       "Warm regards,",
		TeamName:      "The Superwizor AI team",
	}
}

//go:generate echo "HTML template loaded from i18n/templates/email_verification.html"

// verificationEmailHTML builds the branded HTML body for the email
// verification message.
func verificationEmailHTML(locale, firstName, verifyURL, subject string) string {
	s := verificationStringsFor(locale, firstName)
	html := i18n.LoadHTMLTemplate("email_verification")
	if html == "" {
		return ""
	}

	r := strings.NewReplacer(
		"{{lang}}", s.Lang,
		"{{subject}}", subject,
		"{{heading}}", s.Heading,
		"{{greeting}}", s.Greeting,
		"{{body_text}}", s.BodyText,
		"{{cta_text}}", s.CTAText,
		"{{verify_url}}", verifyURL,
		"{{fallback_label}}", s.FallbackLabel,
		"{{safety_note}}", s.SafetyNote,
		"{{sign_off}}", s.SignOff,
		"{{team_name}}", s.TeamName,
	)
	return r.Replace(html)
}
