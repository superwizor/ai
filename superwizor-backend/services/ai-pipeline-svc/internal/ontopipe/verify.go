package ontopipe

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// ── S5: weryfikator wyjscia (dok. 11 sekcja 4, reguly V1-V6) ──
//
// S3 pilnuje, czy twierdzenie mialo prawo powstac. S5 pilnuje, czy PROZA
// mowi to samo, co twierdzenie. To sa dwa rozne bledy: walidator
// dziedzinowy przepusci poprawne twierdzenie, ktore synteza potem
// przekrecí — status podniesiony do obserwacji, liczba dopisana "dla
// obrazu", kategoria z sasiedniego konstruktu wpleciona w zdanie.
//
// Weryfikator jest deterministyczny. Naruszenie nie jest opinia, tylko
// faktem, ktory da sie pokazac autorowi ontologii.

// VRule to kod reguly wyjscia. Kody sa stabilne — ida do telemetrii.
type VRule string

const (
	VRuleReference VRule = "V1_odnosnik"
	VRuleForeign   VRule = "V2_termin_obcy"
	VRuleEtiology  VRule = "V3_etiologia"
	VRuleHierarchy VRule = "V4_hierarchia"
	VRuleMarker    VRule = "V5_marker_abdukcyjny"
	VRuleQuantity  VRule = "V6_liczba_bez_pokrycia"
)

// Violation to jedno naruszenie. Detail trafia z powrotem do S4 przy
// regeneracji, wiec musi byc na tyle konkretny, zeby dalo sie na jego
// podstawie poprawic zdanie — "narusza V2" nie wystarczy.
type Violation struct {
	Rule         VRule
	ConstructID  string
	HypothesisID string
	Detail       string
}

func (v Violation) String() string {
	return fmt.Sprintf("%s [%s/%s]: %s", v.Rule, v.ConstructID, v.HypothesisID, v.Detail)
}

// Verify stosuje V1-V6 do wyniku S4.
//
// Spany sa OSOBNYM parametrem, nie polem SynthesisInput. Roznica jest
// zasadnicza: weryfikator to kod Go i moze widziec wszystko, natomiast
// S4 ma widziec wylacznie zatwierdzone byty. Wsuniecie mapy spanow do
// SynthesisInput dalo by modelowi dostep takze do spanow, ktorych zaden
// zatwierdzony claim nie uzyl — czyli material do dopowiedzenia.
//
// CZEGO TU NIE MA: czesc V5 dotyczaca relacji i cykli (approved_relations,
// approved_cycles). Etapy S2b/S2c nie sa jeszcze zaimplementowane, wiec
// nie ma czego porownywac. Nieobecnosc jest jawna, zeby V1-V6 nie
// wygladalo na komplet.
func Verify(o *ontology.Ontology, rep Report, in SynthesisInput, spans map[string]ontology.Span) []Violation {
	var out []Violation

	allowedSpans := map[string]bool{}
	for _, id := range allowedSpanIDs(in) {
		allowedSpans[id] = true
	}
	allowedConstructs := map[string]bool{}
	for _, id := range allowedConstructIDs(in) {
		allowedConstructs[id] = true
	}

	claimsByConstruct := map[string][]ontology.Claim{}
	for _, c := range in.Claims {
		claimsByConstruct[c.ConstructID] = append(claimsByConstruct[c.ConstructID], c)
	}

	for _, cr := range rep.Constructs {
		// V4a: konstrukt spoza przebiegu jest wymyslony.
		if !allowedConstructs[cr.ConstructID] {
			out = append(out, Violation{
				Rule: VRuleHierarchy, ConstructID: cr.ConstructID,
				Detail: "konstrukt nie wystapil w zatwierdzonych wynikach tego przebiegu",
			})
			continue
		}
		approved := claimsByConstruct[cr.ConstructID]

		// V4b: liczba hipotez nie moze przekroczyc liczby zatwierdzonych
		// twierdzen. Synteza rozwija jezyk, nie mnozy bytow.
		if len(cr.Hypotheses) > len(approved) {
			out = append(out, Violation{
				Rule: VRuleHierarchy, ConstructID: cr.ConstructID,
				Detail: fmt.Sprintf("%d hipotez przy %d zatwierdzonych twierdzeniach — "+
					"synteza nie tworzy nowych bytow", len(cr.Hypotheses), len(approved)),
			})
		}

		foreign := foreignTerms(o, cr.ConstructID, approved)

		for _, h := range cr.Hypotheses {
			out = append(out, verifyHypothesis(o, cr, h, approved, allowedSpans, spans, foreign)...)
		}

		// V5b: meta-obserwacja bez policzonego wzorca jest dopowiedzeniem
		// przebranym za pomiar. To najgrozniejszy rodzaj konfabulacji,
		// bo liczba przekonuje mocniej niz proza.
		out = append(out, verifyPatternNotices(cr, in.Patterns)...)
	}
	return out
}

