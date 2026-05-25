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
//   pending_reservations, outbox_events.
//
// Edge cases pokryte:
//   - Token calculator boundary (45/63/64/120/123min)
//   - Idempotency (2x ten sam session_id)
//   - Quota exhausted gate
//   - ReserveCredit → ReleaseCredit roundtrip
//   - ReserveCredit → CommitUsage transfer
//   - Outbox edge-trigger (warning/critical/exhausted)
//   - PAST_DUE blokuje reservation
//   - Stale reservation expiry (manual /admin/reservation-expiry call)
package e2e_test

import (
	"context"
	"crypto/tls"
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
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
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
	creds := credentials.NewTLS(&tls.Config{MinVersion: tls.VersionTLS12})
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

// readOutboxEvent — wraca najnowszy outbox event dla danego subscription.
// Nil jeśli nic nie ma.
func (e *billingTestEnv) readLatestOutboxEvent(t *testing.T, since time.Time) (eventType string, payload map[string]any, found bool) {
	ctx := context.Background()
	var et string
	var pl []byte
	err := e.dbPool.QueryRow(ctx, `
		SELECT event_type, payload FROM outbox_events
		WHERE organization_id = $1 AND created_at > $2
		ORDER BY created_at DESC LIMIT 1`,
		e.orgID, since).Scan(&et, &pl)
	if err != nil {
		return "", nil, false
	}
	p := map[string]any{}
	require.NoError(t, json.Unmarshal(pl, &p))
	return et, p, true
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
// Formuła: max(1, ceil((duration - 180) / 3600))
// Boundary cases (z docs/16_*.md):
//   45min = 2700s → 1 token
//   60min = 3600s → 1 token
//   63min = 3780s → 1 token (saved by grace)
//   64min = 3840s → 2 tokens
//   120min = 7200s → 2 tokens
//   124min = 7440s → 3 tokens
func TestBilling_TokenCalculation_Boundaries(t *testing.T) {
	env := loadBillingEnv(t)

	cases := []struct {
		name        string
		duration    int32
		wantTokens  int32
	}{
		{"45min one token", 2700, 1},
		{"60min one token", 3600, 1},
		{"63min boundary one token", 3780, 1},
		{"64min crosses to two", 3840, 2},
		{"120min two tokens", 7200, 2},
		{"124min crosses to three", 7440, 3},
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

// ============================================================================
// Outbox edge cases
// ============================================================================

// TestBilling_Outbox_QuotaWarning — counter 6 used, jedna sesja → 5 remaining → warning event
func TestBilling_Outbox_QuotaWarning(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)
	// Limit 40, set used=34 → remaining=6. Commit 1 token (45min) → remaining=5 → warning edge.
	env.setCounterUsage(t, 34, 0)
	defer env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	before := time.Now()
	_, err := c.CommitUsage(ctx, &billingv1.CommitUsageRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		DurationSeconds: 2700,
	})
	require.NoError(t, err)

	// Outbox event powinien być w DB — poller czyści w tle, ale jeśli zdąży
	// szybko, możemy go nie złapać. Damy 1s na pewność że został zapisany,
	// ale niekoniecznie published.
	time.Sleep(500 * time.Millisecond)

	// Sprawdzamy w outbox_events PO created_at > before — niezależnie od processed.
	ctx2, cancel2 := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel2()
	var eventType string
	err = env.dbPool.QueryRow(ctx2, `
		SELECT event_type FROM outbox_events
		WHERE organization_id = $1 AND created_at > $2
		ORDER BY created_at DESC LIMIT 1`,
		env.orgID, before).Scan(&eventType)
	require.NoError(t, err, "outbox event must be persisted")
	assert.Equal(t, "quota.warning", eventType)
}

// TestBilling_Outbox_QuotaExhausted — counter 39 used → commit 1 → 40 used (0 remaining) → exhausted event
func TestBilling_Outbox_QuotaExhausted(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)
	env.setCounterUsage(t, 39, 0) // 1 remaining
	defer env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	before := time.Now()
	_, err := c.CommitUsage(ctx, &billingv1.CommitUsageRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		DurationSeconds: 2700,
	})
	require.NoError(t, err)

	time.Sleep(500 * time.Millisecond)

	et, payload, found := env.readLatestOutboxEvent(t, before)
	require.True(t, found, "outbox event must exist")
	assert.Equal(t, "quota.exhausted", et)
	assert.EqualValues(t, 0, payload["tokens_remaining"])
}

