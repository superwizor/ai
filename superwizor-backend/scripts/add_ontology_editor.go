// Command add_ontology_editor zaklada konto edytora ontologii.
//
// Zakres celowo waski: JEDNA rola, JEDNO konto, bez organizacji i bez
// subskrypcji. Edytor ontologii nie jest terapeuta — nie prowadzi
// kartotek, nie nagrywa sesji, nie ma planu. Ma dostep wylacznie do
// /admin/ontologies (wyjatek sekcyjny w AdminGuard).
//
// HASLA NIE USTAWIAMY. Konto powstaje w Firebase Auth bez hasla, a
// wlasciciel ustawia je sam przez "nie pamietam hasla". Poswiadczenie
// nie przechodzi przez ten skrypt ani przez niczyj terminal.
//
// Uzycie:
//
//	add_ontology_editor -dsn "$DSN" -email osoba@firma.pl -first Imie -last Nazwisko
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"github.com/jackc/pgx/v5"
)

func main() {
	var (
		dsn     = flag.String("dsn", os.Getenv("DATABASE_URL"), "DSN bazy")
		email   = flag.String("email", "", "adres e-mail (wymagane)")
		first   = flag.String("first", "", "imie (wymagane)")
		last    = flag.String("last", "", "nazwisko (wymagane)")
		project = flag.String("project", "superwizor-ai-25ecd", "projekt Firebase")
	)
	flag.Parse()
	if *dsn == "" || *email == "" || *first == "" || *last == "" {
		fmt.Fprintln(os.Stderr, "wymagane: -dsn -email -first -last")
		os.Exit(2)
	}

	ctx := context.Background()
	emailLC := strings.ToLower(strings.TrimSpace(*email))

	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: *project})
	if err != nil {
		fatal("firebase app: %v", err)
	}
	authClient, err := app.Auth(ctx)
	if err != nil {
		fatal("firebase auth: %v", err)
	}

	// Konto w Firebase Auth — bez hasla.
	var uid string
	if u, err := authClient.GetUserByEmail(ctx, emailLC); err == nil {
		uid = u.UID
		fmt.Printf("Firebase Auth: konto juz istnieje (UID %s)\n", uid)
	} else {
		created, err := authClient.CreateUser(ctx, (&auth.UserToCreate{}).
			Email(emailLC).
			DisplayName(*first+" "+*last).
			EmailVerified(true))
		if err != nil {
			fatal("firebase create user: %v", err)
		}
		uid = created.UID
		fmt.Printf("Firebase Auth: konto utworzone (UID %s), BEZ hasla\n", uid)
	}

	conn, err := pgx.Connect(ctx, *dsn)
	if err != nil {
		fatal("baza: %v", err)
	}
	defer conn.Close(ctx)

	var existingID, existingRole string
	err = conn.QueryRow(ctx,
		`SELECT id::text, role::text FROM users WHERE lower(email) = $1`, emailLC).
		Scan(&existingID, &existingRole)
	switch {
	case err == nil:
		// Konto istnieje — podnosimy role zamiast tworzyc duplikat.
		if existingRole == "ONTOLOGY_EDITOR" {
			fmt.Printf("Baza: uzytkownik juz ma role ONTOLOGY_EDITOR (%s)\n", existingID)
		} else {
			if _, err := conn.Exec(ctx,
				`UPDATE users SET role = 'ONTOLOGY_EDITOR' WHERE id = $1::uuid`, existingID); err != nil {
				fatal("zmiana roli: %v", err)
			}
			fmt.Printf("Baza: rola %s -> ONTOLOGY_EDITOR (%s)\n", existingRole, existingID)
		}
	case errors.Is(err, pgx.ErrNoRows):
		var newID string
		err = conn.QueryRow(ctx, `
			INSERT INTO users (role, firebase_uid, email, first_name, last_name,
			                   is_email_verified, has_accepted_tos)
			VALUES ('ONTOLOGY_EDITOR', $1, $2, $3, $4, TRUE, TRUE)
			RETURNING id::text`, uid, emailLC, *first, *last).Scan(&newID)
		if err != nil {
			fatal("insert users: %v", err)
		}
		fmt.Printf("Baza: uzytkownik utworzony z rola ONTOLOGY_EDITOR (%s)\n", newID)
	default:
		fatal("odczyt users: %v", err)
	}

	fmt.Println()
	fmt.Println("Konto NIE ma hasla. Wlasciciel ustawia je sam:")
	fmt.Println("  superwizor.ai -> logowanie -> \"nie pamietam hasla\"")
	fmt.Println("Dostep: wylacznie /admin/ontologies.")
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
