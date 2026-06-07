//go:build e2e
// +build e2e

// E2E tests dla billing-svc (Phase 3).
//
// Run:
//   cd superwizor-backend/tests
//   go test -tags=e2e -timeout=10m -v ./e2e/... -run TestBilling
//
// Required environment:
//   - gcloud authenticated (`gcloud auth print-identity-token` musi działać)
//   - DATABASE_URL — direct connection do Cloud SQL (przez cloud-sql-proxy
//     lub bezpośrednio jeśli IP-allow-listed). Format:
//     postgres://USER:PASS@HOST:5432/DB?sslmode=disable
//   - BILLING_SVC_URL (opcjonalnie; jeśli pusty, `gcloud run services describe`)
//   - BILLING_ORG_ID — UUID organizacji z aktywną MANUAL subscription
//     (z migracji 000030). Jeśli pusty, test ją wykryje sam.
//   - BILLING_THERAPIST_ID — UUID dowolnego therapisty w tej organizacji.
//
// Auth model: billing-svc jest internal (no Cloud Run allUsers binding),
// więc używamy `gcloud auth print-identity-token --audiences=<URL>` do
// uzyskania OIDC tokenu. Cloud Run frontend waliduje signaturę i sprawdza
// czy SA wywołującego ma run.invoker (twoje user @ ma to przez ownership).
//
// Test cleanup:
//   Każdy test używa UNIQUE session_id (UUID), więc nie ma kolizji między
//   testami. Po teście cleanup deletuje swoje rzędy z usage_events,
//   pending_reservations.
//
// Edge cases pokryte:
//   - Token calculator boundary (45/63/64/120/123min)
//   - Idempotency (2x ten sam session_id)
//   - Quota exhausted gate
//   - ReserveCredit → ReleaseCredit roundtrip
//   - ReserveCredit → CommitUsage transfer
//   - PAST_DUE blokuje reservation
//   - Stale reservation expiry (manual /admin/reservation-expiry call)
package e2e_test

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
)

// billingTestEnv — wspólny setup dla wszystkich billing E2E testów.
type billingTestEnv struct {
	billingURL    string
	billingHost   string // host:443 dla grpc.NewClient
	billingHTTPURL string // dla admin HTTP endpoints
	dbPool        *pgxpool.Pool
	orgID         uuid.UUID
	therapistID   uuid.UUID
	idToken       string // OIDC token z audience = billing-svc URL
}

// tryLoadBillingEnv — soft variant used by full_session_test for the
// CommitUsage assertion. Returns (env, true) if DATABASE_URL is set and
// connectable, (nil, false) otherwise (test infra not seeded — skip
// silently rather than failing the whole full-session test).
func tryLoadBillingEnv(t *testing.T) (*billingTestEnv, bool) {
	t.Helper()
	if os.Getenv("DATABASE_URL") == "" {
		t.Logf("ℹ DATABASE_URL not set — skipping billing assertions")
		return nil, false
	}
	defer func() { _ = recover() }() // loadBillingEnv require's; we swallow
	env := loadBillingEnv(t)
	return env, env != nil
}

func loadBillingEnv(t *testing.T) *billingTestEnv {
	t.Helper()

	env := &billingTestEnv{}

	env.billingURL = os.Getenv("BILLING_SVC_URL")
	if env.billingURL == "" {
		env.billingURL = describeServiceURL(t, "billing-svc",
			envOr("GCP_REGION", "europe-central2"),
			envOr("GCP_PROJECT_ID", "superwizor-ai-25ecd"))
	}
	env.billingHost = hostPort(env.billingURL)
	env.billingHTTPURL = env.billingURL

	dbDSN := os.Getenv("DATABASE_URL")
	require.NotEmpty(t, dbDSN, "DATABASE_URL required (use cloud-sql-proxy)")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, dbDSN)
	require.NoError(t, err, "db connect")
	env.dbPool = pool
	t.Cleanup(func() { pool.Close() })

	// Resolve organization + therapist. Allow override via env, else
	// discover the staging seed (MANUAL PRO from migration 000030).
	if orgRaw := os.Getenv("BILLING_ORG_ID"); orgRaw != "" {
		env.orgID = uuid.MustParse(orgRaw)
	} else {
		err := pool.QueryRow(ctx, `
			SELECT s.organization_id
			FROM subscriptions s
			WHERE s.provider = 'MANUAL'
			  AND s.status = 'ACTIVE'
			ORDER BY s.created_at DESC
			LIMIT 1`).Scan(&env.orgID)
		require.NoError(t, err, "discover staging org (run migration 000030 first)")
	}
	if therapistRaw := os.Getenv("BILLING_THERAPIST_ID"); therapistRaw != "" {
		env.therapistID = uuid.MustParse(therapistRaw)
	} else {
		err := pool.QueryRow(ctx, `
			SELECT id FROM users
			WHERE organization_id = $1 AND role = 'THERAPIST' AND deleted_at IS NULL
			LIMIT 1`, env.orgID).Scan(&env.therapistID)
		if err != nil {
			// Brak therapista w org — OK, billing nie wymaga rzeczywistego therapista
			// (ta wartość jest tylko metadata). Generujemy fake UUID.
			env.therapistID = uuid.New()
			t.Logf("⚠ no therapist in org %s, using random UUID %s", env.orgID, env.therapistID)
		}
	}

	env.idToken = mintBillingOIDCToken(t, env.billingURL)

	t.Logf("══════════════════════════════════════════════════════════════")
	t.Logf("  billing-svc E2E setup")
	t.Logf("  URL:          %s", env.billingURL)
	t.Logf("  Organization: %s", env.orgID)
	t.Logf("  Therapist:    %s", env.therapistID)
	t.Logf("══════════════════════════════════════════════════════════════")

	return env
}

