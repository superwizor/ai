package grpc

import (
	"context"
	"strings"
	"testing"

	"google.golang.org/grpc/codes"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/appconfig"
)

func serwerKontroli(t *testing.T) *Server {
	t.Helper()
	cfg := appconfig.NewReader(&atrapaKonfEksp{wiersze: [][2]string{
		{appconfig.KeyReportExperimentalEnabled, "false"},
		{appconfig.KeyReportExperimentalDailyLimit, "5"},
	}})
	return (&Server{}).WithChatConfig(cfg, &atrapaZapisuKonfiguracji{})
}

type atrapaZapisuKonfiguracji struct{ zapisy [][2]string }

// Exec zapisuje WYLACZNIE upserty konfiguracji.
//
// Ta sama pula obsluguje wpisy audytowe, wiec bez filtra po SQL-u test
// liczylby je jako zmiany konfiguracji — i „jedna zmiana" wygladalaby na
// dwie.
func (a *atrapaZapisuKonfiguracji) Exec(_ context.Context, sql string, args ...any) (int64, error) {
	if strings.Contains(sql, "INTO app_config") && len(args) >= 2 {
		k, _ := args[0].(string)
		v, _ := args[1].(string)
		a.zapisy = append(a.zapisy, [2]string{k, v})
	}
	return 1, nil
}

func ctxAdmin() context.Context {
	return ctxRola("SUPERWIZOR_ADMIN")
}

// TestTrybEksperymentalnyTylkoDlaAdmina — raport powstaje na ontologii BEZ
// autoryzacji ekspertów, więc przełącznik nie może być w zasięgu roli,
// która ontologie tworzy. To ten sam rozdział ról, co przy aktywacji.
func TestTrybEksperymentalnyTylkoDlaAdmina(t *testing.T) {
	srv := serwerKontroli(t)
	for _, rola := range []string{"ONTOLOGY_EDITOR", "ORG_ADMIN", "THERAPIST"} {
		_, err := srv.AdminSetExperimentalControls(ctxRola(rola),
			&clinicalv1.AdminSetExperimentalControlsRequest{
				Enabled: proto(true), Note: "próba",
			})
		if kod(err) != codes.PermissionDenied {
			t.Errorf("%s: kod = %v, oczekiwano PermissionDenied", rola, kod(err))
		}
	}
}

// TestNotatkaJestWymagana — wpis audytowy bez powodu nie odpowiada na
// żadne pytanie, które ktoś potem zada.
func TestNotatkaJestWymaganaPrzyTrybie(t *testing.T) {
	srv := serwerKontroli(t)
	_, err := srv.AdminSetExperimentalControls(ctxAdmin(),
		&clinicalv1.AdminSetExperimentalControlsRequest{Enabled: proto(true)})
	if kod(err) != codes.InvalidArgument {
		t.Fatalf("kod = %v, oczekiwano InvalidArgument", kod(err))
	}
}

// TestLimitMaGorneOgraniczenie — jeden raport to kilkanaście wywołań Pro,
// a dual-run mnoży to przez liczbę sesji. Literówka w polu limitu nie
// może być rachunkiem.
func TestLimitMaGorneOgraniczenie(t *testing.T) {
	srv := serwerKontroli(t)
	_, err := srv.AdminSetExperimentalControls(ctxAdmin(),
		&clinicalv1.AdminSetExperimentalControlsRequest{
			DailyLimit: protoI64(500), Note: "literówka",
		})
	if kod(err) != codes.InvalidArgument {
		t.Fatalf("kod = %v, oczekiwano InvalidArgument dla limitu 500", kod(err))
	}
	if _, err := srv.AdminSetExperimentalControls(ctxAdmin(),
		&clinicalv1.AdminSetExperimentalControlsRequest{
			DailyLimit: protoI64(-1), Note: "ujemny",
		}); kod(err) != codes.InvalidArgument {
		t.Errorf("ujemny limit przeszedl: %v", kod(err))
	}
}

// TestZmianaJednegoPolaNieRuszaDrugiego — pola są `optional` właśnie po
// to: bez tego „zmień limit, zostaw flagę" cicho przestawiałoby flagę.
func TestZmianaJednegoPolaNieRuszaDrugiego(t *testing.T) {
	srv := serwerKontroli(t)
	pula := srv.pool.(*atrapaZapisuKonfiguracji)

	if _, err := srv.AdminSetExperimentalControls(ctxAdmin(),
		&clinicalv1.AdminSetExperimentalControlsRequest{
			DailyLimit: protoI64(3), Note: "sam limit",
		}); err != nil {
		t.Fatalf("zmiana limitu odrzucona: %v", err)
	}
	for _, z := range pula.zapisy {
		if z[0] == appconfig.KeyReportExperimentalEnabled {
			t.Fatalf("zmiana samego limitu ruszyla flage: %v", z)
		}
	}
	if len(pula.zapisy) != 1 || pula.zapisy[0][1] != "3" {
		t.Fatalf("zapisy = %v, oczekiwano jednego wpisu limitu", pula.zapisy)
	}
}

func TestPustaZmianaJestOdrzucana(t *testing.T) {
	srv := serwerKontroli(t)
	_, err := srv.AdminSetExperimentalControls(ctxAdmin(),
		&clinicalv1.AdminSetExperimentalControlsRequest{Note: "nic nie zmieniam"})
	if kod(err) != codes.InvalidArgument {
		t.Fatalf("kod = %v, oczekiwano InvalidArgument", kod(err))
	}
}

func proto(b bool) *bool      { return &b }
func protoI64(i int64) *int64 { return &i }
