package ontopipe

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

// MaxRegeneracji to liczba ponowien syntezy po naruszeniu V1-V6.
//
// Dwie, za dok. 11: pierwsza poprawka lapie zwykle potkniecie jezykowe,
// druga jest ostatnia szansa. Dalsze ponawianie to placenie za model,
// ktory systematycznie nie potrafi utrzymac sie w szynach — wtedy
// uczciwiej oddac raport ekstraktywny niz proze, ktora nie przechodzi
// weryfikacji.
const MaxRegeneracji = 2

// Run wykonuje caly potok S1-S5.
//
// Bledy etapow LLM sa TWARDE: potok, ktory po nieudanym S1 poszedlby
// dalej, wyprodukowalby raport z niczego. Odrzucenia walidatora bledami
// nie sa — to normalny wynik i trafiaja do Result.
func Run(ctx context.Context, llm LLM, in Input) (Result, error) {
	var res Result
	if in.Ontology == nil {
		return res, fmt.Errorf("ontopipe: brak ontologii — potok S1-S5 nie ma czego egzekwowac")
	}
	o := in.Ontology

	// ── S1 ──
	spans, s1rejected, err := ExtractSpans(ctx, llm, in, &res.Usage)
	if err != nil {
		return res, err
	}
	res.Spans = spans
	res.S1Rejected = s1rejected

	spanByID := map[string]ontology.Span{}
	for _, s := range spans {
		spanByID[s.ID] = s.Span
	}

	// ── S1.5 ── deterministyczne, bez LLM
	res.Patterns = ontology.DetectPatterns(spans, ontology.PatternOptions{})

	// ── S2 + S3 ── konstrukt po konstrukcie, w kolejnosci zaleznosci
	categories, skipped := o.ConstructsForStage()
	if len(skipped) > 0 {
		// Pominiete kompozyty sa faktem o pokryciu taksonomii, nie
		// szczegolem implementacji — wolajacy ma prawo to zobaczyc.
		res.SkippedComposites = skipped
	}

	approvedConstructs := map[string]bool{}
	for _, id := range orderByRequires(o, categories) {
		stage, err := MapConstruct(ctx, llm, o, id, spans, &res.Usage)
		if err != nil {
			return res, err
		}
		for i := range stage.Claims {
			classifyClaim(&stage.Claims[i], spanByID)
		}
		v := o.Validate3(stage, ontology.ValidateOptions{
			Spans:              spanByID,
			ApprovedConstructs: approvedConstructs,
		})
		if len(v.Approved) > 0 {
			approvedConstructs[id] = true
		}
		res.Approved = append(res.Approved, v.Approved...)
		res.Rejected = append(res.Rejected, v.Rejected...)
		res.Degraded = append(res.Degraded, v.Degraded...)
		res.NoFit = append(res.NoFit, v.NoFitConstructs...)
		res.Insufficient = append(res.Insufficient, v.InsufficientData...)
	}

	// ── S4 + S5 ── z petla regeneracji
	var pastIDs []string
	for _, s := range spans {
		if s.AboutPast {
			pastIDs = append(pastIDs, s.ID)
		}
	}
	si := SynthesisInput{
		Claims:       res.Approved,
		Patterns:     res.Patterns,
		Degraded:     res.Degraded,
		Insufficient: res.Insufficient,
		NoFit:        res.NoFit,
		PastSpanIDs:  pastIDs,
	}
	for proba := 0; ; proba++ {
		rep, err := Synthesize(ctx, llm, o, si, &res.Usage)
		if err != nil {
			return res, err
		}
		viol := Verify(o, rep, si, spanByID)
		if len(viol) == 0 {
			res.Report = rep
			res.Violations = nil
			return res, nil
		}
		if proba >= MaxRegeneracji {
			// TRYB EKSTRAKTYWNY: cytaty i kategorie bez prozy.
			//
			// Raport ubozszy, ale prawdziwy. Wypuszczenie prozy, ktora
			// nie przeszla V1-V6, byloby oddaniem terapeucie zdania z
			// podniesionym statusem albo liczba bez pokrycia — czyli
			// dokladnie tego, przed czym cala ta architektura ma bronic.
			res.Report = extractiveReport(si)
			res.Violations = viol
			res.Extractive = true
			return res, nil
		}
		si.Corrections = viol
	}
}

