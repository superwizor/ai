package ontology

import (
	"testing"
)

// Testy walidatora S3. Kazdy odpowiada konkretnemu objawowi z diagnozy
// dokumentu 11 — to nie sa testy "czy funkcja dziala", tylko "czy klasa
// bledu, dla ktorej ta architektura powstala, jest zablokowana".

func spanZwykly(id, sesja string) Span {
	return Span{ID: id, SessionID: sesja, QuoteVerbatim: "cos powiedzial",
		Kind: SpanDeclarative, ObservedBy: ObservedBySelf}
}

func opcje(spany ...Span) ValidateOptions {
	m := map[string]Span{}
	for _, s := range spany {
		m[s.ID] = s
	}
	return ValidateOptions{Spans: m, ApprovedConstructs: map[string]bool{}}
}

func dowody(ids ...string) []QuoteRef {
	out := make([]QuoteRef, 0, len(ids))
	for _, id := range ids {
		out = append(out, QuoteRef{SpanID: id, Quote: "cos powiedzial"})
	}
	return out
}

func pierwszyPowod(t *testing.T, r ValidationResult) RejectReason {
	t.Helper()
	if len(r.Rejected) == 0 {
		t.Fatalf("oczekiwano odrzucenia, zatwierdzono %d", len(r.Approved))
	}
	return r.Rejected[0].Reason
}

// ── R1/R6: bledy kategorialne (objaw 1 i 6 z dok. 11) ──

func TestR1_KategoriaSpozaKatalogu(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "actual_capacity_secondary", Claims: []Claim{{
		ConstructID: "actual_capacity_secondary",
		Categories:  []string{"spokój"}, // klasyczny blad z feedbacku
		Evidence:    dowody("s1", "s2"),
		Status:      StatusInterpretation,
	}}}
	got := o.Validate3(res, opcje(
		Span{ID: "s1", SessionID: "a", Kind: SpanBehavioral, QuoteVerbatim: "x"},
		spanZwykly("s2", "a")))
	if r := pierwszyPowod(t, got); r != ReasonEnum {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonEnum)
	}
}

func TestR6_KategoriaZRejestruAntywzorcow(t *testing.T) {
	// "troska o siebie" jest w common_confusions PPT. Nawet gdyby ktos
	// dopisal ja do values, R6 ma ja zatrzymac.
	o := wczytajSeed(t, "ppt")
	c := o.Constructs["actual_capacity_secondary"]
	c.Values = append(c.Values, "troska o siebie")

	res := StageResult{ConstructID: "actual_capacity_secondary", Claims: []Claim{{
		ConstructID: "actual_capacity_secondary",
		Categories:  []string{"troska o siebie"},
		Evidence:    dowody("s1", "s2"),
		Status:      StatusInterpretation,
	}}}
	got := o.Validate3(res, opcje(
		Span{ID: "s1", SessionID: "a", Kind: SpanBehavioral, QuoteVerbatim: "x"},
		spanZwykly("s2", "a")))
	if r := pierwszyPowod(t, got); r != ReasonIsNot {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonIsNot)
	}
}

// ── R2: prog dowodowy ──

func TestR2_ZaMaloSpanow(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "actual_capacity_primary", Claims: []Claim{{
		ConstructID: "actual_capacity_primary",
		Categories:  []string{"zaufanie"},
		Evidence:    dowody("s1"), // wymagane 2
		Status:      StatusInterpretation,
	}}}
	if r := pierwszyPowod(t, o.Validate3(res, opcje(spanZwykly("s1", "a")))); r != ReasonCoverage {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonCoverage)
	}
}

// TestR2_DwaCytatyZJednegoSpanuToJedenDowod — inaczej model spelnialby
// prog, cytujac dwa razy to samo zdanie.
func TestR2_DwaCytatyZJednegoSpanuToJedenDowod(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "actual_capacity_primary", Claims: []Claim{{
		ConstructID: "actual_capacity_primary",
		Categories:  []string{"zaufanie"},
		Evidence:    dowody("s1", "s1"),
		Status:      StatusInterpretation,
	}}}
	if r := pierwszyPowod(t, o.Validate3(res, opcje(spanZwykly("s1", "a")))); r != ReasonCoverage {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonCoverage)
	}
}

func TestR2_WymogSpanuBehawioralnego(t *testing.T) {
	// actual_capacity_secondary wymaga behavioral: 1 — deklaracja
	// "jestem punktualny" nie wystarcza.
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "actual_capacity_secondary", Claims: []Claim{{
		ConstructID: "actual_capacity_secondary",
		Categories:  []string{"punktualność"},
		Evidence:    dowody("s1", "s2"),
		Status:      StatusInterpretation,
	}}}
	got := o.Validate3(res, opcje(spanZwykly("s1", "a"), spanZwykly("s2", "a")))
	if r := pierwszyPowod(t, got); r != ReasonCoverage {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonCoverage)
	}
}

