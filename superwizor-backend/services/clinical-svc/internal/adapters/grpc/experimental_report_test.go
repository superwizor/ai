package grpc

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/appconfig"
)

// atrapaPuliEksp odpowiada na kolejne zapytania wg skryptu, zeby test
// mogl ustawic jeden konkretny warunek (brak transkrypcji, przekroczony
// limit) bez stawiania bazy.
type atrapaPuliEksp struct {
	wlasciciel   uuid.UUID
	org          *uuid.UUID
	modalnosc    string
	transkrypcja *uuid.UUID
	uzyteDzis    int64
	wersjaID     uuid.UUID
	bladSesji    error
	bladLicznika error
	zapisano     bool
}

func (p *atrapaPuliEksp) Exec(context.Context, string, ...any) (int64, error) { return 0, nil }
func (p *atrapaPuliEksp) Query(context.Context, string, ...any) (OntologyRows, error) {
	return nil, errors.New("nieuzywane")
}

func (p *atrapaPuliEksp) QueryRow(_ context.Context, sql string, _ ...any) OntologyRow {
	switch {
	case contains(sql, "FROM sessions s"):
		if p.bladSesji != nil {
			return atrapaWiersza{err: p.bladSesji}
		}
		return wierszSesji{p}
	case contains(sql, "count(*) FROM experimental_report_requests"):
		if p.bladLicznika != nil {
			return atrapaWiersza{err: p.bladLicznika}
		}
		return wierszLicznika{p.uzyteDzis}
	case contains(sql, "SELECT ov.id FROM ontology_versions"):
		return wierszWersji{p.wersjaID}
	case contains(sql, "INSERT INTO experimental_report_requests"):
		p.zapisano = true
		return wierszWersji{uuid.New()}
	}
	return atrapaWiersza{err: errors.New("nieoczekiwane zapytanie: " + sql)}
}

func contains(s, sub string) bool { return len(s) >= len(sub) && indexOf(s, sub) >= 0 }

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}

type wierszSesji struct{ p *atrapaPuliEksp }

func (w wierszSesji) Scan(dest ...any) error {
	*(dest[0].(*uuid.UUID)) = w.p.wlasciciel
	*(dest[1].(**uuid.UUID)) = w.p.org
	*(dest[2].(*string)) = w.p.modalnosc
	*(dest[3].(**uuid.UUID)) = w.p.transkrypcja
	return nil
}

type wierszLicznika struct{ n int64 }

func (w wierszLicznika) Scan(dest ...any) error { *(dest[0].(*int64)) = w.n; return nil }

type wierszWersji struct{ id uuid.UUID }

func (w wierszWersji) Scan(dest ...any) error { *(dest[0].(*uuid.UUID)) = w.id; return nil }

// serwerEksp sklada serwer z konfiguracja podana wprost.
func serwerEksp(t *testing.T, pool *atrapaPuliEksp, wlaczone bool, limit string) (*Server, *fakePublisher) {
	t.Helper()
	cfg := appconfig.NewReader(&atrapaKonfEksp{wiersze: [][2]string{
		{appconfig.KeyReportExperimentalEnabled, boolStr(wlaczone)},
		{appconfig.KeyReportExperimentalDailyLimit, limit},
	}})
	pub := &fakePublisher{}
	srv := (&Server{}).WithOntologyStudio(pool).WithChatConfig(cfg, nil)
	srv.pubsub = pub
	return srv, pub
}

