package grpc

import (
	"context"
	"strconv"
	"strings"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/email"
	"github.com/superwizor-ai/backend/services/notification-svc/internal/i18n"
)

// SendInvitationEmail is the internal RPC identity-svc calls from
// InviteTherapist. NOT exposed to client traffic — the gRPC auth
// pattern for service-to-service inside the project relies on Cloud
// Run IAM (no Firebase ID token needed; the caller's SA owns the
// invoker binding on notification-svc).
//
// docs/18 §6.5, §14.7.
func (s *Server) SendInvitationEmail(ctx context.Context, req *notificationv1.SendInvitationEmailRequest) (*emptypb.Empty, error) {
	if strings.TrimSpace(req.GetRecipientEmail()) == "" {
		return nil, status.Error(codes.InvalidArgument, "recipient_email required")
	}
	if strings.TrimSpace(req.GetAcceptUrl()) == "" {
		return nil, status.Error(codes.InvalidArgument, "accept_url required")
	}
	if strings.TrimSpace(req.GetOrganizationName()) == "" {
		return nil, status.Error(codes.InvalidArgument, "organization_name required")
	}

	// Template by invited role (docs/38): org managers get the
	// org_manager_invite onboarding copy; therapists keep the classic
	// invitation. Empty role = old callers = therapist.
	templateKey := "invitation"
	switch req.GetInvitedRole() {
	case "ORG_ADMIN":
		templateKey = "org_manager_invite"
	case "PATIENT":
		templateKey = "patient_invite" // docs/39 — client panel onboarding
	}
	tpl, err := i18n.Load(req.GetLocale(), templateKey)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load template: %v", err)
	}
	subject, body := tpl.Render(map[string]string{
		"recipient_email":    req.GetRecipientEmail(),
		"organization_name":  req.GetOrganizationName(),
		"inviter_first_name": inviterOrDefault(req.GetInviterFirstName()),
		"accept_url":         req.GetAcceptUrl(),
		"expires_at":         req.GetExpiresAtIso(),
	})

	if err := s.emailer.Send(ctx, email.Message{
		To:       req.GetRecipientEmail(),
		Subject:  subject,
		HTMLBody: bodyToHTML(body),
		TextBody: body,
		From:     tpl.From,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "send email: %v", err)
	}
	return &emptypb.Empty{}, nil
}

// SendEmailVerification dispatches a "confirm your email" message using
// the localized template under
// services/notification-svc/internal/i18n/templates/{locale}/email_verification.md.
// Like SendInvitationEmail this is an internal RPC; identity-svc calls
// it after Firebase Auth's createUser to deliver the verification link
// under our own branding.
func (s *Server) SendEmailVerification(ctx context.Context, req *notificationv1.SendEmailVerificationRequest) (*emptypb.Empty, error) {
	if strings.TrimSpace(req.GetRecipientEmail()) == "" {
		return nil, status.Error(codes.InvalidArgument, "recipient_email required")
	}
	if strings.TrimSpace(req.GetVerifyUrl()) == "" {
		return nil, status.Error(codes.InvalidArgument, "verify_url required")
	}

	tpl, err := i18n.Load(req.GetLocale(), "email_verification")
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load template: %v", err)
	}
	subject, body := tpl.Render(map[string]string{
		"recipient_email": req.GetRecipientEmail(),
		"first_name":      firstNameOrDefault(req.GetFirstName(), req.GetLocale()),
		"verify_url":      req.GetVerifyUrl(),
		"expires_at":      req.GetExpiresAtIso(),
	})

	// Use the branded HTML template; fall back to bodyToHTML if unavailable.
	firstName := firstNameOrDefault(req.GetFirstName(), req.GetLocale())
	htmlBody := verificationEmailHTML(req.GetLocale(), firstName, req.GetVerifyUrl(), subject)
	if htmlBody == "" {
		htmlBody = bodyToHTML(body)
	}

	if err := s.emailer.Send(ctx, email.Message{
		To:       req.GetRecipientEmail(),
		Subject:  subject,
		HTMLBody: htmlBody,
		TextBody: body,
		From:     tpl.From,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "send email: %v", err)
	}
	return &emptypb.Empty{}, nil
}