// mintBillingOIDCToken — `gcloud auth print-identity-token --impersonate-service-account=<SA> --audiences=<URL>`.
// Cloud Run waliduje audience claim, więc musi być EXACT URL z https://.
//
// SA musi mieć:
//   - run.invoker na billing-svc (do faktycznego wywołania)
//   - user musi mieć iam.serviceAccountTokenCreator na tym SA
//
// Default: billing-svc@<project>.iam — własna SA usługi, do której granty IAM
// można dodać bez naruszania innych ścieżek.
// Override przez env: BILLING_IMPERSONATE_SA.
func mintBillingOIDCToken(t *testing.T, audienceURL string) string {
	t.Helper()
	impersonateSA := os.Getenv("BILLING_IMPERSONATE_SA")
	if impersonateSA == "" {
		project := envOr("GCP_PROJECT_ID", "superwizor-ai-25ecd")
		impersonateSA = "billing-svc@" + project + ".iam.gserviceaccount.com"
	}
	args := []string{
		"auth", "print-identity-token",
		"--impersonate-service-account=" + impersonateSA,
		"--audiences=" + audienceURL,
	}
	out, err := exec.Command("gcloud", args...).Output()
	require.NoErrorf(t, err, "gcloud print-identity-token (impersonate=%s)", impersonateSA)
	return strings.TrimSpace(string(out))
}

func (e *billingTestEnv) dialBilling(t *testing.T) (*grpc.ClientConn, billingv1.BillingServiceClient) {
	t.Helper()
	var creds credentials.TransportCredentials
	if strings.HasPrefix(e.billingURL, "http://") {
		creds = insecure.NewCredentials()
	} else {
		creds = credentials.NewTLS(&tls.Config{MinVersion: tls.VersionTLS12})
	}
	conn, err := grpc.NewClient(e.billingHost,
		grpc.WithTransportCredentials(creds),
		grpc.WithUnaryInterceptor(authInterceptor(e.idToken)),
	)
	require.NoError(t, err)
	return conn, billingv1.NewBillingServiceClient(conn)
}

// cleanupSession deletes all billing artifacts for a session_id. Idempotent.
func (e *billingTestEnv) cleanupSession(t *testing.T, sessionID uuid.UUID) {
	ctx := context.Background()
	_, _ = e.dbPool.Exec(ctx, `DELETE FROM usage_events WHERE session_id = $1`, sessionID)
	_, _ = e.dbPool.Exec(ctx, `DELETE FROM pending_reservations WHERE session_id = $1`, sessionID)
}

// resetCounter zeruje tokens_used/reserved dla aktywnego countera.
// Używany do izolacji testów które badają konkretne wartości remaining.
func (e *billingTestEnv) resetCounter(t *testing.T) {
	ctx := context.Background()
	_, err := e.dbPool.Exec(ctx, `
		UPDATE usage_counters
		SET tokens_used = 0, tokens_reserved = 0
		WHERE subscription_id IN (
			SELECT id FROM subscriptions
			WHERE organization_id = $1 AND status IN ('ACTIVE', 'TRIALING')
		)
		AND period_start <= now() AND period_end > now()`,
		e.orgID)
	require.NoError(t, err, "reset counter")
}

// setCounterUsage — ustawia konkretny stan tokens_used (do edge case'ów).
func (e *billingTestEnv) setCounterUsage(t *testing.T, used, reserved int32) {
	ctx := context.Background()
	_, err := e.dbPool.Exec(ctx, `
		UPDATE usage_counters
		SET tokens_used = $1, tokens_reserved = $2
		WHERE subscription_id IN (
			SELECT id FROM subscriptions
			WHERE organization_id = $3 AND status IN ('ACTIVE', 'TRIALING')
		)
		AND period_start <= now() AND period_end > now()`,
		used, reserved, e.orgID)
	require.NoError(t, err, "set counter")
}

// ============================================================================
// CheckQuota — gate logic
// ============================================================================

func TestBilling_CheckQuota_HappyPath(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	resp, err := c.CheckQuota(ctx, &billingv1.CheckQuotaRequest{
		OrganizationId: env.orgID.String(),
		TherapistId:    env.therapistID.String(),
		UsageType:      "session_analysis",
		Amount:         1,
	})
	require.NoError(t, err)
	assert.True(t, resp.Allowed)
	assert.Equal(t, "OK", resp.Reason)
	assert.Greater(t, resp.Remaining, int32(0))
	assert.Equal(t, resp.Remaining, resp.RemainingTokens, "legacy/new field parity")
	assert.Equal(t, resp.Limit, resp.LimitTokens, "legacy/new field parity")
}

func TestBilling_CheckQuota_Exhausted(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)
	// Ustaw counter na exact limit — symuluje wyczerpanie.
	env.setCounterUsage(t, 40, 0) // PRO MONTHLY = 40 tokens
	defer env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	resp, err := c.CheckQuota(ctx, &billingv1.CheckQuotaRequest{
		OrganizationId: env.orgID.String(),
		TherapistId:    env.therapistID.String(),
		UsageType:      "session_analysis",
		Amount:         1,
	})
	require.NoError(t, err)
	assert.False(t, resp.Allowed)
	assert.Equal(t, "QUOTA_EXHAUSTED", resp.Reason)
	assert.Equal(t, int32(0), resp.Remaining)
}

