---
name: ios-testflight-and-tester-seeding
description: Guides automated iOS TestFlight uploads and idempotent database seeding for internal testers (Firebase + PostgreSQL).
---

# iOS TestFlight & Tester Seeding Skill

This skill guides adding new internal/external testers to Firebase Auth and Postgres, and deploying iOS builds to Apple TestFlight.

## 1. Adding / Seeding Testers (Firebase + PostgreSQL)
To register a new internal therapist or clinical intern:

1. Open `superwizor-backend/scripts/seed_interns.go`.
2. Append the new tester's details to the `interns` array:
   ```go
   interns := []Intern{
       {Email: "tester.email@example.com", FirstName: "Name", LastName: "Surname"},
   }
   ```
3. Run the registration shortcut from the root directory:
   ```bash
   ./KOMENDY/9
   ```
   *Note: This command connects to Postgres via Cloud SQL proxy, creates the Firebase Auth account, registers their profile in Postgres, assigns a 100-year PRO modality plan, and resets token usage to 90.*

## 2. Deploying to TestFlight
To build and upload a new iOS version:

1. Update version/build number in `flutter-app/superwizor/pubspec.yaml` (e.g., `version: 1.0.2+26`).
2. Ensure `credentials.env` exists with `APP_STORE_ISSUER_ID`, `APP_STORE_KEY_ID`, and `APP_STORE_PRIVATE_KEY_PATH`.
3. Ensure the `.p8` private key is in `~/private_keys/`.
4. Run the upload shortcut:
   ```bash
   ./KOMENDY/8
   ```
   *This automatically builds the IPA and pushes it to TestFlight via `xcrun altool`.*
