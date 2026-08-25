package llmworker

import (
	"testing"

	"github.com/superwizor-ai/backend/pkg/appconfig"
	"github.com/superwizor-ai/backend/services/ai-pipeline-svc/internal/ontopipe"
)

// TestBudzetMysleniaPerModel: Flash dopuszcza zero, Pro nie — ustawienie
// zera dla Pro odrzuca CAŁE żądanie (zaobserwowane na produkcji
// 2026-08-23, S2 padło na wszystkich konstruktach).
// Test sprawdza KONTRAKT funkcji, a nie to, ktorego modelu potok akurat
// uzywa. Do 2026-08-25 pytal o budzet przez `ontopipe.ModelMapping` —
// czyli mierzyl biezacy wybor. Gdy caly potok przeszedl na Flash, test
// zaczal padac, choc nic sie nie zepsulo, a lekcja z produkcji (Pro
// odrzuca zero) zniknelaby razem z nim. Powrot na Pro jest odlegly o
// jedna stala, wiec obie galezie musza zostac sprawdzone.
func TestBudzetMysleniaPerModel(t *testing.T) {
	if got := thinkingBudgetFor("gemini-2.5-flash"); got != 0 {
		t.Errorf("Flash: budzet = %d, oczekiwano 0 (tokeny myslenia zjadaja MaxOutputTokens)", got)
	}
	if got := thinkingBudgetFor("gemini-2.5-pro"); got < minThinkingBudgetPro {
		t.Errorf("Pro: budzet = %d, a model odrzuca cale zadanie ponizej %d",
			got, minThinkingBudgetPro)
	}
	// Kazdy etap potoku musi dostac budzet, ktory jego model przyjmuje.
	for _, m := range []string{ontopipe.ModelExtraction, ontopipe.ModelMapping,
		ontopipe.ModelSynthesis} {
		b := thinkingBudgetFor(m)
		if m == "gemini-2.5-pro" && b < minThinkingBudgetPro {
			t.Errorf("etap na Pro (%s) dostaje budzet %d — zadanie zostanie odrzucone", m, b)
		}
	}
}

// TestLustroModeluFlashSieNieRozjezdza — dobór budżetu opiera się na
// osobnej stałej, więc zmiana modelu w ontopipe bez zmiany tutaj cicho
// wyłączyłaby optymalizację.
func TestLustroModeluFlashSieNieRozjezdza(t *testing.T) {
	if ModelExtractionFlash != ontopipe.ModelExtraction {
		t.Fatalf("lustro rozjechalo sie: %q vs %q — Flash dostanie budzet Pro",
			ModelExtractionFlash, ontopipe.ModelExtraction)
	}
}

// TestModelDoWycenyIdzieZaPotokiem — koszt musi byc liczony po stawkach
// modelu, ktorego uzyl DANY przebieg.
//
// Regresja, ktora to zamyka: raport eksperymentalny chodzil na Pro, a
// koszt zapisywal po stawce legacy (Flash), zaniżajac kazdy wiersz
// okolo 3,7 raza przez piec tygodni. Blad byl niewidoczny, bo zaniżona
// kwota nadal wyglada jak koszt — dlatego test sprawdza ZRODLO nazwy,
// nie sama liczbe.
func TestModelDoWycenyIdzieZaPotokiem(t *testing.T) {
	// Dzis legacy i ontopipe maja TE SAMA nazwe modelu, wiec porownanie
	// wyniku z oczekiwana stala przechodzi takze dla implementacji z
	// bledem — taki test tylko udawalby ochrone. Podmieniamy wiec nazwe
	// legacy na czas testu i odtwarzamy uklad sprzed 2026-08-25: dwa
	// potoki, dwa rozne modele. Dopiero wtedy widac, za czym idzie wycena.
	oryg := geminiModel
	geminiModel = "gemini-legacy-tylko-do-testu"
	t.Cleanup(func() { geminiModel = oryg })

	if got := modelDoWyceny(provenance{Pipeline: appconfig.PipelineLegacy}); got != geminiModel {
		t.Errorf("legacy: wycena po %q, a potok uzyl %q", got, geminiModel)
	}
	for _, klasa := range []string{appconfig.PipelineOntology, PipelineExperimental} {
		switch got := modelDoWyceny(provenance{Pipeline: klasa}); got {
		case ontopipe.ModelSynthesis:
			// dobrze
		case geminiModel:
			t.Errorf("%s: wycena spadla na stala legacy (%q) zamiast modelu potoku (%q) — to jest dokladnie blad, ktory zaniżal koszt raportow eksperymentalnych",
				klasa, got, ontopipe.ModelSynthesis)
		default:
			t.Errorf("%s: wycena po %q, a potok uzyl %q", klasa, got, ontopipe.ModelSynthesis)
		}
	}
}

// TestJednaNazwaModeluOpisujeCalyPrzebieg pilnuje zalozenia, na ktorym
// stoi wycena: skoro Usage nie rozbija tokenow per model, jedna nazwa
// jest uczciwa TYLKO wtedy, gdy wszystkie etapy dziela model.
//
// Gdy ten test padnie, nie zmieniaj go — albo rozbij Usage per model,
// albo pogodz sie z NULL-owym kosztem dla potoku ontologicznego.
func TestJednaNazwaModeluOpisujeCalyPrzebieg(t *testing.T) {
	if ontopipe.ModelExtraction != ontopipe.ModelMapping ||
		ontopipe.ModelMapping != ontopipe.ModelSynthesis {
		t.Fatalf("etapy rozjechaly sie (S1=%q S2=%q S4=%q) — koszt przebiegu przestal byc policzalny jedna stawka",
			ontopipe.ModelExtraction, ontopipe.ModelMapping, ontopipe.ModelSynthesis)
	}
}