// ── R3: degradacja, nigdy podniesienie rangi ──

func TestR3_NiespelnioneRequiresDegradujeZamiastUsuwac(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "key_conflict", Claims: []Claim{{
		ConstructID: "key_conflict",
		Evidence:    dowody("s1", "s2", "s3"),
		Status:      StatusTheoreticalHypothesis,
	}}}
	got := o.Validate3(res, opcje(
		spanZwykly("s1", "a"), spanZwykly("s2", "b"), spanZwykly("s3", "c")))

	if len(got.Degraded) != 1 {
		t.Fatalf("degradacji = %d, oczekiwano 1", len(got.Degraded))
	}
	if len(got.Rejected) != 0 {
		t.Errorf("konstrukt zostal ODRZUCONY zamiast zdegradowany: %v", got.Rejected)
	}
	if got.Degraded[0].To == "" {
		t.Error("brak fallback_rendering — degradacja bez tresci do wyrenderowania")
	}
}

// ── R5: etiologia (objaw 5) ──

func TestR5_EtiologiaBezSpanuOPrzeszlosci(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "basic_conflict", Claims: []Claim{{
		ConstructID: "basic_conflict",
		Evidence:    dowody("s1", "s2"),
		Status:      StatusTheoreticalHypothesis,
		Etiological: true,
	}}}
	got := o.Validate3(res, opcje(spanZwykly("s1", "a"), spanZwykly("s2", "b")))
	if r := pierwszyPowod(t, got); r != ReasonEtiology {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonEtiology)
	}
}

func TestR5_EtiologiaZeSpanemOPrzeszlosciPrzechodzi(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	s1 := spanZwykly("s1", "a")
	s1.AboutPast = true
	res := StageResult{ConstructID: "basic_conflict", Claims: []Claim{{
		ConstructID: "basic_conflict",
		Evidence:    dowody("s1", "s2"),
		Status:      StatusTheoreticalHypothesis,
		Etiological: true,
	}}}
	got := o.Validate3(res, opcje(s1, spanZwykly("s2", "b")))
	if len(got.Approved) != 1 {
		t.Errorf("zatwierdzonych %d, oczekiwano 1: %v", len(got.Approved), got.Rejected)
	}
}

// ── R7: no_fit ──

func TestR7_NoFitNieDostajeKategorii(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{
		ConstructID: "actual_capacity_secondary",
		NoFit:       true,
		Claims: []Claim{{ConstructID: "actual_capacity_secondary",
			Categories: []string{"sumienność"}, Evidence: dowody("s1")}},
	}
	got := o.Validate3(res, opcje(spanZwykly("s1", "a")))
	if r := pierwszyPowod(t, got); r != ReasonNoFit {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonNoFit)
	}
	if len(got.NoFitConstructs) != 1 {
		t.Error("no_fit nie trafil do rejestru luk ontologii")
	}
}

// ── R9: fabrykacja liczb ──

func TestR9_LiczbaSpozaSpanuJestOdrzucana(t *testing.T) {
	o := wczytajSeed(t, "cbt")
	res := StageResult{ConstructID: "automatic_thought", Claims: []Claim{{
		ConstructID: "automatic_thought",
		Evidence:    dowody("s1"),
		Status:      StatusObservation,
		Quantities:  []Quantity{{Raw: "80%", SpanID: "s1"}},
	}}}
	got := o.Validate3(res, opcje(Span{ID: "s1", SessionID: "a",
		QuoteVerbatim: "bylem calkiem pewien", Kind: SpanDeclarative}))
	if r := pierwszyPowod(t, got); r != ReasonQuantity {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonQuantity)
	}
}

func TestR9_LiczbaObecnaWSpanie(t *testing.T) {
	o := wczytajSeed(t, "cbt")
	res := StageResult{ConstructID: "automatic_thought", Claims: []Claim{{
		ConstructID: "automatic_thought",
		Evidence:    dowody("s1"),
		Status:      StatusObservation,
		Quantities:  []Quantity{{Raw: "80%", SpanID: "s1"}},
	}}}
	got := o.Validate3(res, opcje(Span{ID: "s1", SessionID: "a",
		QuoteVerbatim: "wierzylem w to jakos na 80 procent", Kind: SpanDeclarative}))
	if len(got.Approved) != 1 {
		t.Errorf("zatwierdzonych %d: %v", len(got.Approved), got.Rejected)
	}
}

