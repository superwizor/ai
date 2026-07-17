// pii-eval — offline'owa bramka jakości pseudonimizacji (docs/41 §7).
//
// Dla każdej syntetycznej fixture: woła Vertex promptem ekstrakcji PII
// (ten sam kształt co extractPIIFallback w llm-worker), parsuje sekcję
// przez diarization.ParsePIIOnly, aplikuje internal/pseudonymize i
// liczy metryki względem ground-truth:
//
//	leak            — fraza z mustVanish przetrwała w wyjściu
//	false-positive  — fraza z mustStay zniknęła z wyjścia
//
// Bramki (docs/41 §7): 0% leaków na formach bazowych i warstwie regex,
// <5% na formach odmienionych; false-positives ~0.
//
// Uruchomienie (koszt: grosze — flash-lite, kilka tys. tokenów):
//
//	GCP_PROJECT_ID=superwizor-ai-25ecd go run ./services/ai-pipeline-svc/cmd/pii-eval
package main

import (
	"context"
	"fmt"
	"os"
	"strings"

	"google.golang.org/genai"

	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/diarization"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/pseudonymize"
)

const model = "gemini-2.5-flash-lite"

type fixture struct {
	name       string
	transcript string
	// mustVanishBase — formy bazowe + identyfikatory regex: bramka 0%.
	mustVanishBase []string
	// mustVanishInflected — formy odmienione/przekręcone: bramka <5% ogółem.
	mustVanishInflected []string
	// mustStay — imiona i terminy kliniczne, które NIE mogą zniknąć.
	mustStay []string
}

var fixtures = []fixture{
	{
		name: "odmiana_nazwisk",
		transcript: `## Speaker 1 [00:00.00 – 00:20.00]
Dzień dobry, Anno. Jak minął tydzień od naszej rozmowy o mężu?

## Speaker 2 [00:20.00 – 01:10.00]
Trudno. Anna Kowalska to już nie ta sama osoba, tak czuję. Z Kowalskim znowu się pokłóciliśmy. Mama Kowalskiego się wtrąca, a ja nie umiem postawić granicy panu Kowalskiemu.`,
		mustVanishBase:      []string{"Kowalska"},
		mustVanishInflected: []string{"Kowalskim", "Kowalskiego", "Kowalskiemu"},
		mustStay:            []string{"Anna", "Anno", "granicy"},
	},
	{
		name: "pracodawca_szkola_miasto",
		transcript: `## Speaker 1 [00:00.00 – 00:15.00]
Wspominałaś o napięciu w pracy. Co się dzieje?

## Speaker 2 [00:15.00 – 01:00.00]
W Softexie zwolnili pół zespołu. Dojeżdżam z Brzegu Dolnego do Wrocławia i po drodze odbieram Stasia ze Szkoły Podstawowej numer 12. Kierownik w Softexie mówi, że mam się cieszyć, że mam pracę.`,
		mustVanishBase:      []string{"Softex"},
		mustVanishInflected: []string{"Softexie", "Brzegu Dolnego", "Wrocławia", "Szkoły Podstawowej numer 12"},
		mustStay:            []string{"Stasia", "Kierownik", "napięciu"},
	},
	{
		name: "regex_identyfikatory",
		transcript: `## Speaker 1 [00:00.00 – 00:10.00]
Do wniosku o zaświadczenie potrzebuję pani danych.

## Speaker 2 [00:10.00 – 00:50.00]
PESEL 85010212345, telefon 601 234 567, mail anna.k@onet.pl. Mieszkam przy ulicy Polnej 7, kod 50-540. Dowód ABC 123456.`,
		mustVanishBase:      []string{"85010212345", "601 234 567", "anna.k@onet.pl", "50-540", "ABC 123456"},
		mustVanishInflected: []string{"Polnej 7"},
		mustStay:            []string{"zaświadczenie"},
	},
	{
		name: "przekrecone_stt_i_leki",
		transcript: `## Speaker 1 [00:00.00 – 00:15.00]
Jak działa Ketrel wieczorem? Śpi pani lepiej?

## Speaker 2 [00:15.00 – 01:00.00]
Trochę. Doktor Wiśniewska zmieniła dawkę. Z panem Wiśniewski, znaczy z jej mężem, pracowałam kiedyś w Ikei. Kasia mówi, że wyglądam lepiej.`,
		mustVanishBase:      []string{"Wiśniewska"},
		mustVanishInflected: []string{"Wiśniewski", "Ikei"},
		mustStay:            []string{"Ketrel", "Kasia", "dawkę"},
	},
	{
		name: "imiona_musza_zostac",
		transcript: `## Speaker 1 [00:00.00 – 00:12.00]
Opowiedz o relacji z dziećmi.

## Speaker 2 [00:12.00 – 00:55.00]
Marysia i Piotruś się kłócą. Karol, mój starszy, wyjechał do Poznania na studia. Tęsknię za Karolem, ale piszemy codziennie.`,
		mustVanishBase:      []string{},
		mustVanishInflected: []string{"Poznania"},
		mustStay:            []string{"Marysia", "Piotruś", "Karol", "Karolem"},
	},
}