func verifyHypothesis(o *ontology.Ontology, cr ConstructReport, h Hypothesis,
	approved []ontology.Claim, allowedSpans map[string]bool,
	spans map[string]ontology.Span, foreign []string) []Violation {

	var out []Violation

	// ── V1: kazde zdanie wnioskujace ma odnosnik i status ──
	if len(h.Supporting) == 0 {
		out = append(out, Violation{
			Rule: VRuleReference, ConstructID: cr.ConstructID, HypothesisID: h.ID,
			Detail: "hipoteza bez ani jednego spanu w supporting",
		})
	}
	if strings.TrimSpace(h.EpistemicStatus) == "" {
		out = append(out, Violation{
			Rule: VRuleReference, ConstructID: cr.ConstructID, HypothesisID: h.ID,
			Detail: "hipoteza bez statusu epistemicznego",
		})
	}
	for _, id := range append(append([]string{}, h.Supporting...), h.Contradicting...) {
		if !allowedSpans[id] {
			out = append(out, Violation{
				Rule: VRuleReference, ConstructID: cr.ConstructID, HypothesisID: h.ID,
				Detail: fmt.Sprintf("odnosnik do spanu %q, ktory nie niesie zadnego "+
					"zatwierdzonego twierdzenia", id),
			})
		}
	}

	// ── V2: terminy kategorii spoza ontologii w trybie oznajmujacym ──
	if t := firstTermPresent(h.Claim, foreign); t != "" {
		out = append(out, Violation{
			Rule: VRuleForeign, ConstructID: cr.ConstructID, HypothesisID: h.ID,
			Detail: fmt.Sprintf("proza uzywa terminu %q, ktory nie zostal zatwierdzony "+
				"dla tego konstruktu", t),
		})
	}

	// ── V3: etiologia bez proweniencji ──
	if marker := firstTermPresent(h.Claim, etiologyMarkers); marker != "" {
		if !anySpanAboutPast(h.Supporting, spans) {
			out = append(out, Violation{
				Rule: VRuleEtiology, ConstructID: cr.ConstructID, HypothesisID: h.ID,
				Detail: fmt.Sprintf("zdanie o genezie (%q) bez ani jednego spanu "+
					"mowiacego wprost o przeszlosci", marker),
			})
		}
	}

	// ── V4c: status nie moze byc mocniejszy niz w zrodle ──
	src, ok := groundingClaim(h, approved)
	switch {
	case !ok:
		out = append(out, Violation{
			Rule: VRuleHierarchy, ConstructID: cr.ConstructID, HypothesisID: h.ID,
			Detail: "zaden zatwierdzony claim tego konstruktu nie dzieli spanu " +
				"z ta hipoteza — nie ma na czym jej oprzec",
		})
	case assertiveness(ontology.EpistemicStatus(h.EpistemicStatus)) > assertiveness(src.Status):
		out = append(out, Violation{
			Rule: VRuleHierarchy, ConstructID: cr.ConstructID, HypothesisID: h.ID,
			Detail: fmt.Sprintf("status podniesiony: zrodlo ma %s, raport pisze %s",
				src.Status, h.EpistemicStatus),
		})
	}

	// ── V5a: marker abdukcyjny przy hipotezie teoretycznej ──
	if h.EpistemicStatus == string(ontology.StatusTheoreticalHypothesis) &&
		firstTermPresent(h.Claim, abductiveMarkers) == "" {
		out = append(out, Violation{
			Rule: VRuleMarker, ConstructID: cr.ConstructID, HypothesisID: h.ID,
			Detail: "hipoteza teoretyczna bez jezyka modalnego — zdanie czyta sie " +
				"jak rozstrzygniecie",
		})
	}

	// ── V6: liczba w prozie bez pokrycia (lustro R9) ──
	for _, n := range numbersIn(h.Claim) {
		if !numberCovered(n, approved) {
			out = append(out, Violation{
				Rule: VRuleQuantity, ConstructID: cr.ConstructID, HypothesisID: h.ID,
				Detail: fmt.Sprintf("wartosc %q nie wystepuje w zadnym zatwierdzonym "+
					"twierdzeniu ani jego cytacie", n),
			})
		}
	}
	return out
}

