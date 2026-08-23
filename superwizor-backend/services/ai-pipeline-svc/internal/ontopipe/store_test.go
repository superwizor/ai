package ontopipe

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

type zapis struct {
	sql  string
	args []any
}

type fakeDB struct {
	zapisy []zapis
	licz   int
}

func (f *fakeDB) Exec(_ context.Context, sql string, args ...any) error {
	f.zapisy = append(f.zapisy, zapis{sql, args})
	return nil
}

func (f *fakeDB) QueryUUID(_ context.Context, sql string, args ...any) (uuid.UUID, error) {
	f.zapisy = append(f.zapisy, zapis{sql, args})
	f.licz++
	return uuid.New(), nil
}

// doTabeli szuka zapisow do wskazanej tabeli.
//
// Dopasowanie odporne na bialy znak po nazwie: zapytania wieloliniowe
// lamia sie zaraz za nazwa tabeli, a wersja wymagajaca spacji po cichu
// przestawala widziec wpisy przy pierwszym przeformatowaniu SQL-a.
func (f *fakeDB) doTabeli(nazwa string) []zapis {
	var out []zapis
	for _, z := range f.zapisy {
		i := strings.Index(z.sql, "INTO "+nazwa)
		if i < 0 {
			continue
		}
		reszta := z.sql[i+len("INTO "+nazwa):]
		if reszta == "" || reszta[0] == ' ' || reszta[0] == '\n' ||
			reszta[0] == '\t' || reszta[0] == '(' {
			out = append(out, z)
		}
	}
	return out
}

// fakeCrypto oznacza tekst prefiksem, zeby test mogl sprawdzic, ze do
// bazy poszedl szyfrogram, a nie tekst jawny.
type fakeCrypto struct{}

func (fakeCrypto) Encrypt(_ context.Context, p []byte) ([]byte, []byte, error) {
	return append([]byte("ENC:"), p...), []byte("DEK"), nil
}

func wynikDoZapisu() Result {
	return Result{
		Spans: []ontology.TopicSpan{
			{Span: ontology.Span{ID: "s01", QuoteVerbatim: "chcę być blisko",
				Speaker: "Klient", Kind: ontology.SpanDeclarative,
				ObservedBy: ontology.ObservedBySelf}},
			{Span: ontology.Span{ID: "s99", QuoteVerbatim: "myślę, żeby to zakończyć",
				Speaker: "Klient", RiskContent: true}},
		},
		Approved: []ontology.Claim{{
			ConstructID: "konflikt",
			Categories:  []string{"blizkosc-autonomia"},
			Status:      ontology.StatusInterpretation,
			Confidence:  0.7,
			Reasoning:   "Dwie dążności w jednej wypowiedzi.",
			Evidence:    []ontology.QuoteRef{{SpanID: "s01", Quote: "chcę być blisko"}},
			CounterEvidence: []ontology.QuoteRef{{SpanID: "s01",
				Quote: "chcę być blisko"}},
		}},
		Patterns: []ontology.Pattern{{ID: "p1", Type: ontology.PatternRecurrence,
			Topics: []string{"zwiazek"}, SpanIDs: []string{"s01"},
			Method: "3 spany", MethodVersion: ontology.MethodVersion, Sessions: 1}},
		Rejected: []ontology.Rejection{{ConstructID: "zasob",
			Reason: ontology.ReasonCoverage, Detail: "spanow 0, wymagane 1",
			Claim: &ontology.Claim{
				ConstructID: "zasob",
				Categories:  []string{"wsparcie"},
				Status:      ontology.StatusObservation,
				Confidence:  0.9,
				Reasoning:   "Klient wspomina siostrę jako osobę wspierającą.",
				Evidence:    []ontology.QuoteRef{{SpanID: "s01", Quote: "chcę być blisko"}},
			}}},
		Degraded: []ontology.Degradation{{ConstructID: "zasob",
			To: "hipoteza robocza", Detail: "brak konfliktu"}},
		Violations: []Violation{{Rule: VRuleQuantity, ConstructID: "konflikt",
			Detail: "wartosc 80 bez pokrycia", HypothesisID: "A",
			HypothesisText:   "Klient wraca do tematu w 80% wypowiedzi.",
			HypothesisStatus: "interpretation",
			HypothesisSpans:  []string{"s01"}}},
	}
}

func zapiszTestowo(t *testing.T) *fakeDB {
	t.Helper()
	db := &fakeDB{}
	err := Persist(context.Background(), db, fakeCrypto{}, PersistInput{
		ReportID: uuid.New(), SessionID: uuid.New(), TranscriptID: uuid.New(),
	}, wynikDoZapisu())
	if err != nil {
		t.Fatalf("Persist: %v", err)
	}
	return db
}

// TestZapisSpanowRyzyka: span ryzyka MA trafic do bazy z flaga, choc nie
// zasila wnioskowania. Wykluczenie ma byc ZAPISANE, a nie liczone od nowa
// przy kazdym odczycie — inaczej zmiana progu detekcji po cichu zmienia
// historyczne raporty.
func TestZapisSpanowRyzyka(t *testing.T) {
	db := zapiszTestowo(t)
	spany := db.doTabeli("report_spans")
	if len(spany) != 2 {
		t.Fatalf("zapisanych spanow %d, oczekiwano 2 (w tym span ryzyka)", len(spany))
	}
	znaleziony := false
	for _, z := range spany {
		if z.args[2] == "s99" {
			znaleziony = true
			if z.args[9] != true {
				t.Fatal("span ryzyka zapisany z risk_content = false")
			}
		}
	}
	if !znaleziony {
		t.Fatal("span ryzyka nie zostal zapisany w ogole")
	}
}