func buildPrompt(transcript string) string {
	return fmt.Sprintf(`Przeanalizuj transkrypt sesji terapeutycznej i wypisz dane identyfikujące.

ZASADY (docs/41):
%s

JĘZYK: pl-PL

TRANSKRYPT:
%s`, pseudonymize.PIIPromptRules, transcript)
}

func main() {
	ctx := context.Background()
	project := os.Getenv("GCP_PROJECT_ID")
	if project == "" {
		fmt.Fprintln(os.Stderr, "GCP_PROJECT_ID required")
		os.Exit(2)
	}
	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		Project: project, Location: "europe-west4", Backend: genai.BackendVertexAI,
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, "vertex client:", err)
		os.Exit(2)
	}

	var (
		baseTotal, baseLeaked         int
		inflTotal, inflLeaked         int
		stayTotal, stayLost           int
		failures                      []string
	)

	for _, f := range fixtures {
		temp := float32(0.1)
		resp, err := client.Models.GenerateContent(ctx, model,
			genai.Text(buildPrompt(f.transcript)),
			&genai.GenerateContentConfig{Temperature: &temp})
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s: vertex error: %v\n", f.name, err)
			os.Exit(2)
		}
		var raw strings.Builder
		for _, part := range resp.Candidates[0].Content.Parts {
			raw.WriteString(part.Text)
		}
		entities, skipped := diarization.ParsePIIOnly(raw.String())

		eng := make([]pseudonymize.Entity, 0, len(entities))
		for _, e := range entities {
			eng = append(eng, pseudonymize.Entity{Placeholder: e.Placeholder, Forms: e.Forms})
		}
		repl := pseudonymize.NewReplacer(eng)
		out, st := repl.Apply(f.transcript)

		low := strings.ToLower(out)
		check := func(items []string, total, leaked *int, kind string) {
			for _, s := range items {
				*total++
				if strings.Contains(low, strings.ToLower(s)) {
					*leaked++
					failures = append(failures, fmt.Sprintf("%s: LEAK[%s] %q", f.name, kind, s))
				}
			}
		}
		check(f.mustVanishBase, &baseTotal, &baseLeaked, "base")
		check(f.mustVanishInflected, &inflTotal, &inflLeaked, "infl")
		for _, s := range f.mustStay {
			stayTotal++
			if !strings.Contains(low, strings.ToLower(s)) {
				stayLost++
				failures = append(failures, fmt.Sprintf("%s: FALSE-POSITIVE %q removed", f.name, s))
			}
		}
		fmt.Printf("── %-28s entities=%d skipped=%d repl=%d regex=%d unmatched=%d\n",
			f.name, len(entities), skipped, st.Replacements, st.RegexReplacements, len(st.UnmatchedForms))
	}

	fmt.Println()
	fmt.Printf("BASE+REGEX leak: %d/%d  (bramka: 0)\n", baseLeaked, baseTotal)
	fmt.Printf("INFLECTED leak:  %d/%d  (bramka: <5%%)\n", inflLeaked, inflTotal)
	fmt.Printf("FALSE-POSITIVE:  %d/%d  (bramka: ~0)\n", stayLost, stayTotal)
	for _, f := range failures {
		fmt.Println("  ✗", f)
	}

	inflRate := 0.0
	if inflTotal > 0 {
		inflRate = float64(inflLeaked) / float64(inflTotal)
	}
	if baseLeaked > 0 || inflRate >= 0.05 || stayLost > 0 {
		fmt.Println("\nGATE: FAIL")
		os.Exit(1)
	}
	fmt.Println("\nGATE: PASS")
}