// orderByRequires ustawia konstrukty tak, zeby zaleznosc byla walidowana
// przed konstruktem, ktory jej wymaga.
//
// Bez tego R3 degradowalaby konstrukty wylacznie z powodu KOLEJNOSCI
// alfabetycznej — `requires` sprawdza sie wobec juz zatwierdzonych, wiec
// konstrukt przetworzony za wczesnie zawsze wygladalby na niespelniony.
//
// Cykl w `requires` jest bledem ontologii, nie sytuacja do obsluzenia w
// runtime: reszte dokladamy w porzadku alfabetycznym, a lint w CI ma
// cykl wylapac wczesniej.
func orderByRequires(o *ontology.Ontology, ids []string) []string {
	pending := map[string]bool{}
	for _, id := range ids {
		pending[id] = true
	}
	done := map[string]bool{}
	out := make([]string, 0, len(ids))

	for len(out) < len(ids) {
		postep := false
		for _, id := range ids {
			if done[id] {
				continue
			}
			gotowy := true
			if c := o.Constructs[id]; c != nil {
				for _, r := range c.Requires {
					// Zaleznosc spoza tej listy (np. kompozyt) nie
					// blokuje — i tak nie zostanie zatwierdzona.
					if pending[r] && !done[r] {
						gotowy = false
						break
					}
				}
			}
			if gotowy {
				out = append(out, id)
				done[id] = true
				postep = true
			}
		}
		if !postep {
			var reszta []string
			for _, id := range ids {
				if !done[id] {
					reszta = append(reszta, id)
				}
			}
			sort.Strings(reszta)
			out = append(out, reszta...)
			break
		}
	}
	return out
}

// classifyClaim ustawia flagi, ktorych model nie deklaruje.
//
// Etiologicznosc i podmiotowosc terapeuty rozstrzygamy MECHANICZNIE, a
// nie pytaniem do modelu. Pytanie "czy to twierdzenie jest etiologiczne?"
// zadane temu samemu modelowi, ktory je napisal, dziedziczy jego blad:
// model, ktory wlasnie skonfabulowal geneze, odpowie, ze nie konfabulowal.
func classifyClaim(cl *ontology.Claim, spans map[string]ontology.Span) {
	tekst := cl.Reasoning
	for _, q := range cl.Evidence {
		tekst += " " + q.Quote
	}

	if firstTermPresent(cl.Reasoning, etiologyMarkers) != "" {
		cl.Etiological = true
	}
	if firstTermPresent(cl.Reasoning, terapeutaMarkers) != "" &&
		firstTermPresent(cl.Reasoning, stanWewnetrznyMarkers) != "" {
		cl.SubjectIsTherapist = true
	}

	// Liczby z uzasadnienia dostaja span, w ktorym faktycznie padly.
	// Liczba bez takiego spanu dostaje SpanID pusty i R9 ja odrzuci —
	// to jest zamierzone: fabrykowana precyzja ma kosztowac cale
	// twierdzenie, bo wyglada na pomiar i przekonuje mocniej niz proza.
	// ProseNumbers, nie surowe numRe: "s08" to odnosnik do spanu, nie
	// liczba osiem. Na kanarku PPT surowe dopasowanie kazalo R9 odrzucic
	// SIEDEM poprawnych twierdzen — te, ktore najstaranniej powolywaly sie
	// na zrodlo po numerze.
	for _, n := range ProseNumbers(cl.Reasoning) {
		q := ontology.Quantity{Raw: n}
		for _, ev := range cl.Evidence {
			s, ok := spans[ev.SpanID]
			if ok && strings.Contains(stripNonDigits(s.QuoteVerbatim), stripNonDigits(n)) &&
				stripNonDigits(n) != "" {
				q.SpanID = ev.SpanID
				break
			}
		}
		cl.Quantities = append(cl.Quantities, q)
	}
}

var terapeutaMarkers = []string{"terapeut", "superwizor", "prowadzac", "prowadząc"}

var stanWewnetrznyMarkers = []string{
	"czuje", "odczuwa", "przezywa", "przeżywa", "jego lek", "jej lek",
	"jego lęk", "jej lęk", "frustracj", "bezradnos", "bezradnoś",
	"kontrtransfer", "ma poczucie", "boi sie", "boi się", "zniecierpliw",
}

// extractiveReport sklada raport bez prozy z samych zatwierdzonych bytow.
//
// Buduje go KOD, nie model: skoro powodem awarii jest to, ze model nie
// utrzymuje sie w szynach, oddanie mu jeszcze jednej proby zapisu byloby
// powtorzeniem tego samego bledu.
func extractiveReport(in SynthesisInput) Report {
	byConstruct := map[string][]ontology.Claim{}
	for _, c := range in.Claims {
		byConstruct[c.ConstructID] = append(byConstruct[c.ConstructID], c)
	}

	var rep Report
	for _, id := range allowedConstructIDs(in) {
		cr := ConstructReport{ConstructID: id}
		for i, c := range byConstruct[id] {
			var cyt []string
			var sup []string
			for _, q := range c.Evidence {
				cyt = append(cyt, fmt.Sprintf("%q", q.Quote))
				sup = append(sup, q.SpanID)
			}
			var contra []string
			for _, q := range c.CounterEvidence {
				contra = append(contra, q.SpanID)
			}
			kat := strings.Join(c.Categories, ", ")
			if kat == "" {
				kat = "(bez kategorii)"
			}
			cr.Hypotheses = append(cr.Hypotheses, Hypothesis{
				ID:              fmt.Sprintf("E%d", i+1),
				Claim:           kat + " — " + strings.Join(cyt, "; "),
				Supporting:      sup,
				Contradicting:   contra,
				EpistemicStatus: string(c.Status),
				Confidence:      c.Confidence,
			})
		}
		rep.Constructs = append(rep.Constructs, cr)
	}
	return rep
}