// verifyPatternNotices sprawdza, czy meta-obserwacja ma za soba
// policzony wzorzec.
func verifyPatternNotices(cr ConstructReport, patterns []ontology.Pattern) []Violation {
	var out []Violation
	if len(cr.PatternNotices) == 0 {
		return nil
	}
	if len(patterns) == 0 {
		for range cr.PatternNotices {
			out = append(out, Violation{
				Rule: VRuleMarker, ConstructID: cr.ConstructID,
				Detail: "wzmianka o wzorcu, choc S1.5 nie policzyl zadnego",
			})
		}
		return out
	}
	var topics []string
	for _, p := range patterns {
		topics = append(topics, p.Topics...)
	}
	for _, n := range cr.PatternNotices {
		if firstTermPresent(n, topics) == "" {
			out = append(out, Violation{
				Rule: VRuleMarker, ConstructID: cr.ConstructID,
				Detail: fmt.Sprintf("wzmianka %q nie odpowiada tematowi zadnego "+
					"policzonego wzorca", trunc(n, 60)),
			})
		}
	}
	return out
}

// groundingClaim znajduje twierdzenie, na ktorym opiera sie hipoteza:
// to z najwiekszym pokryciem spanow. Wiazanie idzie po spanach, a nie po
// kolejnosci, bo S4 wolno laczyc i przestawiac.
func groundingClaim(h Hypothesis, approved []ontology.Claim) (ontology.Claim, bool) {
	best, bestScore := ontology.Claim{}, 0
	for _, c := range approved {
		ids := map[string]bool{}
		for _, q := range c.Evidence {
			ids[q.SpanID] = true
		}
		for _, q := range c.CounterEvidence {
			ids[q.SpanID] = true
		}
		score := 0
		for _, s := range h.Supporting {
			if ids[s] {
				score++
			}
		}
		if score > bestScore {
			best, bestScore = c, score
		}
	}
	return best, bestScore > 0
}

// assertiveness porzadkuje statusy wg SILY ZOBOWIAZANIA DO FAKTU.
//
// Obserwacja zobowiazuje najmocniej ("widac wprost"), pytanie otwarte
// wcale. Raport moze osłabić twierdzenie, nigdy je wzmocnic — dokladnie
// tak jak R3 degraduje i nigdy nie podnosi.
func assertiveness(s ontology.EpistemicStatus) int {
	switch s {
	case ontology.StatusObservation:
		return 3
	case ontology.StatusInterpretation:
		return 2
	case ontology.StatusTheoreticalHypothesis:
		return 1
	default:
		return 0
	}
}

func anySpanAboutPast(ids []string, spans map[string]ontology.Span) bool {
	for _, id := range ids {
		if s, ok := spans[id]; ok && s.AboutPast {
			return true
		}
	}
	return false
}

// foreignTerms zbiera terminy taksonomii, ktorych ta proza uzyc NIE MOZE:
// wszystkie kategorie i etykiety ontologii poza tymi zatwierdzonymi dla
// tego konstruktu, plus granice `is_not` i wpisy rejestru pomylek.
//
// UWAGA co do zakresu: to wykrywa termin ONTOLOGII uzyty nie tam, gdzie
// trzeba. Terminu spoza slownika ontologii (np. nazwy mechanizmu z innej
// szkoly) ta regula nie zlapie — na to jest przeglad ekspercki i licznik
// no_fit. Wykrywalny podzbior jest jednak tym, ktory faktycznie sie
// zdarza: model siega po sasiednia kategorie z tej samej listy.
func foreignTerms(o *ontology.Ontology, constructID string, approved []ontology.Claim) []string {
	ok := map[string]bool{}
	for _, c := range approved {
		for _, cat := range c.Categories {
			ok[strings.ToLower(cat)] = true
		}
	}
	if c := o.Constructs[constructID]; c != nil {
		ok[strings.ToLower(c.LabelPL)] = true
		for _, a := range c.Aliases {
			ok[strings.ToLower(a)] = true
		}
	}

	seen := map[string]bool{}
	var out []string
	add := func(t string) {
		lt := strings.ToLower(strings.TrimSpace(t))
		if lt == "" || ok[lt] || seen[lt] {
			return
		}
		seen[lt] = true
		out = append(out, lt)
	}

	// WYLACZNIE wlasny konstrukt. Do 2026-08-23 regula porownywala proze z
	// wartosciami CALEJ ontologii i przez to blokowala raporty za zwykly
	// jezyk: kanarek PPT odpadl, bo w akapicie o formie przetwarzania
	// konfliktu padlo slowo "nadzieja" (wartosc potencjalnosci pierwotnej),
	// a w akapicie o potencjalnosci — "deficyt" (wartosc stanu). Oba sa
	// najzwyklejszymi polskimi slowami i oba padly zgodnie z sensem.
	//
	// Ryzyko, ktore ta regula ma lapac, jest wezsze i bylo nazwane juz w
	// pierwszej wersji: model siega po sasiednia kategorie Z TEJ SAMEJ
	// LISTY — pisze "unikanie", gdy zatwierdzono "zaleznosc". Slownik
	// innych konstruktow to legalne slownictwo raportu, nie przemyt
	// kategorii.
	c := o.Constructs[constructID]
	if c == nil {
		return nil
	}
	for _, v := range c.Values {
		add(v)
	}
	for _, v := range c.IsNot {
		add(v)
	}
	for _, cf := range c.CommonConfusions {
		add(cf.Input)
	}

	// Termin ZAWARTY w zatwierdzonej kategorii nie jest przemytem.
	//
	// PPT ma kategorie zlozone ("otwartość/szczerość"), a rejestr pomylek
	// notuje ich polowki jako warianty nazwy. Bez tego odsiewu raport,
	// ktory poprawnie napisal ZATWIERDZONA kategorie, wypadal na V2 za
	// slowo, ktore sam w niej zawiera — i szedl w tryb ekstraktywny za
	// roznice kosmetyczna (kanarek PPT 2026-08-23).
	//
	// To osobny przebieg, nie warunek w `add`: kategorie moga dojsc w
	// dowolnej kolejnosci wzgledem terminow, ktore w sobie zawieraja.
	filtered := out[:0]
	for _, t := range out {
		if zawartyWZatwierdzonej(t, ok) {
			continue
		}
		filtered = append(filtered, t)
	}
	return filtered
}

