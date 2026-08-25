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
				ObservedBy: ontology.ObservedBySelf},
				Topics: []string{"zwiazek", "blizkosc"}},
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

// Hasla tematyczne musza trafic do bazy (migracja 000097, plan F7a-1).
//
// Bez nich rekurencja MIEDZYSESYJNA nie ma z czego sie policzyc:
// zostawaly wylacznie wzorce wynikowe jednej sesji, a z nich nie da sie
// wyprowadzic niczego, gdy dojdzie sesja kolejna.
func TestZapisHaselTematycznych(t *testing.T) {
	db := zapiszTestowo(t)
	spany := db.doTabeli("report_spans")
	if len(spany) == 0 {
		t.Fatal("brak zapisow spanow")
	}
	if !strings.Contains(spany[0].sql, "topics") {
		t.Fatalf("zapytanie nie zapisuje hasel:\n%s", spany[0].sql)
	}
	znalezione := false
	for _, a := range spany[0].args {
		if lista, ok := a.([]string); ok && len(lista) == 2 &&
			lista[0] == "zwiazek" && lista[1] == "blizkosc" {
			znalezione = true
		}
	}
	if !znalezione {
		t.Fatalf("hasla nie poszly w argumentach: %v", spany[0].args)
	}
}

// Kontekst miedzysesyjny POKAZANY przebiegowi jest utrwalany razem
// z grafem twierdzen (dok. 65 §N2, migracja 000098).
func TestZapisKontekstuPrzebiegu(t *testing.T) {
	db := &fakeDB{}
	sesjaHist := uuid.New()
	claimHist := uuid.New()
	past := &PastContext{
		Claims: []PastClaim{{
			ID: claimHist, SessionID: sesjaHist, ConstructID: "konflikt",
			Status: ontology.StatusInterpretation, Confidence: 0.7,
			Evidence: []string{"s0821:s07"},
		}},
		Spans: []PastSpan{{
			Addr: "s0821:s07", SessionID: sesjaHist, Quote: "wtedy też tak było",
		}},
		Stats: PastStats{
			WindowSize: 3, SessionsLoaded: 2, SessionsSkippedUnfinished: 1,
			ClaimsShown: 1, ClaimsDropped: 4, SpansShown: 1, SpansDropped: 9,
		},
	}
	if err := Persist(context.Background(), db, fakeCrypto{}, PersistInput{
		ReportID: uuid.New(), SessionID: uuid.New(), TranscriptID: uuid.New(),
		Past: past,
	}, wynikDoZapisu()); err != nil {
		t.Fatalf("Persist: %v", err)
	}

	wpisy := db.doTabeli("report_run_context")
	if len(wpisy) != 2 {
		t.Fatalf("oczekiwano wpisu twierdzenia i spanu, jest %d", len(wpisy))
	}
	// Asercje po TRESCI argumentow, nie po ich pozycji: kolejnosc
	// kolumn w tym zapytaniu juz raz sie zmienila (dodanie kanalu
	// w F7b-2) i test padl na przesunieciu indeksu, a nie na regresji.
	maArgument := func(w zapis, szukane any) bool {
		for _, a := range w.args {
			if a == szukane {
				return true
			}
		}
		return false
	}
	var maClaim, maSpan bool
	for _, w := range wpisy {
		if strings.Contains(w.sql, "'claim'") {
			maClaim = true
			if !maArgument(w, claimHist.String()) {
				t.Errorf("brak adresu twierdzenia w argumentach: %v", w.args)
			}
		}
		if strings.Contains(w.sql, "'span'") {
			maSpan = true
			if !maArgument(w, "s0821:s07") {
				t.Errorf("brak adresu miedzysesyjnego spanu w argumentach: %v", w.args)
			}
		}
	}
	if !maClaim || !maSpan {
		t.Error("kontekst zapisany bez rozdzielenia poziomow claim/span")
	}

	// Liczniki: "czego nie pokazalismy" tez jest proweniencja.
	stats := db.doTabeli("report_run_context_stats")
	if len(stats) != 1 {
		t.Fatalf("liczniki kontekstu zapisane %d razy", len(stats))
	}
	// Liczniki tez sprawdzamy po tresci — kolumn w tej tabeli przybywa
	// (F7b-2 dolozyl trzy) i pozycje sie przesuwaja.
	liczniki := map[int]bool{}
	for _, a := range stats[0].args {
		if n, ok := a.(int); ok {
			liczniki[n] = true
		}
	}
	if !liczniki[1] || !liczniki[4] || !liczniki[9] {
		t.Errorf("liczniki (pominiete=1, przyciete twierdzenia=4, spany=9) "+
			"nie trafily do zapisu: %v", stats[0].args)
	}
}