func TestBilling_CheckQuota_InvalidOrgID(t *testing.T) {
	env := loadBillingEnv(t)
	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := c.CheckQuota(ctx, &billingv1.CheckQuotaRequest{
		OrganizationId: "not-a-uuid",
		TherapistId:    env.therapistID.String(),
	})
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ============================================================================
// ReserveCredit + CommitUsage — full happy path lifecycle
// ============================================================================

func TestBilling_ReserveCommit_HappyPath(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	// 1. Reserve
	res, err := c.ReserveCredit(ctx, &billingv1.ReserveCreditRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		TherapistId:     env.therapistID.String(),
		EstimatedTokens: 1,
		IdempotencyKey:  "test-reserve-" + sessionID.String(),
	})
	require.NoError(t, err)
	assert.Equal(t, sessionID.String(), res.SessionId)
	assert.Equal(t, int32(1), res.TokensReserved)
	assert.NotEmpty(t, res.ReservationId)
	require.True(t, res.ExpiresAt.AsTime().After(time.Now().Add(3*time.Hour)),
		"expiry must be ~4h from now")

	// 2. Verify counter: 1 reserved, 0 used.
	{
		check, err := c.CheckQuota(ctx, &billingv1.CheckQuotaRequest{
			OrganizationId: env.orgID.String(), Amount: 1,
		})
		require.NoError(t, err)
		assert.Equal(t, check.Limit-1, check.Remaining, "1 token reserved")
	}

	// 3. Commit z duration 45min → 1 token
	commit, err := c.CommitUsage(ctx, &billingv1.CommitUsageRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		DurationSeconds: 2700,
	})
	require.NoError(t, err)
	assert.Equal(t, int32(1), commit.TokensConsumed)
	assert.Equal(t, commit.LimitTokens-1, commit.RemainingTokens, "1 used, 0 reserved")
}

// TestBilling_TokenCalculation_Boundaries — verify formuły BR-2 end-to-end.
//
// Formuła: max(1, ceil((duration - 0) / 4500))  — 1 token = ≤75min, no grace.
// Boundary cases:
//   45min  = 2700s → 1 token
//   74min  = 4440s → 1 token
//   75min  = 4500s → 1 token (exact boundary)
//   75:01  = 4501s → 2 tokens (hard boundary, no grace)
//   150min = 9000s → 2 tokens (exact boundary)
//   151min = 9060s → 3 tokens
func TestBilling_TokenCalculation_Boundaries(t *testing.T) {
	env := loadBillingEnv(t)

	cases := []struct {
		name        string
		duration    int32
		wantTokens  int32
	}{
		{"45min one token", 2700, 1},
		{"74min one token", 4440, 1},
		{"75min boundary one token", 4500, 1},
		{"75:01 crosses to two", 4501, 2},
		{"150min two tokens", 9000, 2},
		{"151min crosses to three", 9060, 3},
	}

	conn, c := env.dialBilling(t)
	defer conn.Close()

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			env.resetCounter(t)
			sessionID := uuid.New()
			t.Cleanup(func() { env.cleanupSession(t, sessionID) })

			ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
			defer cancel()

			// Bezpośredni commit (bez reservation) — sprawdza obliczenia tokenów.
			commit, err := c.CommitUsage(ctx, &billingv1.CommitUsageRequest{
				SessionId:       sessionID.String(),
				OrganizationId:  env.orgID.String(),
				DurationSeconds: tc.duration,
			})
			require.NoError(t, err)
			assert.Equal(t, tc.wantTokens, commit.TokensConsumed,
				"duration %ds should consume %d tokens", tc.duration, tc.wantTokens)
		})
	}
}

// TestBilling_CommitUsage_Idempotency — drugi commit z tym samym session_id
// musi być NO-OP, zwracać ten sam tokens_consumed bez double-charge.
func TestBilling_CommitUsage_Idempotency(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	req := &billingv1.CommitUsageRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		DurationSeconds: 2700,
	}

	first, err := c.CommitUsage(ctx, req)
	require.NoError(t, err)
	assert.Equal(t, int32(1), first.TokensConsumed)

	second, err := c.CommitUsage(ctx, req)
	require.NoError(t, err, "idempotent retry must not error")
	assert.Equal(t, int32(1), second.TokensConsumed, "no double-charge")
	assert.Equal(t, first.RemainingTokens, second.RemainingTokens, "counter unchanged")
}

// TestBilling_ReserveCredit_Idempotent — drugi ReserveCredit zwraca tą samą
// rezerwację, NIE tworzy drugiej.
func TestBilling_ReserveCredit_Idempotent(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	req := &billingv1.ReserveCreditRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		TherapistId:     env.therapistID.String(),
		EstimatedTokens: 1,
		IdempotencyKey:  "idem-" + sessionID.String(),
	}

	first, err := c.ReserveCredit(ctx, req)
	require.NoError(t, err)

	second, err := c.ReserveCredit(ctx, req)
	require.NoError(t, err)
	assert.Equal(t, first.ReservationId, second.ReservationId, "same reservation_id")
}

// TestBilling_ReleaseCredit_RoundTrip — Reserve → Release zwraca token do puli.
func TestBilling_ReleaseCredit_RoundTrip(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	// Reserve
	_, err := c.ReserveCredit(ctx, &billingv1.ReserveCreditRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		TherapistId:     env.therapistID.String(),
		EstimatedTokens: 1,
	})
	require.NoError(t, err)

	beforeRelease, err := c.CheckQuota(ctx, &billingv1.CheckQuotaRequest{
		OrganizationId: env.orgID.String(),
	})
	require.NoError(t, err)
	reservedRemaining := beforeRelease.Remaining

	// Release
	_, err = c.ReleaseCredit(ctx, &billingv1.ReleaseCreditRequest{
		SessionId:      sessionID.String(),
		OrganizationId: env.orgID.String(),
		Reason:         "UPLOAD_FAILED",
	})
	require.NoError(t, err)

	afterRelease, err := c.CheckQuota(ctx, &billingv1.CheckQuotaRequest{
		OrganizationId: env.orgID.String(),
	})
	require.NoError(t, err)
	assert.Equal(t, reservedRemaining+1, afterRelease.Remaining,
		"release must return 1 token to remaining pool")
}

