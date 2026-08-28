package grpc

import (
	"math"
	"testing"
	"time"

	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// Kotwice kalendarza ISO sprawdzalne bez uruchamiania kodu:
// rok ISO 2026 zaczyna się w poniedziałek 29.12.2025 (bo 4.01.2026 wypada
// w niedzielę i z definicji leży w tygodniu 1), ma 53 tygodnie — 1.01.2026
// to czwartek — a tydzień 53 zaczyna się 28.12.2026. Rok ISO 2027 startuje
// dopiero 4.01.2027.
func TestISOWeekStart(t *testing.T) {
	cases := []struct {
		year, week int
		want       string
	}{
		{2026, 1, "2025-12-29"},
		{2026, 34, "2026-08-17"},
		{2026, 53, "2026-12-28"},
		{2027, 1, "2027-01-04"},
	}
	for _, c := range cases {
		got := isoWeekStart(c.year, c.week).Format("2006-01-02")
		if got != c.want {
			t.Errorf("isoWeekStart(%d, %d) = %s, chciano %s", c.year, c.week, got, c.want)
		}
		if wd := isoWeekStart(c.year, c.week).Weekday(); wd != time.Monday {
			t.Errorf("isoWeekStart(%d, %d) wypadł w %s, a początek tygodnia ISO to poniedziałek", c.year, c.week, wd)
		}
	}
}

func TestParseISOWeek(t *testing.T) {
	if y, w, ok := parseISOWeek("2026-34"); !ok || y != 2026 || w != 34 {
		t.Errorf(`parseISOWeek("2026-34") = (%d, %d, %v)`, y, w, ok)
	}
	// Etykiety, których panel nie powinien wpuścić do rachunków. Poprzednia
	// wersja ignorowała błąd Sscanf i zwracała (0, 0) jako prawidłowy wynik.
	for _, bad := range []string{"", "2026", "styczeń", "2026-00", "2026-54", "MM-DD"} {
		if _, _, ok := parseISOWeek(bad); ok {
			t.Errorf("parseISOWeek(%q) przyjęte, a nie jest etykietą IYYY-IW", bad)
		}
	}
}

// Regresja na błąd, przez który KPI „Retencja 30-dniowa" mierzyło zły tydzień:
// stara formuła (wy-cy)*52 + (ww-cw) zakłada 52 tygodnie w roku, a 2026 ma 53.
func TestWeekDiff_PrzelomRoku(t *testing.T) {
	cases := []struct {
		cohort, week string
		want         int
		staraFormula int
	}{
		{"2026-30", "2026-34", 4, 4},
		// Tydzień 53/2026 sąsiaduje z 1/2027 — odległość to 1, nie 0.
		{"2026-53", "2027-01", 1, 0},
		// Przez przełom roku: 51 → 52 → 53 → 01 → 02 to cztery tygodnie.
		{"2026-51", "2027-02", 4, 3},
	}
	for _, c := range cases {
		got, ok := weekDiff(c.cohort, c.week)
		if !ok {
			t.Fatalf("weekDiff(%q, %q) odrzuciło poprawne etykiety", c.cohort, c.week)
		}
		if got != c.want {
			t.Errorf("weekDiff(%q, %q) = %d, chciano %d", c.cohort, c.week, got, c.want)
		}
		if c.want != c.staraFormula && got == c.staraFormula {
			t.Errorf("weekDiff(%q, %q) nadal liczy starą formułą (%d)", c.cohort, c.week, c.staraFormula)
		}
	}
	if _, ok := weekDiff("nonsens", "2026-34"); ok {
		t.Error("weekDiff przyjęło zepsutą etykietę kohorty")
	}
}

func TestRetention30d(t *testing.T) {
	// Piątek 28.08.2026, czyli tydzień ISO 35. Kohorta jest „dojrzała", gdy
	// jej tydzień +4 zdążył się skończyć.
	now := time.Date(2026, 8, 28, 12, 0, 0, 0, time.UTC)

	rows := []db.GetRetentionCohortsRow{
		// Kohorta jednoosobowa ze 100% w tygodniu +4.
		{Cohort: "2026-10", Week: "2026-10", Pct: 100, CohortSize: 1},
		{Cohort: "2026-10", Week: "2026-14", Pct: 100, CohortSize: 1},
		// Kohorta pięćdziesięcioosobowa z 10% w tygodniu +4.
		{Cohort: "2026-20", Week: "2026-20", Pct: 100, CohortSize: 50},
		{Cohort: "2026-20", Week: "2026-24", Pct: 10, CohortSize: 50},
		// Dojrzała, ale BEZ wiersza w tygodniu +4 — nikt nie wrócił. Musi
		// wejść do mianownika z zerem, a nie zniknąć z rachunku.
		{Cohort: "2026-30", Week: "2026-30", Pct: 100, CohortSize: 10},
		// Kohorta, z której NIKT nigdy nie nagrał sesji. LEFT JOIN w
		// GetRetentionCohorts oddaje ją z pustym `week` — musi wejść do
		// mianownika z zerem, inaczej KPI jest zawyżone.
		{Cohort: "2026-25", Week: "", Pct: 0, CohortSize: 30},
		// Zarejestrowani w tym tygodniu — ich tydzień +4 jeszcze nie minął,
		// więc brak aktywności znaczy „za wcześnie", nie „nie wrócili".
		{Cohort: "2026-35", Week: "2026-35", Pct: 100, CohortSize: 7},
	}

	// (100*1 + 10*50 + 0*10 + 0*30) / (1 + 50 + 10 + 30) = 600 / 91
	want := 600.0 / 91.0
	got := retention30d(rows, now)
	if math.Abs(got-want) > 1e-9 {
		t.Errorf("retention30d = %.4f, chciano %.4f", got, want)
	}

	// Stara, nieważona średnia po kohortach z wierszem w +4 dałaby
	// (100 + 10) / 2 = 55 — czyli prawie sześciokrotnie za dużo.
	if math.Abs(got-55.0) < 1.0 {
		t.Errorf("retention30d = %.4f — to nadal nieważona średnia po kohortach", got)
	}

	if r := retention30d(nil, now); r != 0 {
		t.Errorf("retention30d(nil) = %v, chciano 0", r)
	}
}
