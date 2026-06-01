package actionplan

import "testing"

func TestExtract(t *testing.T) {
	tests := []struct {
		name     string
		markdown string
		want     string
	}{
		{
			name: "polish heading captures body, cleans markdown and stops at next same-level heading",
			markdown: `# Raport sesji

## Podsumowanie
Klient był spokojny.

## Plan działania klienta
- **Ćwiczenie oddechowe** codziennie rano
- Prowadzić [dziennik](https://example.com/d) myśli

## Ryzyko
Brak.`,
			want: "• Ćwiczenie oddechowe codziennie rano\n\n• Prowadzić dziennik myśli",
		},
		{
			name: "english heading is matched accent/case-insensitively",
			markdown: `# Session report

### Action Plan
Practice grounding once a day.

### Notes
done`,
			want: "Practice grounding once a day.",
		},
		{
			name: "no matching heading returns empty",
			markdown: `# Report

## Summary
Nothing actionable here.`,
			want: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Extract(tt.markdown)
			if got != tt.want {
				t.Errorf("Extract() =\n%q\nwant\n%q", got, tt.want)
			}
		})
	}
}