// TestBilling_ReleaseCredit_Idempotent — release na non-ACTIVE rezerwacji
// zwraca OK bez efektu.
func TestBilling_ReleaseCredit_Idempotent(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	_, err := c.ReserveCredit(ctx, &billingv1.ReserveCreditRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		TherapistId:     env.therapistID.String(),
		EstimatedTokens: 1,
	})
	require.NoError(t, err)

	// Pierwszy release
	_, err = c.ReleaseCredit(ctx, &billingv1.ReleaseCreditRequest{
		SessionId:      sessionID.String(),
		OrganizationId: env.orgID.String(),
	})
	require.NoError(t, err)

	// Drugi release — no-op, ale nie błąd.
	_, err = c.ReleaseCredit(ctx, &billingv1.ReleaseCreditRequest{
		SessionId:      sessionID.String(),
		OrganizationId: env.orgID.String(),
	})
	require.NoError(t, err, "release on already-released must be idempotent")
}

// ============================================================================
// GetSubscription
// ============================================================================

func TestBilling_GetSubscription(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	sub, err := c.GetSubscription(ctx, &billingv1.GetSubscriptionRequest{
		OrganizationId: env.orgID.String(),
	})
	require.NoError(t, err)
	assert.Contains(t, []string{"SOLO", "PRO", "CLINIC"}, sub.PlanTier)
	assert.Equal(t, "ACTIVE", sub.Status)
	assert.Greater(t, sub.TokensPerPeriod, int32(0))
	// Legacy fields populated identically.
	assert.Equal(t, sub.TokensPerPeriod, sub.SessionsPerMonthLimit)
	assert.Equal(t, sub.TokensUsedThisPeriod, sub.SessionsUsedThisPeriod)
}

// NOTE: the "Outbox edge cases" group (TestBilling_Outbox_QuotaWarning,
// _QuotaExhausted, _NoEventWhenNoEdge) was removed (2026-05-31). It asserted
// against the outbox_events table, which migration 000034_drop_outbox_events
// deliberately dropped when the billing.outbox fan-out was replaced by
// direct-RPC quota propagation (clinical-svc.GetMyBillingState + state_after
// on Reservation/UsageCommit). The two warning/exhausted tests failed
// unconditionally (relation does not exist); NoEventWhenNoEdge only "passed"
// because its helper swallowed that error and returned found=false.

// ============================================================================
// Race conditions
// ============================================================================

// TestBilling_ConcurrentReserve_LastToken — dwa równoległe Reserve na ostatnim
// tokenie. Tylko jeden powinien wygrać; drugi dostać QUOTA_EXHAUSTED.
func TestBilling_ConcurrentReserve_LastToken(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)

	// Fetch actual limit dynamically to leave exactly 1 token
	var limit int32
	ctx := context.Background()
	err := env.dbPool.QueryRow(ctx, `
		SELECT tokens_limit FROM usage_counters
		WHERE subscription_id IN (
			SELECT id FROM subscriptions
			WHERE organization_id = $1 AND status IN ('ACTIVE', 'TRIALING')
		)
		AND period_start <= now() AND period_end > now()`, env.orgID).Scan(&limit)
	require.NoError(t, err)

	env.setCounterUsage(t, limit-1, 0) // 1 token left
	defer env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	sessionA := uuid.New()
	sessionB := uuid.New()
	t.Cleanup(func() {
		env.cleanupSession(t, sessionA)
		env.cleanupSession(t, sessionB)
	})

	type result struct {
		sessionID uuid.UUID
		err       error
		code      codes.Code
	}
	results := make(chan result, 2)

	doReserve := func(sid uuid.UUID) {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		_, err := c.ReserveCredit(ctx, &billingv1.ReserveCreditRequest{
			SessionId:       sid.String(),
			OrganizationId:  env.orgID.String(),
			TherapistId:     env.therapistID.String(),
			EstimatedTokens: 1,
		})
		results <- result{sessionID: sid, err: err, code: status.Code(err)}
	}

	go doReserve(sessionA)
	go doReserve(sessionB)

	r1 := <-results
	r2 := <-results

	successes := 0
	exhausted := 0
	for _, r := range []result{r1, r2} {
		switch {
		case r.err == nil:
			successes++
		case r.code == codes.ResourceExhausted:
			exhausted++
		default:
			t.Errorf("unexpected error for session %s: %v", r.sessionID, r.err)
		}
	}
	assert.Equal(t, 1, successes, "exactly one reservation should win")
	assert.Equal(t, 1, exhausted, "exactly one should get ResourceExhausted")
}

// ============================================================================
// Admin HTTP endpoints (cron)
// ============================================================================

// TestBilling_ReservationExpiry_Cron — manual call /admin/reservation-expiry
// po sztucznie zestarzonej rezerwacji powinien zwolnić tokeny.
func TestBilling_ReservationExpiry_Cron(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)
	defer env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	// Stwórz rezerwację via gRPC
	_, err := c.ReserveCredit(ctx, &billingv1.ReserveCreditRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		TherapistId:     env.therapistID.String(),
		EstimatedTokens: 1,
	})
	require.NoError(t, err)

	// Postarz ją SQL-owo — expires_at = now() - 1h.
	_, err = env.dbPool.Exec(ctx, `
		UPDATE pending_reservations
		SET expires_at = now() - interval '1 hour'
		WHERE session_id = $1`, sessionID)
	require.NoError(t, err)

	// Wywołaj cron endpoint
	postAdmin(t, env, "/admin/reservation-expiry")

	// Po cronie status powinien być EXPIRED.
	var resStatus string
	err = env.dbPool.QueryRow(ctx, `
		SELECT status FROM pending_reservations WHERE session_id = $1`,
		sessionID).Scan(&resStatus)
	require.NoError(t, err)
	assert.Equal(t, "EXPIRED", resStatus)

	// I tokens_reserved counter powinien być 0.
	chk, err := c.CheckQuota(ctx, &billingv1.CheckQuotaRequest{OrganizationId: env.orgID.String()})
	require.NoError(t, err)
	assert.Equal(t, chk.Limit, chk.Remaining, "reservation tokens released")
}