// Potok jednosesyjny nie zapisuje NICZEGO do rejestru kontekstu — brak
// wiersza znaczy "nie bylo kontekstu", a nie "kontekst byl pusty".
func TestBezKontekstuBezWpisow(t *testing.T) {
	db := zapiszTestowo(t)
	if n := len(db.doTabeli("report_run_context")); n != 0 {
		t.Fatalf("przebieg bez kontekstu zapisal %d wpisow", n)
	}
	if n := len(db.doTabeli("report_run_context_stats")); n != 0 {
		t.Fatalf("przebieg bez kontekstu zapisal liczniki (%d)", n)
	}
}

// Kanarek F7a-5 (25.08): twierdzenie zbudowane na spanie z WCZESNIEJSZEJ
// sesji wywracalo Persist bledem „span spoza zapisanych", bo mapa spanow
// tego przebiegu zna wylacznie spany biezacej sesji. Skutek byl gorszy
// niz sam blad: Pub/Sub ponawial CALY przebieg co szesc minut, za kazdym
// razem zostawiajac kolejny raport tej samej sesji.
//
// Span historyczny ma juz swoj wiersz w report_spans — proweniencja ma
// wskazywac ORYGINAL, nie kopie.
func TestProweniencjaSpanuZWczesniejszejSesji(t *testing.T) {
	db := &fakeDB{}
	sesjaHist := uuid.New()
	res := wynikDoZapisu()
	res.Approved[0].Evidence = append(res.Approved[0].Evidence,
		ontology.QuoteRef{SpanID: "s0820:s42", Quote: "wtedy też o tym mówił"})

	err := Persist(context.Background(), db, fakeCrypto{}, PersistInput{
		ReportID: uuid.New(), SessionID: uuid.New(), TranscriptID: uuid.New(),
		Past: &PastContext{Spans: []PastSpan{{
			Addr: "s0820:s42", SessionID: sesjaHist, Quote: "wtedy też o tym mówił",
		}}},
	}, res)
	if err != nil {
		t.Fatalf("Persist odrzucil span historyczny: %v", err)
	}

	// Rozwiazanie MUSI isc do bazy po istniejacy wiersz tamtej sesji.
	var szukano bool
	for _, z := range db.zapisy {
		if strings.Contains(z.sql, "FROM report_spans") &&
			strings.Contains(z.sql, "span_ref") {
			szukano = true
			if z.args[0] != sesjaHist {
				t.Errorf("szukano w sesji %v, chcemy %v", z.args[0], sesjaHist)
			}
			if z.args[1] != "s42" {
				t.Errorf("szukano refa %v, chcemy s42 (bez prefiksu daty)", z.args[1])
			}
		}
	}
	if !szukano {
		t.Fatal("brak zapytania o istniejacy span historyczny")
	}
	// Dowod ma trafic do tabeli proweniencji jak kazdy inny.
	if n := len(db.doTabeli("report_claim_evidence")); n < 3 {
		t.Errorf("wpisow proweniencji %d, oczekiwano co najmniej 3", n)
	}
}