// zawartyWZatwierdzonej mowi, czy termin jest fragmentem ktorejs z
// zatwierdzonych kategorii.
func zawartyWZatwierdzonej(term string, approved map[string]bool) bool {
	for cat := range approved {
		if cat != term && strings.Contains(cat, term) {
			return true
		}
	}
	return false
}

var etiologyMarkers = []string{
	"w dziecinstwie", "w dzieciństwie", "z dziecinstwa", "z dzieciństwa",
	"od dziecka", "w domu rodzinnym", "rodzina pochodzenia", "wczesne doswiadczenia",
	"wczesne doświadczenia", "ukształtowa", "uksztaltowa", "wyniosl", "wyniosł",
	"wyniosla", "wyniosła", "ma korzenie", "sięga korzeniami", "siega korzeniami",
	"jako dziecko", "u zrodel", "u źródeł",
}

var abductiveMarkers = []string{
	"mozliwe", "możliwe", "byc moze", "być może", "hipoteza", "przypuszcz",
	"wydaje sie", "wydaje się", "moglaby", "mogłaby", "moglby", "mógłby",
	"jednym z mozliwych", "jednym z możliwych", "jedna z mozliwych",
	"jedną z możliwych", "prawdopodobnie", "nie mozna wykluczyc",
	"nie można wykluczyć",
}

var numRe = regexp.MustCompile(`\d+(?:[.,]\d+)?%?`)

// ProseNumbers wyciaga z tekstu WARTOSCI LICZBOWE, pomijajac cyfry
// nalezace do identyfikatorow spanow.
//
// "s08" to odnosnik, nie liczba osiem. Do 2026-08-23 R9 tego nie
// rozrozniala i na kanarku PPT odrzucila SIEDEM poprawnych twierdzen,
// bo ich uzasadnienia powolywaly sie na spany po numerze ("wynika ze
// spanu s40"). Regula, ktora miala chronic przed fabrykowana precyzja,
// kasowala dokladnie te twierdzenia, ktore najstaranniej wskazywaly
// zrodlo.
func ProseNumbers(s string) []string {
	var out []string
	for _, m := range numRe.FindAllStringIndex(s, -1) {
		if m[0] > 0 && isASCIILetter(s[m[0]-1]) {
			continue // przylepione do litery: s08, chunk3, v1
		}
		out = append(out, s[m[0]:m[1]])
	}
	return out
}