func TestBilling_SafetyCheck_Cron(t *testing.T) {
	env := loadBillingEnv(t)
	conn, _ := env.dialBilling(t)
	defer conn.Close()

	// Safety check tylko powinien się powodzieć — nawet jeśli wszystkie subs
	// mają countery, endpoint zwraca 200 OK z healed_count=0.
	body := postAdmin(t, env, "/admin/safety-check")
	var resp map[string]any
	require.NoError(t, json.Unmarshal(body, &resp))
	assert.Equal(t, "ok", resp["message"])
}

// postAdmin — POST do admin HTTP endpointu z OIDC tokenem.
// billing-svc używa h2c mixed handler: gRPC i HTTP są na tym samym porcie
// (:443 w Cloud Run); routing po Content-Type w main.go.
func postAdmin(t *testing.T, env *billingTestEnv, path string) []byte {
	t.Helper()
	req, err := http.NewRequest("POST", env.billingHTTPURL+path, nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+env.idToken)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err, "POST %s", path)
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	require.Equal(t, http.StatusOK, resp.StatusCode,
		"POST %s → %d: %s", path, resp.StatusCode, string(body))
	return body
}

// ============================================================================
// Wiring tests — catch missing IAM bindings / unwired RPC callers
// ============================================================================

// TestBilling_ReserveOnUpload — REGRESSION TEST for the Dario bug (2026-05-26).
//
// Bug: ingestion-svc@ SA had no run.invoker on billing-svc → every
// ReserveCredit returned 403 PermissionDenied → tokens_used/tokens_reserved
// stayed 0 forever. App restart showed "0/20 sessions used" even after
// multiple recorded sessions.
//
// What this test exercises end-to-end:
//   1. Real Firebase user → CreateUser via identity-svc
//   2. Create patient_file via clinical-svc
//   3. CreateAudioUpload via ingestion-svc (which spawns the background
//      reserveCreditAsync goroutine)
//   4. Poll PG within 15s for pending_reservations row
//
// If the IAM binding / wiring is missing, no row appears within the
// timeout → test fails with a clear "ReserveCredit was never called for
// session X" message that points at the integration gap, not at
// billing-svc internals.
//
// Skip: requires the FullSession test infrastructure (Firebase, gcloud,
// audio fixture). Standalone — does NOT need a counter to be pre-seeded.
func TestBilling_ReserveOnUpload(t *testing.T) {
	cfg := loadConfig(t)
	env := loadBillingEnv(t) // for DB pool

	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("billing_reserve_uid_%d", runID)
	firebaseEmail := fmt.Sprintf("billing_reserve_%d@example.com", runID)

	t.Logf("══════════════════════════════════════════════════════════════")
	t.Logf("  E2E billing-reserve wiring test")
	t.Logf("  Run ID:  %d", runID)
	t.Logf("══════════════════════════════════════════════════════════════")

	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer tokenCancel()
	fbSession, err := mintFirebaseSession(tokenCtx, cfg.projectID, cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
	require.NoError(t, err, "mint Firebase token")
	t.Cleanup(func() { _ = fbSession.cleanup() })

	identityConn := dial(t, cfg.identityURL, fbSession.IDToken)
	t.Cleanup(func() { _ = identityConn.Close() })
	clinicalConn := dial(t, cfg.clinicalURL, fbSession.IDToken)
	t.Cleanup(func() { _ = clinicalConn.Close() })
	ingestionConn := dial(t, cfg.ingestionURL, fbSession.IDToken)
	t.Cleanup(func() { _ = ingestionConn.Close() })

	identityClient := identityv1.NewIdentityServiceClient(identityConn)
	clinicalClient := clinicalv1.NewClinicalServiceClient(clinicalConn)
	ingestionClient := ingestionv1.NewIngestionServiceClient(ingestionConn)

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid: firebaseUID, Email: firebaseEmail,
		Role: identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName: "BillingE2E", LastName: "Therapist",
		UiLanguage: "pl", Timezone: "Europe/Warsaw", HasAcceptedTos: true,
	})
	require.NoError(t, err, "CreateUser")
	t.Logf("✓ Therapist created: %s", therapist.Id)

	// Pre-condition: therapist needs an organization with active subscription
	// + usage_counter. This is what the bootstrap migration 000030 + the
	// org-bootstrap seed does for all therapists. If your env is fresh
	// (no orgs auto-created on CreateUser), this test will skip.
	therapistUUID, _ := uuid.Parse(therapist.Id)
	var orgIDStr string
	err = env.dbPool.QueryRow(ctx,
		`SELECT COALESCE(organization_id::text, '') FROM users WHERE id = $1`, therapistUUID,
	).Scan(&orgIDStr)
	require.NoError(t, err, "load therapist org")
	if orgIDStr == "" {
		t.Skip("therapist has no organization — run org bootstrap seed first " +
			"(see /tmp/dbq/seed_orgs.go pattern). Test requires usage_counters.")
	}

	patient, err := clinicalClient.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId: therapist.Id, ModalityCode: "CBT",
		WorkingAlias: fmt.Sprintf("BillingE2E Patient %d", runID),
		ProcessType: clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		HasRecordingConsent: true,
		IdempotencyKey: fmt.Sprintf("billing-reserve-patient-%d", runID),
		PatientFirstName: "BillingE2E", PatientLastName: "Patient", PatientLanguageCode: "pl",
	})
	require.NoError(t, err, "CreatePatientFile")
	t.Logf("✓ PatientFile created: %s", patient.Id)
	t.Cleanup(func() {
		bgCtx, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgCancel()
		_, _ = clinicalClient.DeletePatientFile(bgCtx, &clinicalv1.DeletePatientFileRequest{PatientFileId: patient.Id})
	})

	upload, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId: therapist.Id, PatientFileId: patient.Id,
		ContentType: "audio/flac", EstimatedSizeBytes: 100_000, EstimatedDurationSeconds: 60,
		IdempotencyKey: fmt.Sprintf("billing-reserve-upload-%d", runID),
		ClientAppVersion: "e2e-billing-1.0", ClientPlatform: "test",
	})
	require.NoError(t, err, "CreateAudioUpload")
	require.NotEmpty(t, upload.SessionId, "session_id must be in response (Option E)")
	sessionUUID := uuid.MustParse(upload.SessionId)
	t.Logf("✓ CreateAudioUpload returned session_id=%s", sessionUUID)

	t.Cleanup(func() {
		// Reset DB rows we created. Best-effort.
		bgCtx, bgCancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer bgCancel()
		_, _ = env.dbPool.Exec(bgCtx, `DELETE FROM pending_reservations WHERE session_id = $1`, sessionUUID)
		_, _ = env.dbPool.Exec(bgCtx, `DELETE FROM usage_events WHERE session_id = $1`, sessionUUID)
	})

	// Poll for pending_reservations row — ReserveCredit is fire-and-forget
	// (goroutine kicked off after tx.Commit), so allow time for the gRPC
	// round-trip + DB insert.
	pollCtx, pollCancel := context.WithTimeout(ctx, 20*time.Second)
	defer pollCancel()
	deadline := time.Now().Add(20 * time.Second)
	var found bool
	var resStatus string
	var tokensReserved int32
	for time.Now().Before(deadline) {
		err := env.dbPool.QueryRow(pollCtx,
			`SELECT status::text, tokens_reserved FROM pending_reservations WHERE session_id = $1`,
			sessionUUID,
		).Scan(&resStatus, &tokensReserved)
		if err == nil {
			found = true
			break
		}
		time.Sleep(1 * time.Second)
	}
	require.True(t, found,
		"pending_reservations row never appeared for session %s within 20s — "+
			"ingestion-svc.reserveCreditAsync did not complete. Check:\n"+
			"  (1) ingestion-svc SA has run.invoker on billing-svc Cloud Run\n"+
			"  (2) BILLING_SVC_URL env is set on ingestion-svc\n"+
			"  (3) Cloud Logging for ingestion-svc: 'billing reserve' messages",
		sessionUUID)
	assert.Equal(t, "ACTIVE", resStatus, "reservation should be ACTIVE")
	assert.Equal(t, int32(1), tokensReserved, "default 1 token per session")
	t.Logf("✓ pending_reservations row appeared: status=%s tokens=%d",
		resStatus, tokensReserved)
}

