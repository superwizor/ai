package grpc

import (
	"strings"
	"testing"
)

func TestHtmlEscapeVars(t *testing.T) {
	in := map[string]string{
		"organization_name": `<script>alert(1)</script>`,
		"inviter_first_name": `Tom & "Jerry"`,
		"safe":               "plain text",
	}
	out := htmlEscapeVars(in)
	if strings.Contains(out["organization_name"], "<script>") {
		t.Errorf("script tag not escaped: %q", out["organization_name"])
	}
	if !strings.Contains(out["organization_name"], "&lt;script&gt;") {
		t.Errorf("expected escaped entities, got %q", out["organization_name"])
	}
	if !strings.Contains(out["inviter_first_name"], "&amp;") || !strings.Contains(out["inviter_first_name"], "&#34;") {
		t.Errorf("& and \" should be escaped, got %q", out["inviter_first_name"])
	}
	if out["safe"] != "plain text" {
		t.Errorf("plain text should be unchanged, got %q", out["safe"])
	}
	// The original map must not be mutated.
	if in["organization_name"] != `<script>alert(1)</script>` {
		t.Errorf("input map mutated")
	}
}

// End-to-end: an escaped org name fed through bodyToHTML must not produce a
// live <script> element — the whole point of #13.
func TestBodyToHTML_EscapedVarsAreInert(t *testing.T) {
	vars := map[string]string{"organization_name": `<img src=x onerror=alert(1)>`}
	escaped := htmlEscapeVars(vars)
	body := "You were invited to " + escaped["organization_name"] + "\n\nClick https://app.superwizor.ai/accept"
	out := bodyToHTML(body)
	if strings.Contains(out, "<img src=x") {
		t.Errorf("unescaped img tag leaked into HTML: %s", out)
	}
	if !strings.Contains(out, "&lt;img") {
		t.Errorf("expected escaped img, got: %s", out)
	}
	// The template's own trusted URL should still be linkified.
	if !strings.Contains(out, `<a href="https://app.superwizor.ai/accept">`) {
		t.Errorf("trusted URL should still linkify, got: %s", out)
	}
}