// Adres, ktorego w kontekscie NIE POKAZANO, zostaje bledem: to nie jest
// span historyczny, tylko wymyslony.
func TestNiepokazanyAdresHistorycznyToBlad(t *testing.T) {
	db := &fakeDB{}
	res := wynikDoZapisu()
	res.Approved[0].Evidence = append(res.Approved[0].Evidence,
		ontology.QuoteRef{SpanID: "s0101:s99", Quote: "nigdy tego nie było"})

	err := Persist(context.Background(), db, fakeCrypto{}, PersistInput{
		ReportID: uuid.New(), SessionID: uuid.New(), TranscriptID: uuid.New(),
		Past: &PastContext{Spans: []PastSpan{{Addr: "s0820:s42", SessionID: uuid.New()}}},
	}, res)
	if err == nil {
		t.Fatal("Persist przyjal odnosnik do spanu spoza pokazanego kontekstu")
	}
	if !strings.Contains(err.Error(), "s0101:s99") {
		t.Errorf("blad nie nazywa winnego odnosnika: %v", err)
	}
}

// Kanal i podobienstwo musza trafic do rejestru (F7b-2, dok. 65 §N2).
//
// Bez kanalu nie da sie odpowiedziec na pytanie, ktore zadaje strojenie:
// „co DOLOZYLA semantyka". Bez podobienstwa nie da sie odroznic „progu
// za wysokiego" od „braku materialu".
func TestRejestrKontekstuNiesieKanalIPodobienstwo(t *testing.T) {
	db := &fakeDB{}
	sesjaOkno, sesjaSem := uuid.New(), uuid.New()
	past := &PastContext{
		Claims: []PastClaim{
			{ID: uuid.New(), SessionID: sesjaOkno, ConstructID: "konflikt",
				Evidence: []string{"s0820:s01"}},
			{ID: uuid.New(), SessionID: sesjaSem, ConstructID: "zasob",
				Evidence: []string{"s0301:s09"},
				Channel:  "semantic", Similarity: 0.72},
		},
		Spans: []PastSpan{
			{Addr: "s0820:s01", SessionID: sesjaOkno},
			{Addr: "s0301:s09", SessionID: sesjaSem, Channel: "semantic"},
		},
		Stats: PastStats{
			WindowSize: 3, SessionsLoaded: 1,
			SemanticEnabled: true, SemanticFound: 1, SemanticBelowThreshold: 5,
		},
	}
	if err := Persist(context.Background(), db, fakeCrypto{}, PersistInput{
		ReportID: uuid.New(), SessionID: uuid.New(), TranscriptID: uuid.New(),
		Past: past,
	}, wynikDoZapisu()); err != nil {
		t.Fatalf("Persist: %v", err)
	}

	var okno, semantyka int
	var podobienstwoZapisane bool
	for _, z := range db.doTabeli("report_run_context") {
		for _, a := range z.args {
			switch v := a.(type) {
			case string:
				if v == "window" {
					okno++
				}
				if v == "semantic" {
					semantyka++
				}
			case float64:
				if v == 0.72 {
					podobienstwoZapisane = true
				}
			}
		}
	}
	if okno != 2 {
		t.Errorf("wpisow z kanalu okna = %d, chcemy 2", okno)
	}
	if semantyka != 2 {
		t.Errorf("wpisow z kanalu semantycznego = %d, chcemy 2", semantyka)
	}
	if !podobienstwoZapisane {
		t.Error("podobienstwo trafienia semantycznego nie trafilo do rejestru")
	}

	// Liczniki: „zero trafien" ma trzy rozne znaczenia i musza byc
	// rozroznialne po fakcie.
	stats := db.doTabeli("report_run_context_stats")
	if len(stats) != 1 {
		t.Fatalf("liczniki zapisane %d razy", len(stats))
	}
	if stats[0].args[8] != true {
		t.Errorf("flaga semantyki = %v, chcemy true", stats[0].args[8])
	}
	if stats[0].args[10] != 5 {
		t.Errorf("odrzuconych progiem = %v, chcemy 5", stats[0].args[10])
	}
}

// Wpis bez jawnego kanalu to OKNO — zgodnosc wsteczna dla wierszy
// sprzed F7b, gdy kanal byl jeden i nikt go nie zapisywal.
func TestBrakKanaluZnaczyOkno(t *testing.T) {
	if got := kanal(""); got != "window" {
		t.Errorf("kanal(\"\") = %q, chcemy window", got)
	}
	if got := kanal("semantic"); got != "semantic" {
		t.Errorf("kanal zmienil jawna wartosc na %q", got)
	}
}
