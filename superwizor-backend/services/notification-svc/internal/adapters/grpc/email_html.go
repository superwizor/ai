package grpc

import (
	"strings"

	"github.com/superwizor-ai/backend/services/notification-svc/internal/i18n"
)

// genericEmailStrings holds localized strings for the generic layout
type genericEmailStrings struct {
	Lang          string
	FallbackLabel string
	SafetyNote    string
	SignOff       string
	TeamName      string
}

func genericStringsFor(locale string) genericEmailStrings {
	loc := strings.ToLower(strings.TrimSpace(locale))
	if loc == "" || strings.HasPrefix(loc, "pl") {
		return genericEmailStrings{
			Lang:          "pl",
			FallbackLabel: "Przycisk nie działa? Skopiuj i wklej ten link w przeglądarce:",
			SafetyNote:    "Wiadomość została wysłana automatycznie przez system Superwizor AI.",
			SignOff:       "Pozdrawiamy,",
			TeamName:      "Zespół Superwizor AI",
		}
	}
	return genericEmailStrings{
		Lang:          "en",
		FallbackLabel: "Button not working? Copy and paste this link in your browser:",
		SafetyNote:    "This is an automated message sent by the Superwizor AI system.",
		SignOff:       "Warm regards,",
		TeamName:      "The Superwizor AI team",
	}
}

// wrapWithGenericTemplate takes a plain-text markdown-ish body, formats it into HTML,
// and embeds it inside the beautiful branded generic_email.html layout.
//
// Optional: ctaURL and ctaText can be provided to render a primary yellow CTA button.
func wrapWithGenericTemplate(locale, subject, heading, bodyText, ctaURL, ctaText string) string {
	s := genericStringsFor(locale)
	html := i18n.LoadHTMLTemplate("generic_email")
	if html == "" {
		// Fallback to minimal markup if template fails to load
		return bodyToHTML(bodyText)
	}

	// Render Markdown-ish body text to HTML paragraphs/bolding
	bodyHTML := markdownToHTMLContent(bodyText, ctaURL)

	// Build CTA section if ctaURL is present
	ctaSection := ""
	if ctaURL != "" {
		if ctaText == "" {
			if s.Lang == "pl" {
				ctaText = "Przejdź dalej"
			} else {
				ctaText = "Continue"
			}
		}
		ctaSection = `
          <!-- Body <-> CTA: 32px -->
          <tr>
            <td align="left" style="padding:32px 40px 0;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center" style="background-color:#FCAE2F;border-radius:8px;">
                    <a href="` + ctaURL + `" target="_blank" style="display:inline-block;padding:14px 32px;font-size:16px;font-weight:600;color:#111827;text-decoration:none;border-radius:8px;">
                      ` + ctaText + `
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- CTA <-> Divider: 40px -->
          <tr>
            <td style="padding:40px 40px 0;">
              <div style="height:1px;background-color:#005C64;"></div>
            </td>
          </tr>

          <!-- Divider <-> Fallback Link: 24px -->
          <tr>
            <td align="left" style="padding:24px 40px 0;">
              <p style="margin:0;font-size:13px;font-weight:400;color:#D1D5DB;line-height:1.4;">
                ` + s.FallbackLabel + `
              </p>
            </td>
          </tr>

          <tr>
            <td align="left" style="padding:8px 40px 0;">
              <p style="margin:0;font-size:13px;font-weight:400;color:#D1D5DB;line-height:1.4;word-break:break-all;">
                <a href="` + ctaURL + `" style="color:#FCAE2F;text-decoration:underline;">` + ctaURL + `</a>
              </p>
            </td>
          </tr>`
	}

	safetySection := ""
	if s.SafetyNote != "" {
		safetySection = `
          <!-- Link <-> Safety Note: 24px -->
          <tr>
            <td align="left" style="padding:24px 40px 0;">
              <p style="margin:0;font-size:13px;font-weight:400;color:#9CA3AF;line-height:1.4;">
                ` + s.SafetyNote + `
              </p>
            </td>
          </tr>`
	}

	r := strings.NewReplacer(
		"{{lang}}", s.Lang,
		"{{subject}}", subject,
		"{{heading}}", heading,
		"{{body_html}}", bodyHTML,
		"{{cta_section}}", ctaSection,
		"{{safety_section}}", safetySection,
		"{{sign_off}}", s.SignOff,
		"{{team_name}}", s.TeamName,
	)

	return r.Replace(html)
}