func boolStr(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

func ctxTerapeuty(id uuid.UUID) context.Context {
	ctx := context.WithValue(context.Background(), UserRoleKey, "THERAPIST")
	return context.WithValue(ctx, UserIDKey, id.String())
}

func zamowienie(sessionID uuid.UUID) *clinicalv1.GenerateExperimentalReportRequest {
	return &clinicalv1.GenerateExperimentalReportRequest{SessionId: sessionID.String()}
}

func pulaGotowa(terapeuta uuid.UUID) *atrapaPuliEksp {
	tid := uuid.New()
	return &atrapaPuliEksp{
		wlasciciel: terapeuta, modalnosc: "PPT", transkrypcja: &tid,
		wersjaID: uuid.New(),
	}
}

// TestFlagaOrganizacjiJestBramka — bez niej kazdy terapeuta generowalby
// raporty na niezautoryzowanej ontologii.
func TestFlagaOrganizacjiJestBramka(t *testing.T) {
	terapeuta := uuid.New()
	srv, pub := serwerEksp(t, pulaGotowa(terapeuta), false, "5")

	_, err := srv.GenerateExperimentalReport(ctxTerapeuty(terapeuta), zamowienie(uuid.New()))
	if kod(err) != codes.PermissionDenied {
		t.Fatalf("kod = %v, oczekiwano PermissionDenied", kod(err))
	}
	if len(pub.experimental) != 0 {
		t.Fatal("zamowienie opublikowane mimo wylaczonej flagi")
	}
}

// TestDobowyLimitZatrzymuje — potok wieloetapowy na Pro jest drogi.
func TestDobowyLimitZatrzymuje(t *testing.T) {
	terapeuta := uuid.New()
	pool := pulaGotowa(terapeuta)
	pool.uzyteDzis = 5
	srv, pub := serwerEksp(t, pool, true, "5")

	_, err := srv.GenerateExperimentalReport(ctxTerapeuty(terapeuta), zamowienie(uuid.New()))
	if kod(err) != codes.ResourceExhausted {
		t.Fatalf("kod = %v, oczekiwano ResourceExhausted", kod(err))
	}
	if len(pub.experimental) != 0 {
		t.Fatal("zamowienie opublikowane mimo wyczerpanego limitu")
	}
}

// TestAwariaLicznikaNieOtwieraLimitu: nieznany licznik to NIE jest zgoda.
// Odwrotna interpretacja zamienia awarie odczytu w nieograniczony wydatek.
func TestAwariaLicznikaNieOtwieraLimitu(t *testing.T) {
	terapeuta := uuid.New()
	pool := pulaGotowa(terapeuta)
	pool.bladLicznika = errors.New("baza niedostepna")
	srv, pub := serwerEksp(t, pool, true, "5")

	_, err := srv.GenerateExperimentalReport(ctxTerapeuty(terapeuta), zamowienie(uuid.New()))
	if kod(err) != codes.Unavailable {
		t.Fatalf("kod = %v, oczekiwano Unavailable", kod(err))
	}
	if len(pub.experimental) != 0 {
		t.Fatal("zamowienie opublikowane mimo nieznanego licznika")
	}
}

// TestSesjaBezTranskrypcjiOdrzucona — nie ma z czego zbudowac raportu, a
// ponowienie tego nie naprawi.
func TestSesjaBezTranskrypcjiOdrzucona(t *testing.T) {
	terapeuta := uuid.New()
	pool := pulaGotowa(terapeuta)
	pool.transkrypcja = nil
	srv, _ := serwerEksp(t, pool, true, "5")

	_, err := srv.GenerateExperimentalReport(ctxTerapeuty(terapeuta), zamowienie(uuid.New()))
	if kod(err) != codes.FailedPrecondition {
		t.Fatalf("kod = %v, oczekiwano FailedPrecondition", kod(err))
	}
}

// TestCudzaSesjaNiedostepna — bramka wlasnosci danych dziala tak samo
// jak w pozostalych RPC: NotFound, zeby nie dalo sie enumerowac obiektow.
func TestCudzaSesjaNiedostepna(t *testing.T) {
	pool := pulaGotowa(uuid.New()) // wlascicielem jest KTOS INNY
	srv, pub := serwerEksp(t, pool, true, "5")

	_, err := srv.GenerateExperimentalReport(ctxTerapeuty(uuid.New()), zamowienie(uuid.New()))
	if kod(err) != codes.NotFound {
		t.Fatalf("kod = %v, oczekiwano NotFound", kod(err))
	}
	if len(pub.experimental) != 0 {
		t.Fatal("zamowienie opublikowane dla cudzej sesji")
	}
}

// TestUdaneZamowieniePrzekazujeKomplet: worker rozpoznaje tryb po
// atrybutach, wiec brak ktoregokolwiek z nich cicho zmienia zachowanie.
func TestUdaneZamowieniePrzekazujeKomplet(t *testing.T) {
	terapeuta := uuid.New()
	pool := pulaGotowa(terapeuta)
	srv, pub := serwerEksp(t, pool, true, "5")

	sesja := uuid.New()
	resp, err := srv.GenerateExperimentalReport(ctxTerapeuty(terapeuta), zamowienie(sesja))
	if err != nil {
		t.Fatalf("zamowienie odrzucone: %v", err)
	}
	if len(pub.experimental) != 1 {
		t.Fatalf("opublikowanych zamowien %d, oczekiwano 1", len(pub.experimental))
	}
	ev := pub.experimental[0]
	if ev.SessionID != sesja.String() {
		t.Errorf("session_id = %q", ev.SessionID)
	}
	if ev.TranscriptID == "" {
		t.Error("brak transcript_id — worker nie mialby czego wczytac")
	}
	if ev.RequestID == "" {
		t.Error("brak request_id — zamowienia nie da sie dowiazac do raportu")
	}
	if ev.ModalityCode != "PPT" {
		t.Errorf("modality_code = %q, oczekiwano modalnosci kartoteki", ev.ModalityCode)
	}
	if ev.OntologyVersionID == "" {
		t.Error("brak wersji ontologii — przebieg nie bylby odtwarzalny")
	}
	if ev.RequestedBy != terapeuta.String() {
		t.Errorf("requested_by = %q", ev.RequestedBy)
	}
	if !pool.zapisano {
		t.Error("zamowienie nie zostalo zapisane — nie policzy sie do limitu")
	}
	if resp.RemainingToday != 4 {
		t.Errorf("pozostalo dzis = %d, oczekiwano 4", resp.RemainingToday)
	}
}

// TestNadpisanieModalnosci — "raport CBT dla kartoteki PPT" jest jednym
// z dwoch powodow istnienia tego trybu.
func TestNadpisanieModalnosci(t *testing.T) {
	terapeuta := uuid.New()
	pool := pulaGotowa(terapeuta)
	srv, pub := serwerEksp(t, pool, true, "5")

	req := zamowienie(uuid.New())
	req.ModalityCode = "cbt"
	if _, err := srv.GenerateExperimentalReport(ctxTerapeuty(terapeuta), req); err != nil {
		t.Fatalf("zamowienie odrzucone: %v", err)
	}
	if pub.experimental[0].ModalityCode != "CBT" {
		t.Fatalf("modality_code = %q, oczekiwano CBT", pub.experimental[0].ModalityCode)
	}
}

// ── atrapa konfiguracji ──

type atrapaKonfEksp struct{ wiersze [][2]string }

func (a *atrapaKonfEksp) Query(context.Context, string, ...any) (appconfig.Rows, error) {
	return &wierszeKonfEksp{w: a.wiersze}, nil
}

type wierszeKonfEksp struct {
	w [][2]string
	i int
}

func (r *wierszeKonfEksp) Next() bool { r.i++; return r.i <= len(r.w) }
func (r *wierszeKonfEksp) Scan(dest ...any) error {
	cur := r.w[r.i-1]
	*(dest[0].(*string)) = cur[0]
	*(dest[1].(*string)) = cur[1]
	*(dest[2].(**uuid.UUID)) = nil
	return nil
}
func (r *wierszeKonfEksp) Err() error { return nil }
func (r *wierszeKonfEksp) Close()     {}
