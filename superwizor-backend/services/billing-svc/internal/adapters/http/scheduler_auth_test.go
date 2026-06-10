package http

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"google.golang.org/api/idtoken"
)

const (
	testAudience = "https://billing-svc-test.a.run.app"
	testSAEmail  = "cloud-scheduler-billing@test-project.iam.gserviceaccount.com"
)

func schedulerPayload(email string, verified bool) *idtoken.Payload {
	return &idtoken.Payload{
		Issuer:   "https://accounts.google.com",
		Audience: testAudience,
		Claims: map[string]interface{}{
			"email":          email,
			"email_verified": verified,
		},
	}
}

func runSchedAuthed(t *testing.T, mw *SchedulerAuthMiddleware, authHeader string) (*httptest.ResponseRecorder, bool) {
	t.Helper()
	handlerRan := false
	h := mw.Require(func(w http.ResponseWriter, r *http.Request) {
		handlerRan = true
		w.WriteHeader(http.StatusOK)
	})
	req := httptest.NewRequest(http.MethodPost, "/admin/email-drip", nil)
	if authHeader != "" {
		req.Header.Set("Authorization", authHeader)
	}
	rec := httptest.NewRecorder()
	h(rec, req)
	return rec, handlerRan
}

func newSchedMW(validate idTokenValidator) *SchedulerAuthMiddleware {
	mw := NewSchedulerAuthMiddleware(testAudience, testSAEmail, slog.Default())
	mw.validate = validate
	return mw
}

func TestSchedulerAuth_FailClosedWithoutAudience(t *testing.T) {
	mw := NewSchedulerAuthMiddleware("", testSAEmail, slog.Default())
	mw.validate = func(ctx context.Context, token, audience string) (*idtoken.Payload, error) {
		t.Fatal("validator must not be called when audience is unset")
		return nil, nil
	}
	rec, ran := runSchedAuthed(t, mw, "Bearer whatever")
	if rec.Code != http.StatusServiceUnavailable || ran {
		t.Errorf("unset audience must 503 and never run the handler; got %d ran=%v", rec.Code, ran)
	}
}

func TestSchedulerAuth_FailClosedWithoutSAEmail(t *testing.T) {
	mw := NewSchedulerAuthMiddleware(testAudience, "", slog.Default())
	mw.validate = func(ctx context.Context, token, audience string) (*idtoken.Payload, error) {
		t.Fatal("validator must not be called when SA email is unset")
		return nil, nil
	}
	rec, ran := runSchedAuthed(t, mw, "Bearer whatever")
	if rec.Code != http.StatusServiceUnavailable || ran {
		t.Errorf("unset SA email must 503 and never run the handler; got %d ran=%v", rec.Code, ran)
	}
}

func TestSchedulerAuth_MissingToken(t *testing.T) {
	mw := newSchedMW(func(ctx context.Context, token, audience string) (*idtoken.Payload, error) {
		t.Fatal("validator must not be called without a bearer token")
		return nil, nil
	})
	rec, ran := runSchedAuthed(t, mw, "")
	if rec.Code != http.StatusUnauthorized || ran {
		t.Errorf("missing token: want 401, got %d ran=%v", rec.Code, ran)
	}
}

func TestSchedulerAuth_InvalidToken(t *testing.T) {
	mw := newSchedMW(func(ctx context.Context, token, audience string) (*idtoken.Payload, error) {
		return nil, errors.New("idtoken: token expired")
	})
	rec, ran := runSchedAuthed(t, mw, "Bearer expired")
	if rec.Code != http.StatusUnauthorized || ran {
		t.Errorf("invalid token: want 401, got %d ran=%v", rec.Code, ran)
	}
}

func TestSchedulerAuth_WrongServiceAccount(t *testing.T) {
	mw := newSchedMW(func(ctx context.Context, token, audience string) (*idtoken.Payload, error) {
		return schedulerPayload("attacker@evil-project.iam.gserviceaccount.com", true), nil
	})
	rec, ran := runSchedAuthed(t, mw, "Bearer other-sa")
	if rec.Code != http.StatusForbidden || ran {
		t.Errorf("wrong SA: want 403, got %d ran=%v", rec.Code, ran)
	}
}

func TestSchedulerAuth_UnverifiedEmail(t *testing.T) {
	mw := newSchedMW(func(ctx context.Context, token, audience string) (*idtoken.Payload, error) {
		return schedulerPayload(testSAEmail, false), nil
	})
	rec, ran := runSchedAuthed(t, mw, "Bearer unverified")
	if rec.Code != http.StatusForbidden || ran {
		t.Errorf("unverified email: want 403, got %d ran=%v", rec.Code, ran)
	}
}

func TestSchedulerAuth_MissingEmailClaim(t *testing.T) {
	mw := newSchedMW(func(ctx context.Context, token, audience string) (*idtoken.Payload, error) {
		return &idtoken.Payload{Audience: testAudience, Claims: map[string]interface{}{}}, nil
	})
	rec, ran := runSchedAuthed(t, mw, "Bearer no-email")
	if rec.Code != http.StatusForbidden || ran {
		t.Errorf("missing email claim: want 403, got %d ran=%v", rec.Code, ran)
	}
}

func TestSchedulerAuth_SchedulerSAPasses(t *testing.T) {
	mw := newSchedMW(func(ctx context.Context, token, audience string) (*idtoken.Payload, error) {
		if token != "scheduler-token" {
			t.Errorf("token not forwarded: %q", token)
		}
		if audience != testAudience {
			t.Errorf("audience not forwarded: %q", audience)
		}
		return schedulerPayload(testSAEmail, true), nil
	})
	rec, ran := runSchedAuthed(t, mw, "Bearer scheduler-token")
	if rec.Code != http.StatusOK || !ran {
		t.Errorf("scheduler SA: want 200 + handler run, got %d ran=%v", rec.Code, ran)
	}
}