// markdownToHTMLContent converts plain-text markdown-ish paragraphs, bold text,
// and bullet lists into clean HTML tags for email client compatibility.
// If a ctaURL is specified, we remove that URL from the inline text flow to prevent redundancy.
func markdownToHTMLContent(body string, ctaURLToOmit string) string {
	// Clean up newlines
	body = strings.ReplaceAll(body, "\r\n", "\n")
	paras := strings.Split(strings.TrimSpace(body), "\n\n")

	var sb strings.Builder
	for _, p := range paras {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}

		// Handle bullet lists
		if strings.HasPrefix(p, "- ") || strings.HasPrefix(p, "* ") {
			lines := strings.Split(p, "\n")
			sb.WriteString("<ul style=\"margin:0 0 16px 0;padding-left:20px;color:#D1D5DB;\">")
			for _, line := range lines {
				line = strings.TrimSpace(line)
				if line == "" {
					continue
				}
				// strip bullets
				if strings.HasPrefix(line, "- ") {
					line = line[2:]
				} else if strings.HasPrefix(line, "* ") {
					line = line[2:]
				}
				line = formatTextInline(line, ctaURLToOmit)
				sb.WriteString("<li style=\"margin-bottom:8px;line-height:1.5;\">" + line + "</li>")
			}
			sb.WriteString("</ul>")
			continue
		}

		// Regular paragraphs
		p = formatTextInline(p, ctaURLToOmit)
		sb.WriteString("<p style=\"margin:0 0 16px 0;line-height:1.6;\">" + p + "</p>")
	}

	return sb.String()
}

func formatTextInline(p string, ctaURLToOmit string) string {
	// **bold** -> <strong>
	for {
		start := strings.Index(p, "**")
		if start < 0 {
			break
		}
		end := strings.Index(p[start+2:], "**")
		if end < 0 {
			break
		}
		p = p[:start] + "<strong>" + p[start+2:start+2+end] + "</strong>" + p[start+2+end+2:]
	}

	// Linkify URLs or strip the CTA URL if it's rendered as a primary button
	if ctaURLToOmit != "" {
		p = strings.ReplaceAll(p, ctaURLToOmit, "")
		p = strings.ReplaceAll(p, "→ ", "")
		p = strings.ReplaceAll(p, "-> ", "")
	}

	// Linkify remaining https:// URLs
	// Go paragraph may contain simple links
	for {
		idx := strings.Index(p, "https://")
		if idx < 0 {
			break
		}
		// find word end
		end := strings.IndexAny(p[idx:], " \n\t)]\"'")
		if end < 0 {
			end = len(p) - idx
		}
		url := p[idx : idx+end]
		// Prevent double-wrapping if already processed
		if idx > 9 && p[idx-9:idx] == `href="` {
			// Skip this instance, break loop or skip word to prevent infinite loop
			placeholder := strings.Replace(url, "https://", "h__ps://", 1)
			p = p[:idx] + placeholder + p[idx+end:]
			continue
		}
		linkHTML := `<a href="` + url + `" style="color:#FCAE2F;text-decoration:underline;">` + url + `</a>`
		p = p[:idx] + linkHTML + p[idx+end:]
	}

	// Restore any masked https linkifications
	p = strings.ReplaceAll(p, "h__ps://", "https://")

	// Convert single newlines inside paragraph to <br>
	p = strings.ReplaceAll(p, "\n", "<br>")

	return p
}