func TestR9_WartoscZAplikacjiKlientaNieJestKwestionowana(t *testing.T) {
	o := wczytajSeed(t, "cbt")
	res := StageResult{ConstructID: "automatic_thought", Claims: []Claim{{
		ConstructID: "automatic_thought",
		Evidence:    dowody("s1"),
		Status:      StatusObservation,
		Quantities:  []Quantity{{Raw: "65%", SpanID: "s1", FromEntry: true}},
	}}}
	got := o.Validate3(res, opcje(spanZwykly("s1", "a")))
	if len(got.Approved) != 1 {
		t.Errorf("entry_ref odrzucony: %v", got.Rejected)
	}
}

// ── R10: granica terapeuty ──

func TestR10_TwierdzenieOStanieTerapeutyJestOdrzucane(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "current_conflict", Claims: []Claim{{
		ConstructID:        "current_conflict",
		Evidence:           dowody("s1", "s2"),
		Status:             StatusInterpretation,
		SubjectIsTherapist: true,
	}}}
	got := o.Validate3(res, opcje(spanZwykly("s1", "a"), spanZwykly("s2", "b")))
	if r := pierwszyPowod(t, got); r != ReasonTherapist {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonTherapist)
	}
}

// TestR10_WypowiedzTerapeutyJestLegalnymDowodem — zakaz dotyczy
// twierdzen O terapeucie, nie dowodow OD niego.
func TestR10_WypowiedzTerapeutyJestLegalnymDowodem(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	s := spanZwykly("s1", "a")
	s.ObservedBy = ObservedByTherapist
	res := StageResult{ConstructID: "current_conflict", Claims: []Claim{{
		ConstructID: "current_conflict",
		Evidence:    dowody("s1", "s2"),
		Status:      StatusObservation,
	}}}
	got := o.Validate3(res, opcje(s, spanZwykly("s2", "b")))
	if len(got.Approved) != 1 {
		t.Errorf("obserwacja terapeuty o kliencie odrzucona: %v", got.Rejected)
	}
}

// ── T22: spany ryzyka ──

func TestT22_SpanRyzykaNieZasilaWnioskowania(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	s := spanZwykly("s1", "a")
	s.RiskContent = true
	res := StageResult{ConstructID: "current_conflict", Claims: []Claim{{
		ConstructID: "current_conflict",
		Evidence:    dowody("s1", "s2"),
		Status:      StatusObservation,
	}}}
	got := o.Validate3(res, opcje(s, spanZwykly("s2", "b")))
	if r := pierwszyPowod(t, got); r != ReasonRiskSpan {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonRiskSpan)
	}
}

// ── forced_status ──

func TestForcedStatusJestEgzekwowany(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "inner_conflict", Claims: []Claim{{
		ConstructID: "inner_conflict",
		Evidence:    dowody("s1", "s2"),
		Status:      StatusObservation, // ontologia wymusza hipoteze
	}}}
	// inner_conflict wymaga current_conflict — bez tego R3 zdegradowaloby
	// konstrukt, zanim forced_status doszedlby do glosu.
	opts := opcje(spanZwykly("s1", "a"), spanZwykly("s2", "b"))
	opts.ApprovedConstructs["current_conflict"] = true
	got := o.Validate3(res, opts)
	if r := pierwszyPowod(t, got); r != ReasonForcedStatus {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonForcedStatus)
	}
}

// ── nieznany span ──

func TestNieznanySpanJestOdrzucany(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "current_conflict", Claims: []Claim{{
		ConstructID: "current_conflict",
		Evidence:    dowody("nie_istnieje", "s2"),
		Status:      StatusObservation,
	}}}
	got := o.Validate3(res, opcje(spanZwykly("s2", "b")))
	if r := pierwszyPowod(t, got); r != ReasonUnknownSpan {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonUnknownSpan)
	}
}

func TestInsufficientDataNieJestBledem(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	res := StageResult{ConstructID: "positum", InsufficientData: true}
	got := o.Validate3(res, opcje())
	if len(got.Rejected) != 0 {
		t.Errorf("insufficient_data potraktowane jako blad: %v", got.Rejected)
	}
	if len(got.InsufficientData) != 1 {
		t.Error("insufficient_data nie zostalo odnotowane")
	}
}

// ── F7a-3: prog miedzysesyjny i zakotwiczenie w biezacej sesji ──

// spanZSesji buduje span z jawna sesja i data (kontekst miedzysesyjny).
func spanHistoryczny(id, sesja string, oPrzeszlosci bool) Span {
	s := spanZwykly(id, sesja)
	s.AboutPast = oPrzeszlosci
	return s
}