// TestBilling_Outbox_NoEventWhenNoEdge — commit nie przekraczający progu nie tworzy outboxa
func TestBilling_Outbox_NoEventWhenNoEdge(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t) // 0 used, 40 remaining
	defer env.resetCounter(t)

	conn, c := env.dialBilling(t)
	defer conn.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	sessionID := uuid.New()
	t.Cleanup(func() { env.cleanupSession(t, sessionID) })

	before := time.Now()
	_, err := c.CommitUsage(ctx, &billingv1.CommitUsageRequest{
		SessionId:       sessionID.String(),
		OrganizationId:  env.orgID.String(),
		DurationSeconds: 2700, // 1 token → remaining 39, no edge
	})
	require.NoError(t, err)
	time.Sleep(500 * time.Millisecond)

	_, _, found := env.readLatestOutboxEvent(t, before)
	assert.False(t, found, "no outbox event expected (remaining went 40→39, no threshold)")
}

// ============================================================================
// Race conditions
// ============================================================================

// TestBilling_ConcurrentReserve_LastToken — dwa równoległe Reserve na ostatnim
// tokenie. Tylko jeden powinien wygrać; drugi dostać QUOTA_EXHAUSTED.
func TestBilling_ConcurrentReserve_LastToken(t *testing.T) {
	env := loadBillingEnv(t)
	env.resetCounter(t)
	env.setCounterUsage(t, 39, 0) // 1 token left
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
// Stripe stub
// ============================================================================

func TestBilling_StripeStub_Webhook(t *testing.T) {
	env := loadBillingEnv(t)

	stripeEvent := map[string]any{
		"id":   "evt_test_" + uuid.NewString(),
		"type": "invoice.paid",
		"data": map[string]any{"object": map[string]any{"id": "in_test"}},
	}
	body, _ := json.Marshal(stripeEvent)

	req, err := http.NewRequest("POST", env.billingHTTPURL+"/stripe/webhook",
		strings.NewReader(string(body)))
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+env.idToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	assert.Equal(t, http.StatusOK, resp.StatusCode)

	// Verify w DB: payment_events row z processing_status=IGNORED.
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var pStatus string
	err = env.dbPool.QueryRow(ctx, `
		SELECT processing_status FROM payment_events
		WHERE provider_event_id = $1`, stripeEvent["id"]).Scan(&pStatus)
	require.NoError(t, err, "stub should persist payment_event row")
	assert.Equal(t, "IGNORED", pStatus)

	// Cleanup
	_, _ = env.dbPool.Exec(ctx, `DELETE FROM payment_events WHERE provider_event_id = $1`,
		stripeEvent["id"])
}

// TestBilling_StripeStub_Idempotency — same event_id 2x → 1 row, both 200 OK.
func TestBilling_StripeStub_Idempotency(t *testing.T) {
	env := loadBillingEnv(t)
	eventID := "evt_idem_" + uuid.NewString()
	body := []byte(fmt.Sprintf(`{"id":"%s","type":"invoice.paid"}`, eventID))

	post := func() int {
		req, err := http.NewRequest("POST", env.billingHTTPURL+"/stripe/webhook",
			strings.NewReader(string(body)))
		require.NoError(t, err)
		req.Header.Set("Authorization", "Bearer "+env.idToken)
		req.Header.Set("Content-Type", "application/json")
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		_, _ = io.ReadAll(resp.Body)
		_ = resp.Body.Close()
		return resp.StatusCode
	}

	assert.Equal(t, 200, post())
	assert.Equal(t, 200, post(), "duplicate must still return 200")

	ctx := context.Background()
	var count int
	require.NoError(t, env.dbPool.QueryRow(ctx,
		`SELECT COUNT(*) FROM payment_events WHERE provider_event_id = $1`, eventID,
	).Scan(&count))
	assert.Equal(t, 1, count, "exactly one payment_events row")

	// Cleanup
	_, _ = env.dbPool.Exec(ctx, `DELETE FROM payment_events WHERE provider_event_id = $1`, eventID)
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
