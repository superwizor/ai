// Command ontology-seed importuje pliki seedowe ontologii do bazy jako
// wersje `draft` (plan 16, faza F1).
//
// # Dlaczego komenda, a nie migracja
//
// Plan zakladal import migracja. Migracja nie wie jednak, KTO ja
// uruchamia, a `ontology_versions.created_by` jest NOT NULL i niesie
// znaczenie: na nim opiera sie four-eyes (approved_by <> created_by).
// Import "bez autora" wymagalby rozluznienia tej kolumny do NULL, a
// wtedy warunek CHECK przechodzi zawsze i przeglad staje sie pozorny
// dla wlasnie tych wersji, od ktorych zaczyna sie praca ekspercka.
//
// Komenda przyjmuje wiec -actor i zapisuje realna osobe. Skutek jest
// zamierzony: kto zaimportowal seed, ten NIE moze go zatwierdzic.
// Pierwsza wersja kazdej ontologii przechodzi przez dwie pary oczu tak
// samo jak kazda nastepna.
//
// Uruchomienie jest idempotentne: istniejaca para (modalnosc, wersja)
// jest pomijana, wiec ponowny import po dodaniu nowej modalnosci nie
// dubluje niczego i nie nadpisuje pracy ekspertow.
//
// Uzycie:
//
//	ontology-seed -dsn "$DSN" -actor osoba@firma.pl [-dir ../../ontology] [-dry-run]
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

func main() {
	var (
		dsn    = flag.String("dsn", os.Getenv("DATABASE_URL"), "DSN bazy (domyslnie DATABASE_URL)")
		actor  = flag.String("actor", "", "e-mail osoby importujacej (wymagane)")
		dir    = flag.String("dir", "ontology", "katalog z seedami")
		dryRun = flag.Bool("dry-run", false, "pokaz, co zostaloby zrobione, bez zapisu")
	)
	flag.Parse()

	if *dsn == "" || *actor == "" {
		fmt.Fprintln(os.Stderr, "wymagane: -dsn oraz -actor")
		flag.Usage()
		os.Exit(2)
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, *dsn)
	if err != nil {
		fatal("polaczenie z baza: %v", err)
	}
	defer pool.Close()

	actorID, err := resolveActor(ctx, pool, *actor)
	if err != nil {
		fatal("%v", err)
	}
	fmt.Printf("Importujacy: %s (%s)\n", *actor, actorID)
	if *dryRun {
		fmt.Println("TRYB PROBNY — nic nie zostanie zapisane")
	}
	fmt.Println()

	files, err := collectSeeds(*dir)
	if err != nil {
		fatal("odczyt katalogu %s: %v", *dir, err)
	}
	if len(files) == 0 {
		// Pusty wynik to prawie zawsze zla sciezka, nie pusty katalog.
		fatal("nie znaleziono plikow .yaml w %s", *dir)
	}

	var imported, skipped, failed int
	for _, f := range files {
		status, err := importSeed(ctx, pool, f, actorID, *dryRun)
		switch {
		case err != nil:
			fmt.Printf("BLAD    %-34s %v\n", filepath.Base(filepath.Dir(f))+"/"+filepath.Base(f), err)
			failed++
		case status == statusSkipped:
			fmt.Printf("POMINIETO %-32s wersja juz istnieje\n", filepath.Base(filepath.Dir(f))+"/"+filepath.Base(f))
			skipped++
		default:
			fmt.Printf("OK      %-34s zaimportowano jako draft\n", filepath.Base(filepath.Dir(f))+"/"+filepath.Base(f))
			imported++
		}
	}

	fmt.Printf("\nzaimportowano: %d, pominieto: %d, bledow: %d\n", imported, skipped, failed)
	if failed > 0 {
		os.Exit(1)
	}
	if imported > 0 && !*dryRun {
		fmt.Println("\nNastepny krok: eksperci pracuja w /admin/ontologies.")
		fmt.Println("Uwaga: importujacy NIE moze zatwierdzic tych wersji (four-eyes).")
	}
}

type seedStatus int

const (
	statusImported seedStatus = iota
	statusSkipped
)

func importSeed(ctx context.Context, pool *pgxpool.Pool, path string, actorID uuid.UUID, dryRun bool) (seedStatus, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return statusImported, err
	}
	// Load, nie Parse: do bazy nie wchodzi tresc, ktora nie przechodzi
	// metaschematu. Ten sam walidator co lint w CI i co zapis w Studiu.
	o, err := ontology.Load(data)
	if err != nil {
		return statusImported, err
	}
	if o.IsApproved() {
		return statusImported, fmt.Errorf(
			"seed ma niepuste approved_by — autoryzacja nalezy do przeplywu Studia")
	}

	systemCode := strings.ToUpper(o.Modality)
	var modalityID uuid.UUID
	err = pool.QueryRow(ctx,
		`SELECT id FROM modalities WHERE system_code = $1`, systemCode).Scan(&modalityID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return statusImported, fmt.Errorf("brak modalnosci o system_code %q", systemCode)
		}
		return statusImported, err
	}

	var exists bool
	if err := pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM ontology_versions WHERE modality_id=$1 AND version=$2)`,
		modalityID, o.Version).Scan(&exists); err != nil {
		return statusImported, err
	}
	if exists {
		return statusSkipped, nil
	}
	if dryRun {
		return statusImported, nil
	}

	note := fmt.Sprintf("Import seeda z repozytorium (%s). Szkielet do autoryzacji eksperckiej — "+
		"wszystkie katalogi wartosci i progi min_evidence sa placeholderami.", filepath.Base(path))
	_, err = pool.Exec(ctx, `
		INSERT INTO ontology_versions
		    (modality_id, version, content, status, created_by, change_note, construct_count)
		VALUES ($1, $2, $3, 'draft', $4, $5, $6)`,
		modalityID, o.Version, string(data), actorID, note, len(o.Constructs))
	return statusImported, err
}

// resolveActor zamienia e-mail na identyfikator uzytkownika.
//
// Wymagamy roli uprawniajacej do Studia — inaczej import stworzylby
// wersje, ktorej autor nie moze jej nawet otworzyc, a four-eyes
// blokowaloby ja przed nim samym bez zadnej korzysci.
func resolveActor(ctx context.Context, pool *pgxpool.Pool, email string) (uuid.UUID, error) {
	var id uuid.UUID
	var role string
	err := pool.QueryRow(ctx,
		`SELECT id, role::text FROM users WHERE lower(email) = lower($1) AND deleted_at IS NULL`,
		email).Scan(&id, &role)
	if err != nil {
		if err == pgx.ErrNoRows {
			return uuid.Nil, fmt.Errorf("nie znaleziono uzytkownika %q", email)
		}
		return uuid.Nil, err
	}
	if role != "ONTOLOGY_EDITOR" && role != "SUPERWIZOR_ADMIN" {
		return uuid.Nil, fmt.Errorf(
			"uzytkownik %q ma role %s — import wymaga ONTOLOGY_EDITOR albo SUPERWIZOR_ADMIN",
			email, role)
	}
	return id, nil
}

func collectSeeds(dir string) ([]string, error) {
	matches, err := filepath.Glob(filepath.Join(dir, "*", "*.yaml"))
	if err != nil {
		return nil, err
	}
	out := make([]string, 0, len(matches))
	for _, m := range matches {
		// _meta to metaschemat — dokumentacja formatu, nie ontologia.
		if strings.Contains(m, string(filepath.Separator)+"_meta"+string(filepath.Separator)) {
			continue
		}
		out = append(out, m)
	}
	sort.Strings(out)
	return out, nil
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