func TestCytatIUzasadnienieSaSzyfrowane(t *testing.T) {
	db := zapiszTestowo(t)
	for _, z := range db.doTabeli("report_spans") {
		ct, ok := z.args[3].([]byte)
		if !ok || !strings.HasPrefix(string(ct), "ENC:") {
			t.Fatalf("cytat trafil do bazy nieszyfrowany: %v", z.args[3])
		}
	}
	for _, z := range db.doTabeli("report_claims") {
		ct, ok := z.args[5].([]byte)
		if !ok || !strings.HasPrefix(string(ct), "ENC:") {
			t.Fatalf("uzasadnienie trafilo do bazy nieszyfrowane: %v", z.args[5])
		}
	}
}

// TestDowodIKontrdowodMajaRozneRole: format przestrzeni hipotez renderuje
// "dane za" i "dane przeciw" osobno — gdyby zapisywaly sie tak samo,
// raport straciłby to rozróżnienie.
func TestDowodIKontrdowodMajaRozneRole(t *testing.T) {
	db := zapiszTestowo(t)
	role := map[string]bool{}
	for _, z := range db.doTabeli("report_claim_evidence") {
		role[z.args[2].(string)] = true
	}
	if !role["support"] || !role["counter"] {
		t.Fatalf("role proweniencji = %v, oczekiwano support i counter", role)
	}
}

// TestRejestrObejmujeOdrzuceniaDegradacjeINaruszenia: progi przeglądu
// (dok. 11 §8.3) to JEDNO zapytanie SQL — rozbicie na trzy tabele
// zamieniłoby je w trzy.
func TestRejestrObejmujeOdrzuceniaDegradacjeINaruszenia(t *testing.T) {
	db := zapiszTestowo(t)
	reguly := map[string]bool{}
	for _, z := range db.doTabeli("report_claim_rejections") {
		reguly[z.args[2].(string)] = true
	}
	for _, oczekiwana := range []string{
		string(ontology.ReasonCoverage),
		string(ontology.ReasonRequires),
		string(VRuleQuantity),
	} {
		if !reguly[oczekiwana] {
			t.Fatalf("rejestr nie zawiera %q; ma: %v", oczekiwana, reguly)
		}
	}
}

func TestWzorzecMaProweniencjeDoSpanow(t *testing.T) {
	db := zapiszTestowo(t)
	if n := len(db.doTabeli("report_pattern_spans")); n != 1 {
		t.Fatalf("powiazan wzorzec-span %d, oczekiwano 1", n)
	}
}

// TestOdrzuceniaNiosaUzasadnienie — od migracji 000095 rejestr trzyma
// treść odrzuconego twierdzenia. Bez niej nie da się rozstrzygnąć, czy
// reguła zadziałała słusznie: kanarek CBT odrzucił trzy twierdzenia na
// wartości „2" i nie dało się ustalić, czy model sfabrykował precyzję,
// czy odwołał się do numeracji własnego modelu.
func TestOdrzuceniaNiosaUzasadnienie(t *testing.T) {
	db := zapiszTestowo(t)
	wpisy := db.doTabeli("report_claim_rejections")
	if len(wpisy) == 0 {
		t.Fatal("brak wpisow rejestru")
	}

	znalezioneS3, znalezioneS5 := false, false
	for _, z := range wpisy {
		rule := z.args[2].(string)
		switch rule {
		case string(ontology.ReasonCoverage):
			znalezioneS3 = true
			ct, ok := z.args[4].([]byte)
			if !ok || !strings.HasPrefix(string(ct), "ENC:") {
				t.Errorf("uzasadnienie odrzuconego twierdzenia nieszyfrowane: %v", z.args[4])
			}
			if kat, _ := z.args[6].([]string); len(kat) != 1 || kat[0] != "wsparcie" {
				t.Errorf("zaproponowane kategorie = %v, oczekiwano [wsparcie]", z.args[6])
			}
			if spany, _ := z.args[9].([]string); len(spany) != 1 || spany[0] != "s01" {
				t.Errorf("odnosniki do spanow = %v, oczekiwano [s01]", z.args[9])
			}
		case string(VRuleQuantity):
			znalezioneS5 = true
			ct, ok := z.args[4].([]byte)
			if !ok || !strings.HasPrefix(string(ct), "ENC:") {
				t.Errorf("tresc naruszonej hipotezy nieszyfrowana: %v", z.args[4])
			}
		case string(ontology.ReasonRequires):
			// Degradacja dotyczy konstruktu — tresci byc nie moze.
			if z.args[4] != nil {
				if ct, ok := z.args[4].([]byte); ok && len(ct) > 0 {
					t.Error("degradacja konstruktu dostala tresc twierdzenia")
				}
			}
		}
	}
	if !znalezioneS3 {
		t.Error("odrzucenie walidatora S3 nie trafilo do rejestru z trescia")
	}
	if !znalezioneS5 {
		t.Error("naruszenie weryfikatora S5 nie trafilo do rejestru z trescia")
	}
}
