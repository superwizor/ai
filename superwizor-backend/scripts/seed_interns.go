package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type Intern struct {
	Email     string
	FirstName string
	LastName  string
}

func main() {
	ctx := context.Background()
	projectID := "superwizor-ai-25ecd"
	defaultPassword := "SuperwizorApple2026!"

	interns := []Intern{
		{Email: "mwjanta@gmail.com", FirstName: "Magdalena", LastName: "Janta"},
		{Email: "Jagoda.sanecka@student.uj.edu.pl", FirstName: "Jagoda", LastName: "Sanecka"},
		{Email: "wiktoria.jaworska@student.uj.edu.pl", FirstName: "Wiktoria", LastName: "Jaworska"},
		{Email: "dominika.joanna.walczak@student.uj.edu.pl", FirstName: "Dominika", LastName: "Walczak"},
		{Email: "jakub.giza@student.uj.edu.pl", FirstName: "Jakub", LastName: "Giza"},
		{Email: "olga.zawadzka@student.uj.edu.pl", FirstName: "Olga", LastName: "Zawadzka"},
		{Email: "anna.d.szczepaniak@gmail.com", FirstName: "Anna", LastName: "Szczepaniak"},
		{Email: "zawadzk.olga@gmail.com", FirstName: "Olga", LastName: "Zawadzka"},
		{Email: "wiktoriajaworska64@gmail.com", FirstName: "Wiktoria", LastName: "Jaworska"},
		{Email: "domiwal10@gmail.com", FirstName: "Dominika", LastName: "Walczak"},
		{Email: "kubagiza1234@gmail.com", FirstName: "Jakub", LastName: "Giza"},
	}

	// 1. Initialize Firebase Admin SDK
	fmt.Println("🔑 Inicjalizacja Firebase Admin SDK dla projektu:", projectID)
	conf := &firebase.Config{ProjectID: projectID}
	app, err := firebase.NewApp(ctx, conf)
	if err != nil {
		log.Fatalf("❌ Błąd inicjalizacji Firebase App: %v", err)
	}

	authClient, err := app.Auth(ctx)
	if err != nil {
		log.Fatalf("❌ Błąd inicjalizacji Firebase Auth Client: %v", err)
	}

	// 2. Connect to database
	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		// Domyślny DSN dla stagingu (znaleziony w lokalnych skryptach uruchomieniowych)
		dbDSN = "postgres://superwizor_app:%7B%3DjDj%3D%3AG6Q%5DehAvs4mpet%2A0K%2B%5DP%26Ks%7B8@34.118.34.144:5432/superwizor?sslmode=require"
	}
	fmt.Println("🗄️ Łączenie z bazą danych...")
	conn, err := pgx.Connect(ctx, dbDSN)
	if err != nil {
		log.Fatalf("❌ Błąd połączenia z bazą danych: %v\nUpewnij się, że masz połączenie sieciowe lub podaj DATABASE_URL.", err)
	}
	defer conn.Close(ctx)

	// Pobierz domyślną modalność i ID planu PRO
	var defaultModalityID pgtype.UUID
	err = conn.QueryRow(ctx, "SELECT id FROM modalities LIMIT 1").Scan(&defaultModalityID)
	if err != nil {
		fmt.Printf("⚠️ Ostrzeżenie: nie znaleziono żadnej modalności w bazie: %v\n", err)
	}

	var planID string
	var planLimit int32
	err = conn.QueryRow(ctx, "SELECT id, tokens_per_period FROM subscription_plans WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = true LIMIT 1").
		Scan(&planID, &planLimit)
	if err != nil {
		log.Fatalf("❌ Błąd wyszukiwania planu PRO (Rozkwit) w bazie: %v", err)
	}
	fmt.Printf("🌸 Znaleziono plan PRO (Rozkwit) w bazie. Limit tokenów: %d\n", planLimit)

	fmt.Println("\n🚀 Rozpoczynanie procesu rejestracji stażystów...")
	fmt.Println("--------------------------------------------------------------------------------")

	for _, intern := range interns {
		emailLC := strings.ToLower(strings.TrimSpace(intern.Email))
		fmt.Printf("👤 Rejestracja: %s %s (%s)\n", intern.FirstName, intern.LastName, emailLC)

		// A. Firebase Auth
		var firebaseUID string
		u, err := authClient.GetUserByEmail(ctx, emailLC)
		if err == nil {
			firebaseUID = u.UID
			fmt.Printf("   ℹ️ Użytkownik już istnieje w Firebase Auth (UID: %s)\n", firebaseUID)
		} else {
			// Tworzymy nowego użytkownika
			params := (&auth.UserToCreate{}).
				Email(emailLC).
				Password(defaultPassword).
				DisplayName(intern.FirstName + " " + intern.LastName).
				EmailVerified(true)

			newUser, errCreate := authClient.CreateUser(ctx, params)
			if errCreate != nil {
				fmt.Printf("   ❌ Błąd tworzenia użytkownika w Firebase: %v. Pomijanie.\n\n", errCreate)
				continue
			}
			firebaseUID = newUser.UID
			fmt.Printf("   ✅ Utworzono konto w Firebase Auth (UID: %s)\n", firebaseUID)
		}

		// B. Database Transaction
		tx, err := conn.Begin(ctx)
		if err != nil {
			fmt.Printf("   ❌ Błąd rozpoczęcia transakcji DB: %v. Pomijanie.\n\n", err)
			continue
		}

		var userID string
		var orgID string
		var subID string

		err = tx.QueryRow(ctx, "SELECT id, organization_id FROM users WHERE email = $1", emailLC).Scan(&userID, &orgID)
		if err == pgx.ErrNoRows {
			// Nowy użytkownik w bazie danych
			addressID := ""
			err = tx.QueryRow(ctx, "SELECT gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()").Scan(&userID, &orgID, &subID, &addressID)
			if err != nil {
				fmt.Printf("   ❌ Błąd generowania UUID: %v. Wycofywanie.\n\n", err)
				_ = tx.Rollback(ctx)
				continue
			}

			// 1. Adres
			_, err = tx.Exec(ctx, `
				INSERT INTO addresses (id, country_code, region, city, postal_code, street_line, building_number)
				VALUES ($1, 'PL', 'małopolskie', 'Kraków', '31-007', 'Rynek Główny', '1')`,
				addressID,
			)
			if err != nil {
				fmt.Printf("   ❌ Błąd zapisu adresu: %v. Wycofywanie.\n\n", err)
				_ = tx.Rollback(ctx)
				continue
			}

			// 2. Organizacja
			legalName := fmt.Sprintf("Indywidualna Praktyka - %s %s", intern.FirstName, intern.LastName)
			_, err = tx.Exec(ctx, `
				INSERT INTO organizations (id, legal_name, headquarters_address_id, type)
				VALUES ($1, $2, $3, 'SOLO')`,
				orgID, legalName, addressID,
			)
			if err != nil {
				fmt.Printf("   ❌ Błąd zapisu organizacji: %v. Wycofywanie.\n\n", err)
				_ = tx.Rollback(ctx)
				continue
			}

			// 3. Użytkownik
			_, err = tx.Exec(ctx, `
				INSERT INTO users (id, role, organization_id, firebase_uid, email, first_name, last_name, ui_language, timezone, has_accepted_tos, default_modality_id, is_active)
				VALUES ($1, 'THERAPIST', $2, $3, $4, $5, $6, 'pl', 'Europe/Warsaw', true, $7, true)`,
				userID, orgID, firebaseUID, emailLC, intern.FirstName, intern.LastName, defaultModalityID,
			)
			if err != nil {
				fmt.Printf("   ❌ Błąd zapisu użytkownika: %v. Wycofywanie.\n\n", err)
				_ = tx.Rollback(ctx)
				continue
			}

			// 4. Update Admin w organizacji
			_, err = tx.Exec(ctx, `
				UPDATE organizations SET primary_admin_user_id = $1 WHERE id = $2`,
				userID, orgID,
			)
			if err != nil {
				fmt.Printf("   ❌ Błąd przypisania admina org: %v. Wycofywanie.\n\n", err)
				_ = tx.Rollback(ctx)
				continue
			}

			// 5. Subskrypcja PRO
			now := time.Now()
			periodStart := now.Truncate(24 * time.Hour)
			periodEnd := periodStart.AddDate(100, 0, 0) // Na 100 lat dla kont testowych / stażystów

			_, err = tx.Exec(ctx, `
				INSERT INTO subscriptions (id, organization_id, plan_id, provider, provider_subscription_id, status, current_period_start, current_period_end)
				VALUES ($1, $2, $3, 'MANUAL', $4, 'ACTIVE', $5, $6)`,
				subID, orgID, planID, "manual-intern-"+userID[24:], periodStart, periodEnd,
			)
			if err != nil {
				fmt.Printf("   ❌ Błąd utworzenia subskrypcji: %v. Wycofywanie.\n\n", err)
				_ = tx.Rollback(ctx)
				continue
			}

			// 6. Licznik użycia (tokens_limit = 90)
			_, err = tx.Exec(ctx, `
				INSERT INTO usage_counters (id, subscription_id, period_start, period_end, tokens_used, tokens_reserved, tokens_limit)
				VALUES (gen_random_uuid(), $1, $2, $3, 0, 0, $4)`,
				subID, periodStart, periodEnd, planLimit,
			)
			if err != nil {
				fmt.Printf("   ❌ Błąd utworzenia licznika użycia: %v. Wycofywanie.\n\n", err)
				_ = tx.Rollback(ctx)
				continue
			}

			fmt.Println("   ✅ Utworzono konto i organizację w bazie danych!")

		} else if err != nil {
			fmt.Printf("   ❌ Błąd wyszukiwania użytkownika w bazie: %v. Pomijanie.\n\n", err)
			_ = tx.Rollback(ctx)
			continue
		} else {
			// Użytkownik już istnieje, upewnijmy się, że ma poprawny plan i firebase_uid
			fmt.Printf("   ℹ️ Użytkownik już istnieje w bazie (UserID: %s). Aktualizacja planu na PRO...\n", userID)

			// Aktualizujemy firebase_uid w bazie w razie gdyby się nie zgadzał
			_, _ = tx.Exec(ctx, "UPDATE users SET firebase_uid = $1, is_active = true WHERE id = $2", firebaseUID, userID)

			// Znajdź subskrypcję
			err = tx.QueryRow(ctx, "SELECT id FROM subscriptions WHERE organization_id = $1 LIMIT 1", orgID).Scan(&subID)
			now := time.Now()
			periodStart := now.Truncate(24 * time.Hour)
			periodEnd := periodStart.AddDate(100, 0, 0)

			if err != nil {
				// Brak subskrypcji - stwórz nową
				subID = "99000000-0000-0000-0000-" + orgID[24:]
				_, err = tx.Exec(ctx, `
					INSERT INTO subscriptions (id, organization_id, plan_id, provider, provider_subscription_id, status, current_period_start, current_period_end)
					VALUES ($1, $2, $3, 'MANUAL', $4, 'ACTIVE', $5, $6)`,
					subID, orgID, planID, "manual-intern-upgrade-"+userID[24:], periodStart, periodEnd,
				)
				if err != nil {
					fmt.Printf("   ❌ Błąd tworzenia subskrypcji: %v. Wycofywanie.\n\n", err)
					_ = tx.Rollback(ctx)
					continue
				}
			} else {
				// Zaktualizuj subskrypcję do PRO
				_, err = tx.Exec(ctx, "UPDATE subscriptions SET plan_id = $1, status = 'ACTIVE', current_period_end = $2 WHERE id = $3", planID, periodEnd, subID)
				if err != nil {
					fmt.Printf("   ❌ Błąd aktualizacji subskrypcji: %v. Wycofywanie.\n\n", err)
					_ = tx.Rollback(ctx)
					continue
				}
			}

			// Aktualizuj lub dodaj usage_counter
			var counterID string
			err = tx.QueryRow(ctx, "SELECT id FROM usage_counters WHERE subscription_id = $1 AND period_start <= $2 AND period_end > $2", subID, now).Scan(&counterID)
			if err != nil {
				_, err = tx.Exec(ctx, `
					INSERT INTO usage_counters (id, subscription_id, period_start, period_end, tokens_used, tokens_reserved, tokens_limit)
					VALUES (gen_random_uuid(), $1, $2, $3, 0, 0, $4)`,
					subID, periodStart, periodEnd, planLimit,
				)
			} else {
				_, err = tx.Exec(ctx, "UPDATE usage_counters SET tokens_limit = $1, tokens_used = 0, tokens_reserved = 0 WHERE id = $2", planLimit, counterID)
			}

			if err != nil {
				fmt.Printf("   ❌ Błąd aktualizacji limitów użycia: %v. Wycofywanie.\n\n", err)
				_ = tx.Rollback(ctx)
				continue
			}

			fmt.Println("   ✅ Zaktualizowano plan na PRO (Rozkwit) oraz zresetowano limity użycia!")
		}

		if err := tx.Commit(ctx); err != nil {
			fmt.Printf("   ❌ Błąd zapisu transakcji w bazie: %v\n\n", err)
		} else {
			fmt.Printf("   🎉 Zakończono sukcesem dla: %s\n\n", emailLC)
		}
	}

	fmt.Println("--------------------------------------------------------------------------------")
	fmt.Println("✅ Proces zakończony!")
	fmt.Printf("Wszyscy użytkownicy logują się za pomocą podanych maili oraz hasła:\n👉 %s\n", defaultPassword)
}
