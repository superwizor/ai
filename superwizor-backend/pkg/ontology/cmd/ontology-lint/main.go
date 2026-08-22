// Command ontology-lint waliduje pliki seedowe ontologii w repozytorium.
//
// Od planu 16 v1.2 zrodlem prawdy runtime jest aktywna wersja w bazie, a
// pliki `ontology/<modality>/<semver>.yaml` sa seedami i dokumentacja
// formatu. Ten lint pilnuje, zeby seed, ktory kiedys zostanie
// zaimportowany jako draft, byl od poczatku poprawny — i zeby CI
// zatrzymywalo zepsuty plik w PR, nie dopiero w Studio.
//
// Uzycie: ontology-lint <sciezka>...   (katalogi przechodzone rekurencyjnie)
package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/superwizor-ai/backend/pkg/ontology"
)

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "uzycie: ontology-lint <sciezka>...")
		os.Exit(2)
	}

	files, err := collect(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "blad wejscia: %v\n", err)
		os.Exit(2)
	}
	if len(files) == 0 {
		// Brak plikow to prawie zawsze zla sciezka w konfiguracji CI, a
		// nie pusty katalog. Cicha zielona bramka jest gorsza niz brak
		// bramki, bo tworzy falszywe poczucie pokrycia.
		fmt.Fprintln(os.Stderr, "nie znaleziono plikow .yaml — sprawdz sciezke")
		os.Exit(2)
	}

	failed := 0
	for _, f := range files {
		if problems := lintFile(f); len(problems) > 0 {
			failed++
			fmt.Printf("BLAD %s (%d):\n", f, len(problems))
			for _, p := range problems {
				fmt.Printf("   - %s\n", p)
			}
			continue
		}
		fmt.Printf("OK   %s\n", f)
	}

	fmt.Printf("\nsprawdzono %d plik(ow), niepoprawnych: %d\n", len(files), failed)
	if failed > 0 {
		os.Exit(1)
	}
}

func lintFile(path string) []string {
	data, err := os.ReadFile(path)
	if err != nil {
		return []string{fmt.Sprintf("odczyt: %v", err)}
	}
	o, err := ontology.Parse(data)
	if err != nil {
		return []string{err.Error()}
	}
	problems := o.Validate()

	// Seed z niepustym approved_by udawalby autoryzacje, ktorej nie bylo.
	// Autoryzacja zyje w bazie (status `approved` + four-eyes w Studio),
	// wiec plik w repo nie moze jej deklarowac.
	if o.IsApproved() {
		problems = append(problems,
			"approved_by musi byc puste w seedzie — autoryzacja nalezy do Ontology Studio")
	}

	// Katalog musi zgadzac sie z modalnoscia: ontology/ppt/0.1.0.yaml
	// deklarujacy `modality: cbt` zaimportowalby sie pod zla modalnosc.
	if dir := filepath.Base(filepath.Dir(path)); dir != "" && dir != "." && o.Modality != dir {
		problems = append(problems,
			fmt.Sprintf("modality %q nie zgadza sie z katalogiem %q", o.Modality, dir))
	}

	// To samo dla nazwy pliku i semver.
	name := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	if o.Version != name {
		problems = append(problems,
			fmt.Sprintf("version %q nie zgadza sie z nazwa pliku %q", o.Version, name))
	}
	return problems
}

// collect rozwija katalogi do plikow .yaml, pomijajac _meta (metaschemat
// jest dokumentacja formatu, nie ontologia — nie ma konstruktow).
func collect(paths []string) ([]string, error) {
	var out []string
	for _, p := range paths {
		info, err := os.Stat(p)
		if err != nil {
			return nil, err
		}
		if !info.IsDir() {
			out = append(out, p)
			continue
		}
		err = filepath.WalkDir(p, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				if d.Name() == "_meta" {
					return fs.SkipDir
				}
				return nil
			}
			if strings.HasSuffix(path, ".yaml") || strings.HasSuffix(path, ".yml") {
				out = append(out, path)
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	return out, nil
}
