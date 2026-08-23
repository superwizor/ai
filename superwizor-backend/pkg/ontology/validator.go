package ontology

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
)

// Walidator dziedzinowy S3 (dok. 11, sekcja 4).
//
// DETERMINISTYCZNY, ZERO LLM. To jest cala jego wartosc: reguly, ktore
// pytaja model, czy wolno mu bylo cos powiedziec, dziedzicza jego
// zawodnosc. Tutaj kazde odrzucenie da sie odtworzyc i uzasadnic.
//
// Podzial pracy wzgledem schematu (schema.go): schemat pilnuje tego, co
// da sie wyrazic w JSON Schema — enum kategorii, obecnosc cytatu,
// zawezony status. Walidator pilnuje tego, czego nie da sie — progow
// dowodowych liczonych po spanach, zaleznosci miedzy konstruktami,
// zgodnosci liczby z jej zrodlem, granicy terapeuty.
//
// Reguly R4 (entailment) i R8 (relacje) NIE sa tutaj: pierwsza wymaga
// wywolania modelu, druga dotyczy etapu S2b. Ich nieobecnosc jest
// zamierzona i odnotowana, zeby nie wygladalo, ze R1-R10 jest kompletne.

// RejectReason to kod reguly, ktora odrzucila twierdzenie.
//
// Kody sa stabilne, bo trafiaja do telemetrii (dok. 11 sekcja 8.3:
// report_claim_rejected {rule}) i do progow przegladu — zmiana kodu
// zrywa ciaglosc pomiaru.
type RejectReason string

const (
	ReasonEnum         RejectReason = "R1_enum"
	ReasonCoverage     RejectReason = "R2_coverage"
	ReasonRequires     RejectReason = "R3_requires"
	ReasonEtiology     RejectReason = "R5_etiology"
	ReasonIsNot        RejectReason = "R6_is_not"
	ReasonNoFit        RejectReason = "R7_no_fit"
	ReasonQuantity     RejectReason = "R9_quantity"
	ReasonTherapist    RejectReason = "R10_therapist_boundary"
	ReasonUnknownSpan  RejectReason = "R2_unknown_span"
	ReasonRiskSpan     RejectReason = "T22_risk_span"
	ReasonForcedStatus RejectReason = "R1_forced_status"
)

// Rejection to jedno odrzucone twierdzenie z powodem.
type Rejection struct {
	ConstructID string
	Reason      RejectReason
	Detail      string
	// Claim to ODRZUCONA tresc.
	//
	// Do 2026-08-23 rejestr trzymal sam kod reguly i konstrukt, a
	// uzasadnienie przepadalo. Kanarek CBT pokazal, czym to jest w
	// praktyce: trzy twierdzenia odpadly na wartosci "2" bez pokrycia i
	// NIE DALO SIE ustalic, czy model sfabrykowal precyzje, czy odwolal
	// sie do numeracji wlasnego modelu ("ogniwo 2"). Dwie zupelnie rozne
	// diagnozy, ta sama linijka w rejestrze.
	//
	// Progi dowodowe i prompty stroi sie na przykladach, wiec przyklad
	// musi przetrwac. Nil dla odrzucen, ktore nie dotycza pojedynczego
	// twierdzenia (konstrukt spoza ontologii, degradacja `requires`).
	Claim *Claim
}

// Degradation to twierdzenie, ktoremu OBNIZONO range zamiast je usunac.
//
// R3 degraduje, NIGDY nie podnosi: konstrukt bez spelnionych zaleznosci
// renderuje sie jako fallback_rendering, a nie znika. Roznica jest
// kliniczna — "hipoteza robocza napiecia aktualnego" niesie informacje,
// pusty raport nie.
type Degradation struct {
	ConstructID string
	To          string // fallback_rendering z ontologii
	Detail      string
}

// ValidationResult to wynik S3 dla jednego przebiegu.
type ValidationResult struct {
	Approved []Claim
	Rejected []Rejection
	Degraded []Degradation
	// NoFitConstructs zasila rejestr luk ontologii (dok. 11 sekcja 8.3:
	// prog przegladu 10% kwartalnie -> przeglad ekspercki).
	NoFitConstructs []string
	// InsufficientData to konstrukty, dla ktorych zabraklo danych.
	// Pole raportu renderuje sie wtedy jako zaproszenie, nie jako blad.
	InsufficientData []string
}

// ValidateOptions niesie kontekst potrzebny regulom.
type ValidateOptions struct {
	// Spans to wszystkie spany z S1, po ID. Twierdzenie wskazujace span
	// spoza tego zbioru jest odrzucane (nie ma czego weryfikowac).
	Spans map[string]Span
	// ApprovedConstructs to konstrukty juz zatwierdzone w tym przebiegu.
	// R3 sprawdza wzgledem nich `requires`. Wolajacy przekazuje wyniki
	// wczesniejszych etapow, bo kolejnosc walidacji konstruktow jest
	// jego decyzja.
	ApprovedConstructs map[string]bool
}

