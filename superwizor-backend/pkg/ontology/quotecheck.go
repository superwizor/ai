package ontology

import (
	"strings"
	"unicode"
)

// Weryfikacja mechaniczna cytatow — bramka S1 (dok. 11, sekcja 4).
//
// Model zwraca `quote_verbatim`; ta funkcja sprawdza, czy taki tekst
// FAKTYCZNIE jest w transkrypcji. Span, ktory nie przejdzie, nie
// istnieje — nie trafia do S2, wiec nie moze uziemic zadnego
// twierdzenia.
//
// To jest fundament proweniencji. Bez niego reszta potoku sprawdza
// jedynie, czy model WSKAZAL span — a nie, czy powiedzial prawde o jego
// tresci. Objaw 5 z dokumentu 11 wracalby tylnymi drzwiami: zamiast
// zmyslic twierdzenie, wystarczyloby zmyslic cytat.
//
// Prog i normalizacja sa wynikiem doswiadczenia z weryfikatora czatu
// (pkg/guardrail): transkrypcja mowy niesie roznice w bialych znakach i
// interpunkcji, ktore nie sa fabrykacja. Ale zmiana SLOW juz nia jest —
// 21.08 model przetlumaczyl angielski cytat na polski i weryfikator
// czatu slusznie to odrzucil.

// DefaultQuoteThreshold to minimalne podobienstwo cytatu do zrodla.
//
// 0,95 jest wysokie celowo: przy 0,80 zmiana pojedynczego slowa w
// krotkim cytacie przechodzi, a to juz jest zmiana znaczenia.
const DefaultQuoteThreshold = 0.95

// VerifyQuote sprawdza, czy cytat jest fragmentem transkrypcji.
//
// Dwustopniowo: najpierw dopasowanie doslowne po normalizacji (szybkie,
// pokrywa wiekszosc przypadkow), potem podobienstwo znakowe dla roznic
// w interpunkcji i ogonkach. Zwraca uzyte podobienstwo, zeby wolajacy
// mogl je zaraportowac w metryce s1_reject_rate.
func VerifyQuote(transcript, quote string, threshold float64) (ok bool, similarity float64) {
	q := normalizeForMatch(quote)
	if q == "" {
		return false, 0
	}
	src := normalizeForMatch(transcript)

	// Sciezka szybka: cytat jest doslownym podlancuchem.
	if strings.Contains(src, q) {
		return true, 1.0
	}

	// Sciezka rozmyta: najlepsze okno o dlugosci cytatu. Bierzemy
	// maksimum, a nie srednia — cytat ma pasowac do JEDNEGO miejsca w
	// transkrypcji, nie do calosci.
	best := bestWindowSimilarity(src, q)
	return best >= threshold, best
}

// normalizeForMatch sprowadza tekst do postaci porownywalnej.
//
// Ujednolicamy biale znaki, wielkosc liter i interpunkcje — to sa
// roznice zapisu mowy. NIE ruszamy liter: usuniecie ogonkow
// przepusciloby "moze" jako "morze", a to jest inne slowo.
func normalizeForMatch(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	lastSpace := true
	for _, r := range strings.ToLower(s) {
		switch {
		case unicode.IsSpace(r):
			if !lastSpace {
				b.WriteRune(' ')
				lastSpace = true
			}
		case unicode.IsPunct(r):
			// Interpunkcja pomijana: transkrypcja automatyczna stawia ja
			// niekonsekwentnie, a jej brak nie zmienia slow.
		default:
			b.WriteRune(r)
			lastSpace = false
		}
	}
	return strings.TrimSpace(b.String())
}

// bestWindowSimilarity znajduje najlepsze dopasowanie okna o dlugosci
// cytatu.
func bestWindowSimilarity(src, quote string) float64 {
	s := []rune(src)
	q := []rune(quote)
	if len(q) == 0 || len(s) < len(q) {
		// Cytat dluzszy niz zrodlo nie moze byc jego fragmentem.
		return 0
	}
	best := 0.0
	// Krok 1 znaku: transkrypcje sesji to kilkadziesiat tysiecy znakow,
	// a cytaty krotkie — koszt jest akceptowalny i liczony raz per span.
	for i := 0; i+len(q) <= len(s); i++ {
		sim := similarity(s[i:i+len(q)], q)
		if sim > best {
			best = sim
			if best == 1.0 {
				break
			}
		}
	}
	return best
}

// similarity to udzial pozycji zgodnych — miara pozycyjna, nie edycyjna.
//
// Swiadomy wybor: odleglosc edycyjna wybaczylaby wstawienie slowa w
// srodku (przesuniecie reszty), a wstawienie slowa do cytatu JEST
// fabrykacja. Miara pozycyjna karze je natychmiast.
func similarity(a, b []rune) float64 {
	if len(a) != len(b) || len(a) == 0 {
		return 0
	}
	same := 0
	for i := range a {
		if a[i] == b[i] {
			same++
		}
	}
	return float64(same) / float64(len(a))
}

// VerifySpans odsiewa spany, ktorych cytaty nie sa w transkrypcji.
//
// Zwraca spany przyjete oraz identyfikatory odrzuconych — te drugie
// zasilaja metryke s1_reject_rate (dok. 11 sekcja 8.3). Wysoki wskaznik
// oznacza, ze S1 zmysla cytaty, i jest sygnalem do audytu promptu, a nie
// do podniesienia progu.
func VerifySpans(transcript string, spans []Span, threshold float64) (accepted []Span, rejected []string) {
	if threshold <= 0 {
		threshold = DefaultQuoteThreshold
	}
	for _, s := range spans {
		if ok, _ := VerifyQuote(transcript, s.QuoteVerbatim, threshold); ok {
			accepted = append(accepted, s)
			continue
		}
		rejected = append(rejected, s.ID)
	}
	return accepted, rejected
}
