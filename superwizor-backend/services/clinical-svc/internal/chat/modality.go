package chat

import (
	"context"
	"strings"

	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/pkg/guardrail"
)

// Soczewka modalnosci.
//
// # Problem, ktory to rozwiazuje
//
// 20.08.2026 terapeuta poprosil "zastosuj model rownowagi" (A7) i dostal
// sekcje o wymyslonych naglowkach zamiast czterech sfer PPT. Raport zna
// ontologie modalnosci, bo llm-worker czyta
// modalities.therapist_ai_general_prompt; czat uzywal generycznych
// promptow per intencja i nie wiedzial, czym Model Rownowagi jest.
//
// # Sklad
//
// Fragment soczewki zyje w tym samym JSONB co prompt raportowy, pod
// osobnym kluczem 'chat' (zrodla w repo:
// migrations/modality_prompts/chat_<KOD>.txt). Osobny klucz, a nie
// reuzycie 'system': prompt raportowy ma ~8000 znakow i opisuje ZADANIE
// pisania raportu — doklejenie go do czatu podnioslby latencje (wlasnie
// zbita z 12,8 s do 7,4 s) i kazaloby modelowi "generowac raport" przy
// pytaniu o cytaty. Soczewka ma ~1,5 tys. znakow i jest OPTYKA, nie
// zadaniem: zadanie definiuje prompt intencji i on wygrywa.
//
// # Dociaganie innej modalnosci
//
// Terapeuta prowadzacy proces w PPT moze zapytac "jak konceptualizacja
// wyglada w podejsciu CBT?". Wykrywanie jest LEKSYKALNE i deterministyczne
// (aliasy nazw modalnosci), nie modelowe: koszt zero, testowalne, a tryb
// awarii lagodny — nierozpoznana prosba spada do soczewki kartoteki.
// Priorytet: modalnosc wymieniona w pytaniu > modalnosc kartoteki.
//
// # Granica bezpieczenstwa
//
// Soczewka to kontrola instrukcyjna, czyli ta, ktorej ADR sekcja 4.1
// celowo nie ufa. Dlatego: (1) tresc z bazy jest opakowywana w Render(),
// ktory KODEM doklada przypomnienie zasad — edycja fragmentu w bazie nie
// moze ich usunac; (2) schematy wyjscia i weryfikator dzialaja bez zmian.
// Wlasciwe wymuszenie ontologii (schemat per model z zamknietym enumem
// kategorii) to warstwa 2 — patrz docs/63 sekcja 9.

// ModalityLens to soczewka jednej modalnosci.
type ModalityLens struct {
	Code        string
	DisplayName string
	Fragment    string
}

// Render sklada blok promptu.
//
// Ogon jest w KODZIE, nie w bazie: fragment jest edytowalny przez
// operatora, a przypomnienie inwariantow nie moze zniknac razem z
// nieostrozna edycja tresci.
func (l ModalityLens) Render() string {
	return "SOCZEWKA MODALNOSCI (" + l.DisplayName + "):\n" + strings.TrimSpace(l.Fragment) + "\n" +
		"Soczewka zmienia jezyk i porzadek analizy, nigdy zasady: hipotezy formulowane " +
		"warunkowo, uziemienie cytatami wedlug schematu, bez etykiet nozologicznych, " +
		"bez farmakoterapii, bez oceny ryzyka."
}

// modalityAliases mapuje kod modalnosci na frazy, po ktorych rozpoznajemy
// ja w pytaniu. Frazy sa w formie ZLOZONEJ przez fold() — male litery,
// bez diakrytykow.
//
// Aliasy sa celowo konserwatywne, bo falszywe dopasowanie podmienia
// soczewke po cichu:
//   - ST wylacznie jako "terapii schematow" itp. — golo "schematow"
//     zapala sie na "schematy myslenia", czyli slowniku CBT;
//   - SYS jako "systemow" nie lapie "systematycznie" (po "system" stoi
//     tam "a", nie "o") — sprawdzone testem;
//   - PPT bez golego "pozytywn" — "pozytywne strony" to zwykla polszczyzna.
//     Za to "model rownowagi" JEST aliasem PPT: to narzedzie tej szkoly
//     i prosba o nie na kartotece CBT oznacza prosbe o rame PPT.
var modalityAliases = map[string][]string{
	"CBT":     {"cbt", "poznawczo-behawioral", "poznawczo behawioral"},
	"PPT":     {"ppt", "psychoterapii pozytywnej", "psychoterapia pozytywna", "terapii pozytywnej", "peseschkian", "model rownowagi", "modelu rownowagi"},
	"GESTALT": {"gestalt"},
	"PSYCHO":  {"psychodynamiczn", "psychoanaliz"},
	"EFT":     {"eft", "skoncentrowanej na emocjach", "skoncentrowana na emocjach"},
	"SYS":     {"systemow"},
	"ST":      {"terapii schematow", "terapia schematow", "terapie schematow", "schema therapy"},
	"COACH":   {"coaching", "modelu grow", "model grow", "icf"},
	// UNIV bez aliasow: to rama domyslna, nie cos, o co sie prosi.
}

