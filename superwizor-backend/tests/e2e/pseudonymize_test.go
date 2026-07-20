//go:build e2e
// +build e2e

package e2e_test

// pseudonymize_test.go — e2e bramka docs/41 na żywym stagingu.
// Wymaga LLM_PSEUDONYMIZE=all na llm-workerze oraz fixture audio z
// wstrzykniętą PII (AUDIO_FILE): dialog zawiera nazwisko "Kowalski/m",
// pracodawcę "Softex/ie", miasto "Wrocław/ia", szkołę i nazwisko
// "Wiśniewska". Asercje: raport + Title/Summary NIE zawierają tych fraz
// (STT może je przekręcić — wtedy sprawdzamy tylko obecność tokenów),
// a imiona (Anna/Karol/Staś) MOGĄ w nich być.
//
// Tryb: PII_E2E=strict → fail na leaku; inaczej observe+log (suite
// zostaje zielona przy fladze off).

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
)

func TestPseudonymize_E2E(t *testing.T) {
	if os.Getenv("AUDIO_FILE") == "" {
		t.Skip("AUDIO_FILE (fixture z PII) not set")
	}
	strict := os.Getenv("PII_E2E") == "strict"
	cfg := loadConfig(t)
	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_pii_uid_%d", runID)
	firebaseEmail := fmt.Sprintf("test_pii_%d@example.com", runID)

	audioSize := assertValidAudio(t, cfg.audioFile)

	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer tokenCancel()
	var idToken string
	if cfg.preMintedToken != "" {
		idToken = cfg.preMintedToken
	} else {
		fbSession, err := mintFirebaseSession(tokenCtx, cfg.projectID, cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
		require.NoError(t, err)
		t.Cleanup(func() { _ = fbSession.cleanup() })
		idToken = fbSession.IDToken
	}

	identityConn := dial(t, cfg.identityURL, idToken)
	t.Cleanup(func() { _ = identityConn.Close() })
	clinicalConn := dial(t, cfg.clinicalURL, idToken)
	t.Cleanup(func() { _ = clinicalConn.Close() })
	ingestionConn := dial(t, cfg.ingestionURL, idToken)
	t.Cleanup(func() { _ = ingestionConn.Close() })

	identityClient := identityv1.NewIdentityServiceClient(identityConn)
	clinicalClient := clinicalv1.NewClinicalServiceClient(clinicalConn)
	ingestionClient := ingestionv1.NewIngestionServiceClient(ingestionConn)

	ctx, cancel := context.WithTimeout(context.Background(), cfg.pollDeadline+5*time.Minute)
	defer cancel()

	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid: firebaseUID, Email: firebaseEmail,
		Role:      identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName: "PII", LastName: "Therapist",
		UiLanguage: "pl", Timezone: "Europe/Warsaw", HasAcceptedTos: true,
	})
	require.NoError(t, err)

	mods, err := clinicalClient.ListModalities(ctx, &emptypb.Empty{})
	require.NoError(t, err)
	require.NotEmpty(t, mods.Modalities)

	patient, err := clinicalClient.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId: therapist.Id, ModalityCode: "CBT",
		WorkingAlias:        fmt.Sprintf("PII E2E %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "PII redaction e2e",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-pii-%d", runID),
		PatientFirstName:    "Anna", PatientLastName: "P",
		PatientLanguageCode: "pl",
	})
	require.NoError(t, err)
	t.Cleanup(func() {
		bgCtx, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgCancel()
		_, _ = clinicalClient.DeletePatientFile(bgCtx, &clinicalv1.DeletePatientFileRequest{PatientFileId: patient.Id})
	})

	sessID := runPipelineSession(t, ctx, cfg, ingestionClient, clinicalClient,
		therapist.Id, patient.Id, fmt.Sprintf("e2e-pii-up-%d", runID), audioSize)

	details, err := clinicalClient.GetSessionDetails(ctx, &clinicalv1.GetSessionDetailsRequest{SessionId: sessID})
	require.NoError(t, err)
	require.NotEmpty(t, details.Reports)

	combined := strings.ToLower(details.Reports[0].Title + "\n" +
		details.Reports[0].SummaryShort + "\n" + details.Reports[0].Content)
	if details.Session != nil {
		combined += "\n" + strings.ToLower(details.Session.Name)
	}

	// Frazy PII wstrzyknięte do fixture (formy bazowe — STT je zwykle
	// utrzymuje; przekręcenia łapie eval offline, nie e2e).
	blacklist := []string{"kowalski", "kowalskim", "softex", "wrocław", "wrocławia", "wiśniewska"}
	var leaks []string
	for _, b := range blacklist {
		if strings.Contains(combined, b) {
			leaks = append(leaks, b)
		}
	}

	// Imiona muszą przetrwać przynajmniej częściowo (miękka asercja —
	// raport nie musi cytować każdego imienia).
	namesSeen := 0
	for _, n := range []string{"anna", "karol", "staś", "stas"} {
		if strings.Contains(combined, n) {
			namesSeen++
		}
	}
	hasTokens := strings.Contains(combined, "[nazwisko") || strings.Contains(combined, "[pracodawca") ||
		strings.Contains(combined, "[miejscowość")

	t.Logf("leaks=%v namesSeen=%d tokensPresent=%v", leaks, namesSeen, hasTokens)
	if len(leaks) > 0 {
		msg := fmt.Sprintf("PII leaked into report/title/summary: %v", leaks)
		if strict {
			t.Fatal(msg)
		}
		t.Logf("⚠ (non-strict) %s — is LLM_PSEUDONYMIZE=all deployed?", msg)
	} else {
		t.Logf("✓ no injected PII in report/title/summary (tokens present: %v)", hasTokens)
	}

	// ── Kanoniczna transkrypcja (pełna pseudonimizacja) ──
	// Przy LLM_PSEUDONYMIZE_CANONICAL=on llm-worker nadpisuje blob +
	// transcript_segments zredagowaną wersją, więc widok transkrypcji
	// (ten sam, który renderują aplikacje) nie może zawierać czarnej
	// listy. Osobna bramka PII_CANON_E2E=strict — suite zostaje zielona
	// zanim flaga trafi na staging.
	canonStrict := os.Getenv("PII_CANON_E2E") == "strict"
	var tleaks []string
	if details.Transcript != nil {
		var sb strings.Builder
		for _, turn := range details.Transcript.Turns {
			sb.WriteString(turn.Text)
			sb.WriteString("\n")
		}
		for _, seg := range details.Transcript.Segments {
			sb.WriteString(seg.Text)
			sb.WriteString("\n")
		}
		ttext := strings.ToLower(sb.String())
		for _, b := range blacklist {
			if strings.Contains(ttext, b) {
				tleaks = append(tleaks, b)
			}
		}
	}
	if len(tleaks) > 0 {
		msg := fmt.Sprintf("PII present in canonical transcript view: %v", tleaks)
		if canonStrict {
			t.Fatal(msg)
		}
		t.Logf("⚠ (non-strict) %s — is LLM_PSEUDONYMIZE_CANONICAL=on deployed?", msg)
	} else {
		t.Logf("✓ no injected PII in canonical transcript (turns+segments)")
	}
}
