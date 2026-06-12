package rolelabels

import "testing"

func TestGenerate_TherapyPolish(t *testing.T) {
	taken := map[string]int{}
	label, role := Generate("pl-PL", "therapy", "therapist", 1, taken)
	if label != "Terapeuta" || role != "therapist" {
		t.Fatalf("first therapist (pl, therapy): got (%q,%q), want (Terapeuta,therapist)", label, role)
	}
	label, role = Generate("pl-PL", "therapy", "patient", 2, taken)
	if label != "Klient" || role != "patient" {
		t.Fatalf("first patient (pl, therapy): got (%q,%q), want (Klient,patient)", label, role)
	}
}

func TestGenerate_TherapyEnglish(t *testing.T) {
	taken := map[string]int{}
	if got, _ := Generate("en-US", "therapy", "therapist", 1, taken); got != "Therapist" {
		t.Errorf("therapy/therapist en-US: got %q, want Therapist", got)
	}
	if got, _ := Generate("en-US", "therapy", "patient", 2, taken); got != "Client" {
		t.Errorf("therapy/patient en-US: got %q, want Patient", got)
	}
}

func TestGenerate_CoachingPolish(t *testing.T) {
	taken := map[string]int{}
	if got, _ := Generate("pl-PL", "coaching", "therapist", 1, taken); got != "Trener" {
		t.Errorf("coaching/therapist pl-PL: got %q, want Trener", got)
	}
	if got, _ := Generate("pl-PL", "coaching", "patient", 2, taken); got != "Klient" {
		t.Errorf("coaching/patient pl-PL: got %q, want Klient", got)
	}
}

func TestGenerate_CoachingEnglish(t *testing.T) {
	taken := map[string]int{}
	if got, _ := Generate("en-US", "coaching", "therapist", 1, taken); got != "Coach" {
		t.Errorf("coaching/therapist en-US: got %q, want Coach", got)
	}
	if got, _ := Generate("en-US", "coaching", "patient", 2, taken); got != "Client" {
		t.Errorf("coaching/patient en-US: got %q, want Client", got)
	}
}

func TestGenerate_MultiPatient_NumericSuffix(t *testing.T) {
	// Couples therapy: two speakers classified as "patient". First
	// gets the bare label, second gets "Klient 2", third gets
	// "Klient 3", and so on.
	taken := map[string]int{}
	expected := []string{"Klient", "Klient 2", "Klient 3"}
	for i, want := range expected {
		got, role := Generate("pl-PL", "therapy", "patient", i+1, taken)
		if got != want {
			t.Errorf("patient #%d: got %q, want %q", i+1, got, want)
		}
		if role != "patient" {
			t.Errorf("patient #%d claimed role %q, want patient", i+1, role)
		}
	}
}

func TestGenerate_MultiTherapist_NumericSuffix(t *testing.T) {
	// Pathological but possible — model clusters two speakers as
	// therapists. Second gets a numeric suffix.
	taken := map[string]int{}
	if got, _ := Generate("pl-PL", "therapy", "therapist", 1, taken); got != "Terapeuta" {
		t.Errorf("therapist #1: got %q, want Terapeuta", got)
	}
	if got, _ := Generate("pl-PL", "therapy", "therapist", 2, taken); got != "Terapeuta 2" {
		t.Errorf("therapist #2: got %q, want Terapeuta 2", got)
	}
}

func TestGenerate_NonDyadicRoles_FallThrough(t *testing.T) {
	// couple_partner / family_member / third_party / unknown /
	// filler all fall through to speakerlabels.Generate — they're
	// not role-named in this design.
	taken := map[string]int{}
	cases := []struct {
		role string
	}{
		{"couple_partner"},
		{"family_member_parent"},
		{"family_member_sibling"},
		{"third_party"},
		{"unknown"},
		{"filler"},
		{""},
	}
	for _, tc := range cases {
		got, role := Generate("pl-PL", "therapy", tc.role, 3, taken)
		if got != "Osoba 3" {
			t.Errorf("non-dyadic role %q: got %q, want Osoba 3", tc.role, got)
		}
		if role != "" {
			t.Errorf("non-dyadic role %q: claimedRole = %q, want empty (no claim)", tc.role, role)
		}
	}
	if len(taken) != 0 {
		t.Errorf("non-dyadic calls should not mutate takenRoles, got %v", taken)
	}
}

func TestGenerate_UnknownLocale_FallsToEnglish(t *testing.T) {
	taken := map[string]int{}
	if got, _ := Generate("xx-XX", "therapy", "therapist", 1, taken); got != "Therapist" {
		t.Errorf("unknown locale: got %q, want English fallback Therapist", got)
	}
}

func TestGenerate_UnknownModality_FallsToTherapy(t *testing.T) {
	// Empty / garbage modality string should be treated as therapy
	// — the catalog is overwhelmingly clinical and "therapy" is
	// the safer default.
	taken := map[string]int{}
	if got, _ := Generate("pl-PL", "", "therapist", 1, taken); got != "Terapeuta" {
		t.Errorf("empty modality: got %q, want Terapeuta (therapy fallback)", got)
	}
	if got, _ := Generate("pl-PL", "supervision", "patient", 2, taken); got != "Klient" {
		t.Errorf("unknown modality: got %q, want Klient (therapy fallback)", got)
	}
}

func TestGenerate_LanguagePrefix_Match(t *testing.T) {
	// "pl" alone (no region) must hit the same table as "pl-PL".
	taken := map[string]int{}
	if got, _ := Generate("pl", "coaching", "therapist", 1, taken); got != "Trener" {
		t.Errorf("pl-only locale: got %q, want Trener", got)
	}
}

func TestGenerate_NilTakenRoles_Panics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("Generate(nil takenRoles) should panic")
		}
	}()
	_, _ = Generate("pl-PL", "therapy", "therapist", 1, nil)
}

func TestGenerate_CountersIndependent(t *testing.T) {
	// Therapist and patient counters are independent: a session
	// with one therapist + two patients should produce
	// "Terapeuta" + "Klient" + "Klient 2", NOT "Terapeuta" +
	// "Klient" + "Klient 3".
	taken := map[string]int{}
	want := []string{"Terapeuta", "Klient", "Klient 2"}
	roles := []string{"therapist", "patient", "patient"}
	for i, r := range roles {
		got, _ := Generate("pl-PL", "therapy", r, i+1, taken)
		if got != want[i] {
			t.Errorf("speaker %d (%s): got %q, want %q", i+1, r, got, want[i])
		}
	}
}
