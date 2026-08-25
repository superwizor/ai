package ontopipe

import (
	"fmt"
	"sort"
	"time"

	"github.com/google/uuid"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// Kontekst miedzysesyjny — wejscie S0 (plan F7a, dok. 65).
//
// ══ Co tu jest, a czego nie ma ══
//
// Sa: ZATWIERDZONE twierdzenia poprzednich sesji i spany, ktore je
// uziemiaja. Kazdy taki span przeszedl weryfikacje mechaniczna S1 w
// swoim czasie, wiec proweniencja przezywa przeniesienie miedzy
// sesjami — dlatego wnioskowanie podluzne nie lamie fundamentu
// architektury.
//
// Nie ma: prozy raportow (hipotez S4). To jest niezmiennik N1 dokumentu
// 65 — przeszla hipoteza NIGDY nie jest dowodem. Wpuszczenie jej tutaj
// zamienialoby powtorzenie wlasnej interpretacji w uzasadnienie, czyli
// automatyzowaloby konfirmacje. Kanal ciaglosci dla hipotez powstaje
// osobno w F7b, z wlasnym sufitem statusu i wlasna regula weryfikatora.
//
// Nie ma tez uzasadnien twierdzen (reasoning z S2): to proza modelu,
// a do ustalenia ciaglosci wystarcza konstrukt, kategorie i CYTAT.

// PastSpan to jednostka dowodowa z wczesniejszej sesji.
type PastSpan struct {
	// Addr to adres uzywany w promptach i w rejestrze proweniencji:
	// `s{MMDD}:{span_ref}`, np. `s0821:s07`. Lokalny `span_ref` jest
	// unikalny tylko w obrebie transkrypcji, wiec bez daty dwa spany z
	// roznych sesji mialyby ten sam adres i S2 nie wiedzialby, ktory
	// cytuje.
	Addr        string
	SessionID   uuid.UUID
	SessionDate time.Time
	Quote       string
	Speaker     string
	Kind        ontology.SpanKind
	ObservedBy  ontology.ObservedBy
	// AboutPast decyduje o dopuszczalnosci twierdzen etiologicznych
	// (R5) dokladnie tak samo jak dla spanow biezacej sesji.
	AboutPast bool
	Topics    []string
	// Channel jak w PastClaim: span wchodzi tym samym kanalem co
	// twierdzenie, ktore go przywiodlo.
	Channel string
}

// PastClaim to zatwierdzone twierdzenie z wczesniejszej sesji.
type PastClaim struct {
	ID          uuid.UUID
	SessionID   uuid.UUID
	SessionDate time.Time
	ConstructID string
	Categories  []string
	Status      ontology.EpistemicStatus
	Confidence  float64
	// Evidence to adresy spanow (PastSpan.Addr), nie ich tresc —
	// tresc jest w PastContext.Spans, zeby ten sam cytat nie
	// powtarzal sie w prompcie przy kilku twierdzeniach.
	Evidence []string
	// Channel mowi, SKAD to ustalenie sie wzielo: "window" (okno
	// deterministyczne, F7a) albo "semantic" (indeks, F7b).
	// Pusty = window, dla zgodnosci wstecznej.
	Channel string
	// Similarity to podobienstwo kosinusowe wobec zapytania. Ma sens
	// WYLACZNIE dla kanalu semantycznego; dla okna zostaje zerem, bo
	// tam selekcja nie ma miary i udawanie, ze ma, myli przy strojeniu.
	Similarity float64
}

// PastSessionTopics to hasla jednej wczesniejszej sesji.
//
// Rekurencja miedzysesyjna (S1.5) pyta, w ILU SESJACH wystapilo haslo,
// a nie ile razy lacznie — temat powtorzony piec razy w jednej sesji
// jest watkiem rozmowy, w trzech sesjach jest wzorcem.
type PastSessionTopics struct {
	SessionID   uuid.UUID
	SessionDate time.Time
	Topics      []string
}

// PastStats mowi, co zostalo zaladowane i CZEGO NIE POKAZANO.
//
// Drugie jest wazniejsze: bez licznikow przyciecia „model tego nie
// polaczyl" byloby nierozroznialne od „model tego nie zobaczyl".
type PastStats struct {
	WindowSize                int
	SessionsLoaded            int
	SessionsSkippedUnfinished int
	ClaimsShown               int
	ClaimsDropped             int
	SpansShown                int
	SpansDropped              int
	// SemanticEnabled odroznia „flaga wylaczona" od „nic nie
	// znaleziono". Bez tego zero trafien semantycznych bylo by
	// nieodroznialne od niewlaczonego wyszukiwania.
	SemanticEnabled bool
	SemanticFound   int
	// SemanticBelowThreshold to sasiedzi odrzuceni progiem. Liczba jest
	// materialem do kalibracji (F7b-4): duzo odrzuconych przy zerze
	// przyjetych znaczy „prog za wysoki", a nie „brak historii".
	SemanticBelowThreshold int
}

// PastContext to komplet kontekstu miedzysesyjnego jednego przebiegu.
//
// Wskaznik nil = potok jednosesyjny (zachowanie sprzed F7a). Kod
// konsumujacy musi to znosic, bo tryb bez kontekstu zostaje na stale:
// pierwsza sesja kartoteki nie ma przeszlosci.
type PastContext struct {
	Claims        []PastClaim
	Spans         []PastSpan
	SessionTopics []PastSessionTopics
	Stats         PastStats
}

// SpanAddr sklada adres miedzysesyjny spanu.
func SpanAddr(sessionDate time.Time, spanRef string) string {
	return fmt.Sprintf("s%02d%02d:%s", sessionDate.Month(), sessionDate.Day(), spanRef)
}

// SpanByAddr znajduje span po adresie. Uzywane przez walidacje
// odnosnikow (V1 w F7a-3): odnosnik spoza pokazanego kontekstu jest
// naruszeniem, nie literowka do naprawienia.
func (p *PastContext) SpanByAddr(addr string) (PastSpan, bool) {
	if p == nil {
		return PastSpan{}, false
	}
	for _, s := range p.Spans {
		if s.Addr == addr {
			return s, true
		}
	}
	return PastSpan{}, false
}

// ClaimsForConstruct zwraca twierdzenia jednego konstruktu, najnowsze
// pierwsze. S2 dostaje ustalenia WLASNEGO konstruktu — mieszanie
// poziomow pojeciowych w jednym prompcie produkuje objaw 2 (potrzeba =
// zasob = potencjalnosc w jednym worku), dokladnie ten sam powod, dla
// ktorego S2 jest wolane osobno na konstrukt.
func (p *PastContext) ClaimsForConstruct(constructID string) []PastClaim {
	if p == nil {
		return nil
	}
	var out []PastClaim
	for _, c := range p.Claims {
		if c.ConstructID == constructID {
			out = append(out, c)
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		return out[i].SessionDate.After(out[j].SessionDate)
	})
	return out
}

// SpansForConstruct zwraca spany, ktore uziemialy DANY konstrukt
// w poprzednich sesjach.
//
// Zawezenie do konstruktu jest decyzja projektowa, nie oszczednoscia:
// S2 jest wolane osobno na konstrukt wlasnie po to, zeby nie mieszac
// poziomow pojeciowych. Pokazanie wszystkich spanow historycznych
// kazdemu konstruktowi cofneloby ten rozdzial — i przy okazji
// mnozyloby koszt przez liczbe konstruktow ontologii.
func (p *PastContext) SpansForConstruct(constructID string) []PastSpan {
	if p == nil {
		return nil
	}
	chciane := map[string]bool{}
	for _, c := range p.Claims {
		if c.ConstructID != constructID {
			continue
		}
		for _, addr := range c.Evidence {
			chciane[addr] = true
		}
	}
	if len(chciane) == 0 {
		return nil
	}
	var out []PastSpan
	for _, s := range p.Spans {
		if chciane[s.Addr] {
			out = append(out, s)
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		if !out[i].SessionDate.Equal(out[j].SessionDate) {
			return out[i].SessionDate.After(out[j].SessionDate)
		}
		return out[i].Addr < out[j].Addr
	})
	return out
}

// TopicSessionCounts liczy, w ilu WCZESNIEJSZYCH sesjach wystapilo
// kazde haslo. Wejscie rekurencji miedzysesyjnej (S1.5, F7a-3).
func (p *PastContext) TopicSessionCounts() map[string]int {
	out := map[string]int{}
	if p == nil {
		return out
	}
	for _, st := range p.SessionTopics {
		widziane := map[string]bool{}
		for _, t := range st.Topics {
			if t == "" || widziane[t] {
				continue
			}
			widziane[t] = true
			out[t]++
		}
	}
	return out
}

// SessionCount to liczba wczesniejszych sesji, ktore weszly do kontekstu.
func (p *PastContext) SessionCount() int {
	if p == nil {
		return 0
	}
	return p.Stats.SessionsLoaded
}