// min_evidence.sessions BYL NIESPELNIALNY przed F7a: potok widzial
// jedna sesje, wiec konstrukt wymagajacy ciaglosci (Gestalt
// `unfinished_business`: 3 spany z 2 sesji) zawsze konczyl w
// insufficient_data. Ten test pilnuje, ze prog dziala w obie strony.
func TestR2_ProgSesjiSpelnionyKontekstemHistorycznym(t *testing.T) {
	o := wczytajSeed(t, "gestalt")
	opts := opcje(
		spanZwykly("s1", "biezaca"),
		spanZwykly("s2", "biezaca"),
		spanHistoryczny("s0821:s07", "wczesniejsza", false),
	)
	opts.CurrentSessionID = "biezaca"
	opts.ApprovedConstructs["contact_cycle_phase"] = true

	res := StageResult{ConstructID: "unfinished_business", Claims: []Claim{{
		ConstructID: "unfinished_business",
		Evidence:    dowody("s1", "s2", "s0821:s07"),
		Status:      StatusInterpretation,
	}}}
	v := o.Validate3(res, opts)
	if len(v.Approved) != 1 {
		t.Fatalf("twierdzenie odrzucone mimo dwoch sesji w dowodach: %v", v.Rejected)
	}
}

func TestR2_ProgSesjiNiespelnionyBezHistorii(t *testing.T) {
	o := wczytajSeed(t, "gestalt")
	opts := opcje(
		spanZwykly("s1", "biezaca"),
		spanZwykly("s2", "biezaca"),
		spanZwykly("s3", "biezaca"),
	)
	opts.CurrentSessionID = "biezaca"
	opts.ApprovedConstructs["contact_cycle_phase"] = true

	res := StageResult{ConstructID: "unfinished_business", Claims: []Claim{{
		ConstructID: "unfinished_business",
		Evidence:    dowody("s1", "s2", "s3"),
		Status:      StatusInterpretation,
	}}}
	if r := pierwszyPowod(t, o.Validate3(res, opts)); r != ReasonCoverage {
		t.Errorf("powod = %s, oczekiwano %s (trzy spany, ale jedna sesja)",
			r, ReasonCoverage)
	}
}

// Twierdzenie zlozone WYLACZNIE z historii opisuje tamta sesje, nie te.
// Bez tej reguly kontekst miedzysesyjny pozwalalby przepisac stary
// wniosek do dzisiejszego raportu bez ani jednego dowodu z dzisiaj.
func TestR2_TwierdzenieBezSpanuBiezacejSesji(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	opts := opcje(
		spanHistoryczny("s0821:s07", "wczesniejsza", false),
		spanHistoryczny("s0814:s02", "starsza", false),
	)
	opts.CurrentSessionID = "biezaca"

	res := StageResult{ConstructID: "actual_capacity_primary", Claims: []Claim{{
		ConstructID: "actual_capacity_primary",
		Categories:  []string{"zaufanie"},
		Evidence:    dowody("s0821:s07", "s0814:s02"),
		Status:      StatusInterpretation,
	}}}
	if r := pierwszyPowod(t, o.Validate3(res, opts)); r != ReasonNoCurrentSpan {
		t.Errorf("powod = %s, oczekiwano %s", r, ReasonNoCurrentSpan)
	}
}

// Potok jednosesyjny (CurrentSessionID puste) dziala jak przed F7a —
// regula spi, zgodnosc wsteczna zachowana.
func TestR2_ZakotwiczenieSpiBezIdentyfikatoraSesji(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	opts := opcje(spanZwykly("s1", "jakas"), spanZwykly("s2", "jakas"))

	res := StageResult{ConstructID: "actual_capacity_primary", Claims: []Claim{{
		ConstructID: "actual_capacity_primary",
		Categories:  []string{"zaufanie"},
		Evidence:    dowody("s1", "s2"),
		Status:      StatusInterpretation,
	}}}
	if v := o.Validate3(res, opts); len(v.Approved) != 1 {
		t.Fatalf("zgodnosc wsteczna zlamana: %v", v.Rejected)
	}
}

// R5: span historyczny mowiacy WPROST o przeszlosci uzasadnia
// twierdzenie etiologiczne tak samo jak span z dzisiejszej sesji —
// klient opowiedzial o dziecinstwie dwa tygodnie temu, nie dzisiaj.
func TestR5_HistorycznySpanOPrzeszlosciUzasadniaEtiologie(t *testing.T) {
	o := wczytajSeed(t, "ppt")
	opts := opcje(
		spanZwykly("s1", "biezaca"),
		spanHistoryczny("s0814:s02", "starsza", true),
	)
	opts.CurrentSessionID = "biezaca"

	res := StageResult{ConstructID: "actual_capacity_primary", Claims: []Claim{{
		ConstructID: "actual_capacity_primary",
		Categories:  []string{"zaufanie"},
		Evidence:    dowody("s1", "s0814:s02"),
		Status:      StatusInterpretation,
		Etiological: true,
	}}}
	if v := o.Validate3(res, opts); len(v.Approved) != 1 {
		t.Fatalf("etiologia odrzucona mimo historycznego spanu o przeszlosci: %v",
			v.Rejected)
	}
}