func isASCIILetter(b byte) bool {
	return (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z')
}

// wordNumbers to liczebniki, ktore niosa TWIERDZENIE ILOSCIOWE, a nie
// nieostry kwantyfikator. "Trzykrotnie" to liczba zapisana slowem i
// podlega tej samej regule co "3"; "czesto" jest nieostre i lapie je
// zakaz w prompcie, nie ta regula.
var wordNumbers = map[string]string{
	"dwukrotnie": "2", "trzykrotnie": "3", "czterokrotnie": "4", "pieciokrotnie": "5",
	"pięciokrotnie": "5", "drugi raz": "2", "trzeci raz": "3", "czwarty raz": "4",
}

func numbersIn(s string) []string {
	out := ProseNumbers(s)
	low := strings.ToLower(s)
	for w, d := range wordNumbers {
		if strings.Contains(low, w) {
			out = append(out, d)
		}
	}
	return out
}

// numberCovered szuka liczby w materiale zrodlowym twierdzenia.
//
// Porownanie idzie po samych cyfrach, tak jak R9: "80%" w prozie jest
// pokryte przez "80" w cytacie, bo znak procentu nalezy do zapisu, nie
// do wartosci.
func numberCovered(n string, approved []ontology.Claim) bool {
	digits := stripNonDigits(n)
	if digits == "" {
		return true
	}
	for _, c := range approved {
		for _, q := range c.Quantities {
			if stripNonDigits(q.Raw) == digits {
				return true
			}
		}
		for _, q := range append(append([]ontology.QuoteRef{}, c.Evidence...), c.CounterEvidence...) {
			for _, cand := range numRe.FindAllString(q.Quote, -1) {
				if stripNonDigits(cand) == digits {
					return true
				}
			}
		}
		for _, cand := range numRe.FindAllString(c.Reasoning, -1) {
			if stripNonDigits(cand) == digits {
				return true
			}
		}
	}
	return false
}

func stripNonDigits(s string) string {
	var b strings.Builder
	for _, r := range s {
		if r >= '0' && r <= '9' {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// firstTermPresent zwraca pierwszy termin obecny w tekscie.
//
// Dopasowanie jest ODPORNE NA ODMIANE przez obciecie do rdzenia: polska
// fleksja sprawia, ze "unikanie" w liscie i "unikania" w prozie to ten
// sam termin, a dopasowanie doslowne przepuscilo by kazdy przypadek
// zalezny.
//
// Heurystyka jest CELOWO ostrozna (rdzen >= 5 znakow, dopasowanie od
// poczatku slowa): falszywy alarm kosztuje wiecej niz przeoczenie. Blad
// V wypycha raport do regeneracji, a po dwoch probach do trybu
// ekstraktywnego — czyli falszywy alarm psuje POPRAWNY raport, podczas
// gdy przeoczenie zostawia zdanie, ktore i tak zobaczy terapeuta.
func firstTermPresent(text string, terms []string) string {
	hay := foldPolish(strings.ToLower(text))
	for _, t := range terms {
		if termPresent(hay, foldPolish(strings.ToLower(t))) {
			return t
		}
	}
	return ""
}

// foldPolish sprowadza znaki diakrytyczne do liter bazowych.
//
// Odwrotnie niz w weryfikacji cytatow (pkg/ontology/quotecheck.go), gdzie
// diakrytyki sa ZACHOWANE, bo "sad" i "sad z ogonkiem" to inne slowa, a
// cytat ma byc doslowny. Tutaj porownujemy TERMIN DZIEDZINOWY z proza i
// wazniejsze jest, zeby "zwiazek" w temacie wzorca dopasowal sie do
// "zwiazku" w zdaniu niezaleznie od tego, czy model zapisal temat z
// ogonkami. Rozbieznosc ortograficzna miedzy etapami nie moze decydowac
// o tym, czy raport idzie do regeneracji.
var polskieZnaki = strings.NewReplacer(
	"ą", "a", "ć", "c", "ę", "e", "ł", "l", "ń", "n",
	"ó", "o", "ś", "s", "ź", "z", "ż", "z",
)

func foldPolish(s string) string { return polskieZnaki.Replace(s) }

func termPresent(hayLower, term string) bool {
	words := strings.Fields(term)
	if len(words) == 0 {
		return false
	}
	for _, w := range words {
		if len([]rune(w)) < 5 {
			// Krotkie slowo dopasowujemy doslownie — obcinanie rdzenia
			// zamienilo by je w losowy prefiks.
			if !strings.Contains(hayLower, w) {
				return false
			}
			continue
		}
		if !stemPresent(hayLower, w) {
			return false
		}
	}
	return true
}

func stemPresent(hayLower, word string) bool {
	r := []rune(word)
	stem := string(r[:len(r)-2])
	idx := 0
	for {
		j := strings.Index(hayLower[idx:], stem)
		if j < 0 {
			return false
		}
		abs := idx + j
		if abs == 0 || !isWordRune(rune(hayLower[abs-1])) {
			return true
		}
		idx = abs + 1
		if idx >= len(hayLower) {
			return false
		}
	}
}

func isWordRune(r rune) bool {
	return r == '-' || r == '_' || (r >= 'a' && r <= 'z') ||
		(r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r > 127
}

func trunc(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n]) + "…"
}