// SendQuotaWarning is fired from billing-svc when the org crosses
// 80% / 95% of its monthly token quota for the first time in the
// period. Idempotency is the caller's concern — we always send.
//
// Placeholder set in templates/{locale}/quota_warning.md:
//
//	{first_name}, {organization_name}, {usage_percent}, {tokens_remaining},
//	{plan_tier}, {plan_cycle}, {period_end}, {billing_url}.
func (s *Server) SendQuotaWarning(ctx context.Context, req *notificationv1.SendQuotaWarningRequest) (*emptypb.Empty, error) {
	if strings.TrimSpace(req.GetRecipientEmail()) == "" {
		return nil, status.Error(codes.InvalidArgument, "recipient_email required")
	}
	if strings.TrimSpace(req.GetOrganizationName()) == "" {
		return nil, status.Error(codes.InvalidArgument, "organization_name required")
	}
	if req.GetUsagePercent() <= 0 || req.GetUsagePercent() > 100 {
		return nil, status.Error(codes.InvalidArgument, "usage_percent must be 1..100")
	}

	tpl, err := i18n.Load(req.GetLocale(), "quota_warning")
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load template: %v", err)
	}
	subject, body := tpl.Render(map[string]string{
		"recipient_email":   req.GetRecipientEmail(),
		"first_name":        firstNameOrDefault(req.GetFirstName(), req.GetLocale()),
		"organization_name": req.GetOrganizationName(),
		"usage_percent":     strconv.Itoa(int(req.GetUsagePercent())),
		"tokens_remaining":  strconv.Itoa(int(req.GetTokensRemaining())),
		"plan_tier":         req.GetPlanTier(),
		"plan_cycle":        req.GetPlanCycle(),
		"period_end":        req.GetPeriodEndIso(),
		"billing_url":       req.GetBillingUrl(),
	})
	if err := s.emailer.Send(ctx, email.Message{
		To:       req.GetRecipientEmail(),
		Subject:  subject,
		HTMLBody: bodyToHTML(body),
		TextBody: body,
		From:     tpl.From,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "send email: %v", err)
	}
	return &emptypb.Empty{}, nil
}

// firstNameOrDefault picks a friendly greeting fallback per locale so
// an empty first_name doesn't render a literal "Hi ,". This is the
// same pattern inviterOrDefault uses for the invitation flow.
func firstNameOrDefault(s, locale string) string {
	if strings.TrimSpace(s) != "" {
		return s
	}
	loc := strings.ToLower(strings.TrimSpace(locale))
	if strings.HasPrefix(loc, "en") {
		return "there"
	}
	return "" // PL: drop the placeholder entirely; subject still works
}

func inviterOrDefault(s string) string {
	if strings.TrimSpace(s) == "" {
		return "Twój kolega" // PL fallback; EN template's user fills it in
	}
	return s
}

// bodyToHTML is the minimum-viable Markdown-ish conversion the
// invitation templates need: paragraphs separated by blank lines,
// **bold**, and bare URLs become <a> tags. We deliberately don't
// pull in a full Markdown renderer for a one-shot template.
func bodyToHTML(body string) string {
	// Split on double newline to detect paragraphs.
	paras := strings.Split(strings.TrimSpace(body), "\n\n")
	var sb strings.Builder
	sb.WriteString("<html><body style=\"font-family:system-ui,sans-serif;\">")
	for _, p := range paras {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		// **bold** → <strong>
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
		// Bare https?:// URLs → <a>
		// (one URL per paragraph max; the templates we own don't violate this.)
		if idx := strings.Index(p, "https://"); idx >= 0 {
			end := strings.IndexAny(p[idx:], " \n\t")
			if end < 0 {
				end = len(p) - idx
			}
			url := p[idx : idx+end]
			p = p[:idx] + `<a href="` + url + `">` + url + `</a>` + p[idx+end:]
		}
		// Newlines inside a paragraph → <br>
		p = strings.ReplaceAll(p, "\n", "<br>")
		sb.WriteString("<p>")
		sb.WriteString(p)
		sb.WriteString("</p>")
	}
	sb.WriteString("</body></html>")
	return sb.String()
}