// AssertBillingCommittedAfterSession — helper for full-session E2E tests.
// Polls for usage_events row + counter increment after STT finalize. Use
// from TestFullSession_HappyPath after waiting for COMPLETED status.
//
// If this fails, the bug is most likely:
//   - stt-worker SA missing run.invoker on billing-svc
//   - BILLING_SVC_URL env not set on stt-worker function
//   - stt-worker code path not hitting commitBillingUsageAsync (e.g.,
//     never reached "ANALYZING" status due to prior pipeline failure).
func AssertBillingCommittedAfterSession(t *testing.T, env *billingTestEnv, sessionID uuid.UUID, expectMinTokens int32) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	deadline := time.Now().Add(30 * time.Second)
	var found bool
	var tokensConsumed, durationSeconds int32
	for time.Now().Before(deadline) {
		err := env.dbPool.QueryRow(ctx,
			`SELECT tokens_consumed, duration_seconds FROM usage_events WHERE session_id = $1`,
			sessionID,
		).Scan(&tokensConsumed, &durationSeconds)
		if err == nil {
			found = true
			break
		}
		time.Sleep(2 * time.Second)
	}
	require.True(t, found,
		"usage_events row never appeared for session %s within 30s after COMPLETED — "+
			"stt-worker.commitBillingUsageAsync did not complete. Check:\n"+
			"  (1) stt-worker SA has run.invoker on billing-svc\n"+
			"  (2) BILLING_SVC_URL env on stt-worker Cloud Function\n"+
			"  (3) Cloud Logging for stt-worker: 'billing commit' messages",
		sessionID)
	assert.GreaterOrEqual(t, tokensConsumed, expectMinTokens,
		"expected ≥%d tokens consumed", expectMinTokens)
	assert.Greater(t, durationSeconds, int32(0), "duration_seconds must be > 0")
	t.Logf("✓ usage_events row: tokens=%d duration=%ds", tokensConsumed, durationSeconds)
}

// ============================================================================
// metadata helpers (re-use existing patterns)
// ============================================================================

// Provide deduped helpers — these mirror full_session_test.go but live here
// for compilation (e2e build tag = each test file has independent helpers).
//
// We rely on full_session_test.go's hostPort, authInterceptor, envOr,
// describeServiceURL — these are in the same package so they're shared.

// metadata import marker (suppress unused).
var _ = metadata.New

// ---------- Stripe Webhook Mock Structs & E2E Test ----------

type mockStripePrice struct {
	ID string `json:"id"`
}

type mockStripeSubscriptionItem struct {
	Price mockStripePrice `json:"price"`
}

type mockStripeSubscriptionItems struct {
	Data []mockStripeSubscriptionItem `json:"data"`
}

type mockStripeSubscriptionMetadata struct {
	OrganizationID string `json:"organization_id"`
}

type mockStripeSubscription struct {
	ID                 string                         `json:"id"`
	Customer           string                         `json:"customer"`
	Status             string                         `json:"status"`
	CurrentPeriodStart int64                          `json:"current_period_start"`
	CurrentPeriodEnd   int64                          `json:"current_period_end"`
	CancelAtPeriodEnd  bool                           `json:"cancel_at_period_end"`
	CanceledAt         int64                          `json:"canceled_at"`
	TrialEnd           int64                          `json:"trial_end"`
	Items              mockStripeSubscriptionItems    `json:"items"`
	Metadata           mockStripeSubscriptionMetadata `json:"metadata"`
}

type mockStripeEventData struct {
	Object json.RawMessage `json:"object"`
}

type mockStripeEvent struct {
	ID   string              `json:"id"`
	Type string              `json:"type"`
	Data mockStripeEventData `json:"data"`
}