// Validate stosuje reguly R1-R10 do wyniku jednego etapu S2.
func (o *Ontology) Validate3(res StageResult, opts ValidateOptions) ValidationResult {
	out := ValidationResult{}
	c := o.Constructs[res.ConstructID]
	if c == nil {
		out.Rejected = append(out.Rejected, Rejection{
			ConstructID: res.ConstructID, Reason: ReasonEnum,
			Detail: "konstrukt spoza ontologii",
		})
		return out
	}

	// R7: no_fit przechodzi do S4 jako obserwacja BEZ kategorii i nigdy
	// nie jest mapowany wstecznie na najblizsza kategorie. Licznik
	// zasila rejestr luk — wysoki odsetek to sygnal dla ekspertow, ze
	// taksonomia czegos nie obejmuje, a nie ze model sie myli.
	if res.NoFit {
		out.NoFitConstructs = append(out.NoFitConstructs, res.ConstructID)
		for _, cl := range res.Claims {
			if len(cl.Categories) > 0 {
				odrzucone := cl
				out.Rejected = append(out.Rejected, Rejection{
					ConstructID: res.ConstructID, Reason: ReasonNoFit,
					Detail: "no_fit z jednoczesna kategoria — zjawisko poza taksonomia " +
						"nie moze dostac etykiety z listy",
					Claim: &odrzucone,
				})
			}
		}
		return out
	}
	if res.InsufficientData {
		out.InsufficientData = append(out.InsufficientData, res.ConstructID)
		return out
	}

	// R3: zaleznosci twarde. Sprawdzane RAZ dla calego konstruktu, bo
	// `requires` opisuje warunek istnienia konstruktu, nie pojedynczego
	// twierdzenia.
	if missing := missingRequires(c, opts.ApprovedConstructs); len(missing) > 0 {
		out.Degraded = append(out.Degraded, Degradation{
			ConstructID: res.ConstructID,
			To:          c.FallbackRendering,
			Detail:      fmt.Sprintf("niespelnione requires: %s", strings.Join(missing, ", ")),
		})
		return out
	}

	for _, cl := range res.Claims {
		if rej, bad := o.checkClaim(c, cl, opts); bad {
			out.Rejected = append(out.Rejected, rej)
			continue
		}
		out.Approved = append(out.Approved, cl)
	}
	return out
}

