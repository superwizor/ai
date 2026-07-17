package pseudonymize

import (
	"strings"
	"testing"
)

func apply(t *testing.T, entities []Entity, text string) (string, Stats) {
	t.Helper()
	r := NewReplacer(entities)
	return r.Apply(text)
}

// Kanoniczny przypadek z docs/41 §3.1: imiona zostają, nazwisko po
// imieniu znika bez tokenu, nazwisko solo dostaje token, odmiana kryta
// przez formy z # PII.
func TestSurnames_FirstNamesStay(t *testing.T) {
	entities := []Entity{{
		Placeholder: "[NAZWISKO-1]",
		Forms:       []string{"Nowak", "Nowaka", "Nowakiem", "Nowak"},
	}}
	in := "Anna Nowak mówiła o mężu. Rozmowa z Nowakiem była trudna. " +
		"Pani Nowak wróciła do tematu. Nowakowski to inna osoba."
	out, st := apply(t, entities, in)

	if strings.Contains(out, "Nowakiem") || strings.Contains(strings.ReplaceAll(out, "Nowakowski", ""), "Nowak") {
		t.Fatalf("surname leaked: %q", out)
	}
	// Imię zostaje, token po imieniu skolapsowany.
	if !strings.Contains(out, "Anna mówiła") {
		t.Errorf("full name should read as bare first name, got: %q", out)
	}
	// "Pani Nowak" → "Pani" (kolaps po kapitalizowanym słowie jest OK).
	if !strings.Contains(out, "Pani wróciła") {
		t.Errorf("want 'Pani wróciła', got: %q", out)
	}
	// Nazwisko solo (odmienione, po małej literze) → token zostaje.
	if !strings.Contains(out, "z [NAZWISKO-1]") {
		t.Errorf("standalone inflected surname must keep the token, got: %q", out)
	}
	// "Nowakowski" — inne słowo, granice słów muszą je ochronić.
	if !strings.Contains(out, "Nowakowski") {
		t.Errorf("word boundaries violated (Nowakowski), got: %q", out)
	}
	if st.Replacements == 0 {
		t.Error("expected entity replacements")
	}
}

func TestEmployersSchoolsLocalities(t *testing.T) {
	entities := []Entity{
		{Placeholder: "[PRACODAWCA]", Forms: []string{"Softex", "Softexie"}},
		{Placeholder: "[SZKOŁA]", Forms: []string{"SP 12", "dwunastce"}},
		{Placeholder: "[MIEJSCOWOŚĆ-A]", Forms: []string{"Wrocław", "Wrocławiu"}},
	}
	in := "Pracuje w Softexie we Wrocławiu, syn chodzi do SP 12, o dwunastce mówi dobrze."
	out, _ := apply(t, entities, in)
	for _, leaked := range []string{"Softex", "Wrocław", "SP 12", "dwunastce"} {
		if strings.Contains(out, leaked) {
			t.Errorf("leaked %q in %q", leaked, out)
		}
	}
	for _, want := range []string{"[PRACODAWCA]", "[SZKOŁA]", "[MIEJSCOWOŚĆ-A]"} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %s in %q", want, out)
		}
	}
}

// Warstwa regex działa nawet przy pustej liście encji (privacy floor).
func TestRegexLayer_AlwaysOn(t *testing.T) {
	in := "PESEL 85010212345, tel. +48 601 234 567, mail jan.k@example.com, " +
		"kod 50-540, dowód ABC 123456."
	out, st := apply(t, nil, in)
	for _, leaked := range []string{"85010212345", "601 234 567", "jan.k@example.com", "50-540", "ABC 123456"} {
		if strings.Contains(out, leaked) {
			t.Errorf("regex layer leaked %q in %q", leaked, out)
		}
	}
	if st.RegexReplacements < 5 {
		t.Errorf("RegexReplacements = %d, want >= 5 (%q)", st.RegexReplacements, out)
	}
}

func TestLongestMatchFirst(t *testing.T) {
	entities := []Entity{
		{Placeholder: "[PRACODAWCA]", Forms: []string{"Bank Polski", "Banku Polskim"}},
		{Placeholder: "[NAZWISKO-1]", Forms: []string{"Polski"}},
	}
	out, _ := apply(t, entities, "Pracuje w Banku Polskim od lat.")
	if !strings.Contains(out, "[PRACODAWCA]") || strings.Contains(out, "[NAZWISKO-1]") {
		t.Errorf("longest form must win: %q", out)
	}
}

func TestCollisions_FirstEntityWins(t *testing.T) {
	entities := []Entity{
		{Placeholder: "[NAZWISKO-1]", Forms: []string{"Karol"}},
		{Placeholder: "[NAZWISKO-2]", Forms: []string{"Karol"}},
	}
	r := NewReplacer(entities)
	out, st := r.Apply("Karol przyszedł.")
	if !strings.Contains(out, "[NAZWISKO-1]") {
		t.Errorf("first entity must win: %q", out)
	}
	if st.Collisions != 1 {
		t.Errorf("Collisions = %d, want 1", st.Collisions)
	}
}

func TestUnmatchedForms_Reported(t *testing.T) {
	entities := []Entity{{Placeholder: "[NAZWISKO-1]", Forms: []string{"Kowalski", "Kowalskiego"}}}
	r := NewReplacer(entities)
	_, _ = r.Apply("Rozmowa o Kowalskim nie padła — tu jest tylko Kowalski.")
	_, st := r.Apply("Druga porcja tekstu bez nazwisk.")
	if len(st.UnmatchedForms) != 1 || st.UnmatchedForms[0] != "Kowalskiego" {
		t.Errorf("UnmatchedForms = %v, want [Kowalskiego]", st.UnmatchedForms)
	}
}

func TestCaseInsensitiveAndUnicode(t *testing.T) {
	entities := []Entity{{Placeholder: "[MIEJSCOWOŚĆ-A]", Forms: []string{"Łódź", "Łodzi"}}}
	out, _ := apply(t, entities, "mieszka w łodzi; ŁÓDŹ wspomina ciepło")
	if strings.Contains(strings.ToLower(out), "łod") || strings.Contains(strings.ToLower(out), "łód") {
		t.Errorf("case-insensitive unicode match failed: %q", out)
	}
}

func TestEmptyAndNoop(t *testing.T) {
	r := NewReplacer(nil)
	out, st := r.Apply("")
	if out != "" || st.Replacements != 0 {
		t.Error("empty input must be a no-op")
	}
	out2, _ := r.Apply("Zwykły tekst bez PII.")
	if out2 != "Zwykły tekst bez PII." {
		t.Errorf("clean text must pass through unchanged: %q", out2)
	}
}
