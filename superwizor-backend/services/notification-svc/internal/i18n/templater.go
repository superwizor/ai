// Package i18n is notification-svc's localised email/push template
// engine. Templates live at templates/{locale}/<event>.md with a YAML
// frontmatter block carrying the subject + (optionally) a from
// override. The body is rendered with simple {var} substitution.
//
// Reference: docs/18 §14.7.
package i18n

import (
	"embed"
	"fmt"
	"strings"
)

//go:embed templates
var templatesFS embed.FS

// Template is a parsed template ready to render. Subject + Body still
// contain {placeholder} markers — call Render to substitute.
type Template struct {
	Subject string
	Body    string
	From    string // optional override; empty means use sender default
}

// Render replaces every {key} occurrence in subject + body with
// vars[key]. Missing keys leave the placeholder untouched (loud
// failure — easier to spot than silent empty substitution).
func (t Template) Render(vars map[string]string) (subject, body string) {
	subject = substitute(t.Subject, vars)
	body = substitute(t.Body, vars)
	return
}

// Load reads templates/{locale}/<name>.md from the embedded FS. Falls
// back to "pl" (the primary market) when the requested locale doesn't
// have a template. Returns NotFound only when even the "pl" template
// is missing.
func Load(locale, name string) (Template, error) {
	locale = normalizeLocale(locale)
	path := fmt.Sprintf("templates/%s/%s.md", locale, name)
	data, err := templatesFS.ReadFile(path)
	if err != nil && locale != "pl" {
		// Locale fallback.
		path = fmt.Sprintf("templates/pl/%s.md", name)
		data, err = templatesFS.ReadFile(path)
	}
	if err != nil {
		return Template{}, fmt.Errorf("template %q/%q not found: %w", locale, name, err)
	}
	return parse(data)
}

// LoadHTMLTemplate reads a shared (locale-independent) HTML template
// from templates/<name>.html. Returns empty string if the file doesn't
// exist, so callers can gracefully degrade to bodyToHTML.
func LoadHTMLTemplate(name string) string {
	path := fmt.Sprintf("templates/%s.html", name)
	data, err := templatesFS.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(data)
}

// parse splits the YAML frontmatter from the body. Frontmatter is a
// minimal subset: lines of "key: value" between two "---" fences at the
// top of the file. Only `subject` and `from` are recognised — anything
// else is ignored.
func parse(data []byte) (Template, error) {
	s := string(data)
	if !strings.HasPrefix(s, "---\n") {
		return Template{}, fmt.Errorf("template missing frontmatter")
	}
	end := strings.Index(s[4:], "\n---\n")
	if end < 0 {
		return Template{}, fmt.Errorf("template frontmatter unterminated")
	}
	frontmatter := s[4 : 4+end]
	body := strings.TrimLeft(s[4+end+5:], "\n")

	t := Template{Body: body}
	for _, line := range strings.Split(frontmatter, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		colon := strings.Index(line, ":")
		if colon < 0 {
			continue
		}
		key := strings.TrimSpace(line[:colon])
		val := strings.Trim(strings.TrimSpace(line[colon+1:]), `"`)
		switch key {
		case "subject":
			t.Subject = val
		case "from":
			t.From = val
		}
	}
	if t.Subject == "" {
		return Template{}, fmt.Errorf("template missing 'subject' in frontmatter")
	}
	return t, nil
}

func substitute(s string, vars map[string]string) string {
	for k, v := range vars {
		s = strings.ReplaceAll(s, "{"+k+"}", v)
	}
	return s
}

func normalizeLocale(loc string) string {
	loc = strings.ToLower(strings.TrimSpace(loc))
	if loc == "" {
		return "pl"
	}
	// Strip region (en-GB → en, pl-PL → pl).
	if i := strings.IndexAny(loc, "-_"); i > 0 {
		loc = loc[:i]
	}
	switch loc {
	case "pl", "en":
		return loc
	}
	return "pl"
}