type mockStripeInvoiceLine struct {
	Period struct {
		Start int64 `json:"start"`
		End   int64 `json:"end"`
	} `json:"period"`
	Price mockStripePrice `json:"price"`
}

type mockStripeInvoiceLines struct {
	Data []mockStripeInvoiceLine `json:"data"`
}

type mockStripeInvoice struct {
	ID           string                 `json:"id"`
	Customer     string                 `json:"customer"`
	Subscription string                 `json:"subscription"`
	AmountPaid   int64                  `json:"amount_paid"`
	AmountDue    int64                  `json:"amount_due"`
	Currency     string                 `json:"currency"`
	PeriodStart  int64                  `json:"period_start"`
	PeriodEnd    int64                  `json:"period_end"`
	Lines        mockStripeInvoiceLines `json:"lines"`
}

func fetchStripeWebhookSecret(t *testing.T) string {
	t.Helper()
	if secret := os.Getenv("STRIPE_WEBHOOK_SECRET"); secret != "" {
		return secret
	}
	project := envOr("GCP_PROJECT_ID", "superwizor-ai-25ecd")
	args := []string{
		"secrets", "versions", "access", "latest",
		"--secret=stripe-webhook-secret",
		"--project=" + project,
	}
	out, err := exec.Command("gcloud", args...).Output()
	if err != nil {
		t.Logf("⚠️ Failed to fetch Stripe webhook secret from Secret Manager: %v", err)
		return ""
	}
	return strings.TrimSpace(string(out))
}

func signStripePayload(t *testing.T, body []byte, secret string) (string, int64) {
	t.Helper()
	timestamp := time.Now().Unix()
	payload := fmt.Sprintf("%d.%s", timestamp, string(body))
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	sig := hex.EncodeToString(mac.Sum(nil))
	return fmt.Sprintf("t=%d,v1=%s", timestamp, sig), timestamp
}

func postWebhook(t *testing.T, env *billingTestEnv, eventType string, eventID string, obj any, secret string) {
	t.Helper()
	objBytes, err := json.Marshal(obj)
	require.NoError(t, err)

	evt := mockStripeEvent{
		ID:   eventID,
		Type: eventType,
		Data: mockStripeEventData{
			Object: objBytes,
		},
	}
	payload, err := json.Marshal(evt)
	require.NoError(t, err)

	sigHeader, _ := signStripePayload(t, payload, secret)

	req, err := http.NewRequest("POST", env.billingHTTPURL+"/stripe/webhook", bytes.NewReader(payload))
	require.NoError(t, err)

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Stripe-Signature", sigHeader)

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	require.Equal(t, http.StatusOK, resp.StatusCode, "POST webhook %s → %d: %s", eventType, resp.StatusCode, string(respBody))
}

