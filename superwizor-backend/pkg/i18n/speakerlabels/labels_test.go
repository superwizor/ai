package speakerlabels

import "testing"

func TestGenerate(t *testing.T) {
	tests := []struct {
		locale   string
		tag      int
		expected string
	}{
		{"pl-PL", 1, "Osoba 1"},
		{"pl", 2, "Osoba 2"},
		{"en-US", 1, "Person 1"},
		{"cmn-CN", 1, "说话人 1"},
		{"unknown", 3, "Speaker 3"}, // fallback
		{"", 1, "Speaker 1"},        // fallback empty
	}

	for _, tc := range tests {
		got := Generate(tc.locale, tc.tag)
		if got != tc.expected {
			t.Errorf("Generate(%q, %d) = %q; want %q", tc.locale, tc.tag, got, tc.expected)
		}
	}
}