// DetectRequestedModality rozpoznaje modalnosc wymieniona w pytaniu.
//
// Przy kilku trafieniach wygrywa wymieniona NAJWCZESNIEJ — "porownaj
// ujecie CBT z Gestalt" dostaje soczewke CBT, a nie los zalezny od
// kolejnosci iteracji po mapie.
func DetectRequestedModality(question string) (string, bool) {
	folded := fold(question)
	best, bestIdx := "", -1
	for code, aliases := range modalityAliases {
		for _, a := range aliases {
			idx := strings.Index(folded, a)
			if idx < 0 {
				continue
			}
			if bestIdx == -1 || idx < bestIdx || (idx == bestIdx && code < best) {
				best, bestIdx = code, idx
			}
		}
	}
	return best, bestIdx >= 0
}

const sqlLensByFile = `
SELECT m.system_code, m.display_name, coalesce(m.therapist_ai_general_prompt->>'chat', '')
  FROM patient_files pf
  JOIN modalities m ON m.id = pf.modality_id
 WHERE pf.id = $1`

const sqlLensByCode = `
SELECT m.system_code, m.display_name, coalesce(m.therapist_ai_general_prompt->>'chat', '')
  FROM modalities m
 WHERE m.system_code = $1 AND m.is_supported`

// LensByFile zwraca soczewke modalnosci prowadzonej w tej kartotece.
// Best-effort: brak wiersza albo pusty fragment = brak soczewki, czyli
// dzisiejsze zachowanie.
func (r Retriever) LensByFile(ctx context.Context, patientFileID uuid.UUID) (ModalityLens, bool) {
	return r.scanLens(r.Pool.QueryRow(ctx, sqlLensByFile, patientFileID))
}

// LensByCode zwraca soczewke wskazanej modalnosci — sciezka "dociagniecia"
// innej ramy, niz prowadzona.
func (r Retriever) LensByCode(ctx context.Context, code string) (ModalityLens, bool) {
	return r.scanLens(r.Pool.QueryRow(ctx, sqlLensByCode, code))
}

func (r Retriever) scanLens(row RowScanner) (ModalityLens, bool) {
	var l ModalityLens
	if err := row.Scan(&l.Code, &l.DisplayName, &l.Fragment); err != nil {
		return ModalityLens{}, false
	}
	if strings.TrimSpace(l.Fragment) == "" {
		return ModalityLens{}, false
	}
	return l, true
}

// resolveLens wybiera soczewke dla tury.
//
// Regula dla A4_EDU jest inna niz dla intencji uziemionych i to nie
// przypadek: A4 z definicji nie dostaje ZADNEGO kontekstu klienta, a
// modalnosc prowadzonego procesu JEST informacja o kliencie. Dlatego A4
// dostaje soczewke wylacznie wtedy, gdy terapeuta sam wymienil modalnosc
// w pytaniu — i nigdy nie odpytujemy wtedy kartoteki.
func (s Service) resolveLens(ctx context.Context, t Turn, intent guardrail.Intent) (ModalityLens, bool) {
	requested, has := DetectRequestedModality(t.Question)

	if intent == guardrail.A4Edu {
		if !has {
			return ModalityLens{}, false
		}
		return s.Retriever.LensByCode(ctx, requested)
	}

	if has {
		if l, ok := s.Retriever.LensByCode(ctx, requested); ok {
			return l, true
		}
		// Nierozpoznany kod w bazie — spadamy do modalnosci kartoteki.
	}
	return s.Retriever.LensByFile(ctx, t.PatientFileID)
}