func TestBilling_StripeWebhook(t *testing.T) {
	env := loadBillingEnv(t)
	ctx := context.Background()

	// 1. Fetch stripe webhook secret from Secret Manager
	secret := fetchStripeWebhookSecret(t)
	if secret == "" {
		t.Skip("Skipping Stripe Webhook E2E test: stripe-webhook-secret not set/accessible")
	}

	// 2. Create a test organization
	testOrgID := uuid.New()
	_, err := env.dbPool.Exec(ctx, `
		INSERT INTO organizations (id, legal_name, type)
		VALUES ($1, 'Stripe Webhook Test Org', 'SOLO')`, testOrgID)
	require.NoError(t, err)

	// Register cleanup for the test organization and all linked items
	var paymentEventIDs []uuid.UUID
	t.Cleanup(func() {
		bg := context.Background()
		for _, peID := range paymentEventIDs {
			_, _ = env.dbPool.Exec(bg, `DELETE FROM payment_events WHERE id = $1`, peID)
		}
		// Delete usage counters first
		_, _ = env.dbPool.Exec(bg, `
			DELETE FROM usage_counters 
			WHERE subscription_id IN (SELECT id FROM subscriptions WHERE organization_id = $1)`, 
			testOrgID)
		// Delete subscriptions
		_, _ = env.dbPool.Exec(bg, `DELETE FROM subscriptions WHERE organization_id = $1`, testOrgID)
		// Delete organization
		_, _ = env.dbPool.Exec(bg, `DELETE FROM organizations WHERE id = $1`, testOrgID)
	})

	// 3. Query active stripe price ID
	var stripePriceID string
	var planID uuid.UUID
	var planTokens int32
	err = env.dbPool.QueryRow(ctx, `
		SELECT id, stripe_price_id, tokens_per_period 
		FROM subscription_plans 
		WHERE stripe_price_id IS NOT NULL AND is_active = true 
		LIMIT 1`).Scan(&planID, &stripePriceID, &planTokens)
	require.NoError(t, err, "must have at least one active subscription plan with stripe_price_id")

	stripeSubID := "sub_test_" + uuid.New().String()[:8]
	stripeCustomerID := "cus_test_" + uuid.New().String()[:8]

	// 4. Test customer.subscription.created (ACTIVE)
	t.Log("Testing customer.subscription.created ...")
	createdEventID := "evt_created_" + uuid.New().String()[:8]
	nowTS := time.Now().Unix()
	endTS := time.Now().Add(30 * 24 * time.Hour).Unix()

	subObj := mockStripeSubscription{
		ID:                 stripeSubID,
		Customer:           stripeCustomerID,
		Status:             "active",
		CurrentPeriodStart: nowTS,
		CurrentPeriodEnd:   endTS,
		CancelAtPeriodEnd:  false,
		CanceledAt:         0,
		TrialEnd:           0,
		Metadata: mockStripeSubscriptionMetadata{
			OrganizationID: testOrgID.String(),
		},
	}
	subObj.Items.Data = []mockStripeSubscriptionItem{
		{Price: mockStripePrice{ID: stripePriceID}},
	}

	postWebhook(t, env, "customer.subscription.created", createdEventID, subObj, secret)

	// Verify subscription created in DB
	var dbSubStatus string
	var dbSubID uuid.UUID
	err = env.dbPool.QueryRow(ctx, `
		SELECT id, status::text FROM subscriptions 
		WHERE organization_id = $1 AND provider_subscription_id = $2`, 
		testOrgID, stripeSubID).Scan(&dbSubID, &dbSubStatus)
	require.NoError(t, err)
	assert.Equal(t, "ACTIVE", dbSubStatus)

	// Capture payment_event ID for cleanup
	var peID uuid.UUID
	err = env.dbPool.QueryRow(ctx, `
		SELECT id FROM payment_events WHERE provider_event_id = $1`, 
		createdEventID).Scan(&peID)
	require.NoError(t, err)
	paymentEventIDs = append(paymentEventIDs, peID)

	// Verify usage_counter was created
	var count int
	err = env.dbPool.QueryRow(ctx, `
		SELECT COUNT(*) FROM usage_counters WHERE subscription_id = $1`, 
		dbSubID).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 1, count, "usage_counter should be created on ACTIVE subscription")

	// 5. Test idempotency (duplicate event should return StatusOK with duplicate message)
	t.Log("Testing webhook idempotency (duplicate event) ...")
	// Send the exact same event ID again
	postWebhook(t, env, "customer.subscription.created", createdEventID, subObj, secret)
	// Verify count of payment_events is still 1
	var peCount int
	err = env.dbPool.QueryRow(ctx, `
		SELECT COUNT(*) FROM payment_events WHERE provider_event_id = $1`, 
		createdEventID).Scan(&peCount)
	require.NoError(t, err)
	assert.Equal(t, 1, peCount)

	// 6. Test customer.subscription.updated (status -> past_due)
	t.Log("Testing customer.subscription.updated ...")
	updatedEventID := "evt_updated_" + uuid.New().String()[:8]
	subObj.Status = "past_due"
	postWebhook(t, env, "customer.subscription.updated", updatedEventID, subObj, secret)

	// Capture payment_event ID
	err = env.dbPool.QueryRow(ctx, `
		SELECT id FROM payment_events WHERE provider_event_id = $1`, 
		updatedEventID).Scan(&peID)
	require.NoError(t, err)
	paymentEventIDs = append(paymentEventIDs, peID)

	// Verify status updated in DB
	err = env.dbPool.QueryRow(ctx, `
		SELECT status::text FROM subscriptions WHERE id = $1`, 
		dbSubID).Scan(&dbSubStatus)
	require.NoError(t, err)
	assert.Equal(t, "PAST_DUE", dbSubStatus)

	// 7. Test invoice.paid (should shift period and create a new usage counter bucket)
	t.Log("Testing invoice.paid ...")
	invoiceEventID := "evt_invoice_" + uuid.New().String()[:8]
	shiftedStartTS := endTS
	shiftedEndTS := endTS + int64(30*24*time.Hour/time.Second)

	invObj := mockStripeInvoice{
		ID:           "in_test_" + uuid.New().String()[:8],
		Customer:     stripeCustomerID,
		Subscription: stripeSubID,
		AmountPaid:   10000,
		AmountDue:    10000,
		Currency:     "pln",
		PeriodStart:  shiftedStartTS,
		PeriodEnd:    shiftedEndTS,
	}
	invObj.Lines.Data = []mockStripeInvoiceLine{
		{
			Period: struct {
				Start int64 `json:"start"`
				End   int64 `json:"end"`
			}{
				Start: shiftedStartTS,
				End:   shiftedEndTS,
			},
			Price: mockStripePrice{ID: stripePriceID},
		},
	}

	postWebhook(t, env, "invoice.paid", invoiceEventID, invObj, secret)

	// Capture payment_event ID
	err = env.dbPool.QueryRow(ctx, `
		SELECT id FROM payment_events WHERE provider_event_id = $1`, 
		invoiceEventID).Scan(&peID)
	require.NoError(t, err)
	paymentEventIDs = append(paymentEventIDs, peID)

	// Verify subscription period shifted
	var currentPeriodStart, currentPeriodEnd time.Time
	err = env.dbPool.QueryRow(ctx, `
		SELECT current_period_start, current_period_end FROM subscriptions WHERE id = $1`, 
		dbSubID).Scan(&currentPeriodStart, &currentPeriodEnd)
	require.NoError(t, err)
	assert.Equal(t, time.Unix(shiftedStartTS, 0).UTC(), currentPeriodStart.UTC())
	assert.Equal(t, time.Unix(shiftedEndTS, 0).UTC(), currentPeriodEnd.UTC())

	// Verify a new usage_counter was created
	err = env.dbPool.QueryRow(ctx, `
		SELECT COUNT(*) FROM usage_counters WHERE subscription_id = $1`, 
		dbSubID).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 2, count, "should have 2 usage_counters after invoice.paid shifts period")

	// 8. Test customer.subscription.deleted (CANCELED)
	t.Log("Testing customer.subscription.deleted ...")
	deletedEventID := "evt_deleted_" + uuid.New().String()[:8]
	subObj.Status = "canceled"
	subObj.CanceledAt = time.Now().Unix()
	postWebhook(t, env, "customer.subscription.deleted", deletedEventID, subObj, secret)

	// Capture payment_event ID
	err = env.dbPool.QueryRow(ctx, `
		SELECT id FROM payment_events WHERE provider_event_id = $1`, 
		deletedEventID).Scan(&peID)
	require.NoError(t, err)
	paymentEventIDs = append(paymentEventIDs, peID)

	// Verify status canceled in DB
	err = env.dbPool.QueryRow(ctx, `
		SELECT status::text FROM subscriptions WHERE id = $1`, 
		dbSubID).Scan(&dbSubStatus)
	require.NoError(t, err)
	assert.Equal(t, "CANCELED", dbSubStatus)
}
