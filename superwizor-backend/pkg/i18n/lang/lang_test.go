package lang

import "testing"

func TestBCP47ize(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"", ""},
		{" ", ""},
		{"pl", "pl-PL"},
		{"en", "en-US"},
		{"de", "de-DE"},
		{"es", "es-ES"},
		{"fr", "fr-FR"},
		{"uk", "uk-UA"},
		{"PL", "pl-PL"}, // case-insensitive on 2-char
		{"xx", ""},      // unknown short code → empty (caller falls back)
		// Pre-tagged inputs (Flutter's current default) are case-
		// normalized and returned as-is.
		{"pl-PL", "pl-PL"},
		{"PL-pl", "pl-PL"},
		{"en-GB", "en-GB"}, // distinct region preserved
		{"en-gb", "en-GB"}, // case-normalize
	}
	for _, c := range cases {
		t.Run(c.in, func(t *testing.T) {
			if got := BCP47ize(c.in); got != c.want {
				t.Errorf("BCP47ize(%q) = %q, want %q", c.in, got, c.want)
			}
		})
	}
}

// Pin the static map so a typo (e.g. fr → ff-FR) is caught
// immediately. Add an assertion here whenever a language is added.
func TestDefaultRegionByLanguage_KnownValues(t *testing.T) {
	want := map[string]string{
		"pl": "pl-PL",
		"en": "en-US",
		"de": "de-DE",
		"es": "es-ES",
		"fr": "fr-FR",
		"uk": "uk-UA",
	}
	if len(defaultRegionByLanguage) != len(want) {
		t.Fatalf("map size mismatch: got %d entries, want %d", len(defaultRegionByLanguage), len(want))
	}
	for k, v := range want {
		if defaultRegionByLanguage[k] != v {
			t.Errorf("defaultRegionByLanguage[%q] = %q, want %q", k, defaultRegionByLanguage[k], v)
		}
	}
}