// checkClaim stosuje reguly per twierdzenie. Zwraca pierwsze naruszenie —
// odrzucenie jest binarne, wiec dalsze sprawdzanie nie zmienia wyniku,
// a pierwszy powod jest tym, ktory autor promptu ma naprawic.
func (o *Ontology) checkClaim(c *Construct, cl Claim, opts ValidateOptions) (Rejection, bool) {
	rej := func(r RejectReason, format string, a ...any) (Rejection, bool) {
		// Kopia, nie wskaznik na parametr petli: wolajacy trzyma te
		// strukture dluzej niz trwa iteracja.
		odrzucone := cl
		return Rejection{ConstructID: cl.ConstructID, Reason: r,
			Detail: fmt.Sprintf(format, a...), Claim: &odrzucone}, true
	}

	// R10: GRANICA TERAPEUTY. Pierwsza, bo jest bezwarunkowa — zadne
	// pokrycie dowodowe nie czyni inferencji o stanie wewnetrznym
	// terapeuty dopuszczalna. Wypowiedzi terapeuty pozostaja legalnymi
	// DOWODAMI (observed_by: therapist o kliencie); zakaz dotyczy
	// twierdzen, ktorych PODMIOTEM jest terapeuta.
	if cl.SubjectIsTherapist {
		return rej(ReasonTherapist,
			"twierdzenie o stanie wewnetrznym terapeuty — dopuszczalne wylacznie "+
				"jako entry_ref jego autorstwa")
	}

	// R1: kategoria z katalogu. Schemat juz tego pilnuje enumem; to
	// drugi bezpiecznik na wypadek sciezki omijajacej structured output.
	if len(c.Values) > 0 {
		if len(cl.Categories) == 0 {
			return rej(ReasonEnum, "brak kategorii przy konstrukcie z katalogiem zamknietym")
		}
		if !c.MultiLabel && len(cl.Categories) > 1 {
			return rej(ReasonEnum, "wiele kategorii przy konstrukcie single-label")
		}
		for _, cat := range cl.Categories {
			if !containsStr(c.Values, cat) {
				return rej(ReasonEnum, "kategoria %q spoza katalogu", cat)
			}
			// R6: kategoria z rejestru antywzorcow. Zywy rejestr bledow
			// zasilany feedbackiem — "spokoj" jako potencjalnosc trafia
			// tutaj, nie do enumu.
			for _, cc := range c.CommonConfusions {
				if strings.EqualFold(cc.Input, cat) {
					return rej(ReasonIsNot, "kategoria %q figuruje w common_confusions: %s",
						cat, cc.Correct)
				}
			}
		}
	}

	// forced_status: status wymuszony przez ontologie.
	if c.ForcedStatus != "" && cl.Status != c.ForcedStatus {
		return rej(ReasonForcedStatus, "status %q, ontologia wymusza %q",
			cl.Status, c.ForcedStatus)
	}

	// R2: pokrycie dowodowe. Liczone po SPANACH, nie po cytatach: dwa
	// cytaty z jednego spanu to jeden dowod, a nie dwa.
	spanIDs := map[string]bool{}
	for _, q := range cl.Evidence {
		s, ok := opts.Spans[q.SpanID]
		if !ok {
			return rej(ReasonUnknownSpan, "cytat wskazuje nieznany span %q", q.SpanID)
		}
		// T22: spany ryzyka nie zasilaja wnioskowania. Twarde, w kodzie,
		// nie w prompcie — automatyczna ocena ryzyka to klasa IIb i
		// pozostaje poza zakresem produktu.
		if s.RiskContent {
			return rej(ReasonRiskSpan, "twierdzenie oparte na spanie z trescia ryzyka")
		}
		spanIDs[q.SpanID] = true
	}
	if me := c.MinEvidence; me != nil {
		if len(spanIDs) < me.Spans {
			return rej(ReasonCoverage, "spanow %d, wymagane %d", len(spanIDs), me.Spans)
		}
		if me.Behavioral != nil && *me.Behavioral > 0 {
			n := 0
			for id := range spanIDs {
				if opts.Spans[id].Kind == SpanBehavioral {
					n++
				}
			}
			if n < *me.Behavioral {
				return rej(ReasonCoverage, "spanow behawioralnych %d, wymagane %d",
					n, *me.Behavioral)
			}
		}
		if me.Sessions != nil && *me.Sessions > 0 {
			sessions := map[string]bool{}
			for id := range spanIDs {
				sessions[opts.Spans[id].SessionID] = true
			}
			if len(sessions) < *me.Sessions {
				return rej(ReasonCoverage, "sesji %d, wymagane %d",
					len(sessions), *me.Sessions)
			}
		}
	}

	// R5: ETIOLOGIA. Twierdzenie genetyczne wymaga spanu mowiacego
	// WPROST o przeszlosci. To jest reguła, ktora likwiduje objaw 5
	// (konfabulacja "mikrotraumy", "supermatki"): koszt dopowiedzenia
	// przestaje byc zerowy, bo dopowiedzenie nie ma czym sie podeprzec.
	if cl.Etiological && o.EtiologyPolicy == "strict" {
		maPrzeszlosc := false
		for id := range spanIDs {
			if opts.Spans[id].AboutPast {
				maPrzeszlosc = true
				break
			}
		}
		if !maPrzeszlosc {
			return rej(ReasonEtiology,
				"twierdzenie etiologiczne bez spanu mowiacego wprost o przeszlosci")
		}
	}

	// R9: KWANTYFIKACJA. Liczba dopuszczalna wylacznie ze spanem, w
	// ktorym padla — fabrykowana precyzja jest konfabulacja o wiekszej
	// siLe przekonywania niz proza, bo wyglada na pomiar.
	for _, q := range cl.Quantities {
		if q.FromEntry {
			continue // klient wpisal sam — stated_only z definicji
		}
		s, ok := opts.Spans[q.SpanID]
		if !ok {
			return rej(ReasonQuantity, "wartosc %q bez wskazanego spanu", q.Raw)
		}
		if !quantityAppears(s.QuoteVerbatim, q.Raw) {
			return rej(ReasonQuantity, "wartosc %q nie wystepuje w spanie %s",
				q.Raw, q.SpanID)
		}
	}

	return Rejection{}, false
}

// missingRequires zwraca niespelnione zaleznosci konstruktu.
func missingRequires(c *Construct, approved map[string]bool) []string {
	var missing []string
	for _, r := range c.Requires {
		if !approved[r] {
			missing = append(missing, r)
		}
	}
	sort.Strings(missing)
	return missing
}

// digitsRe wyciaga same cyfry, zeby porownanie nie zalezalo od zapisu
// ("80%" vs "80 %", "7/10" vs "7 / 10").
var digitsRe = regexp.MustCompile(`\d+`)

// quantityAppears sprawdza, czy liczba z twierdzenia pada w spanie.
//
// Porownanie po cyfrach, nie po calym zapisie: model czesto normalizuje
// forme ("80 procent" -> "80%"), a to jest zmiana zapisu, nie fabrykacja.
// Fabrykacja to LICZBA, ktorej w zrodle nie ma — i to lapiemy.
func quantityAppears(source, raw string) bool {
	want := digitsRe.FindAllString(raw, -1)
	if len(want) == 0 {
		return false
	}
	have := digitsRe.FindAllString(source, -1)
	for _, w := range want {
		found := false
		for _, h := range have {
			if h == w {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

func containsStr(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}
