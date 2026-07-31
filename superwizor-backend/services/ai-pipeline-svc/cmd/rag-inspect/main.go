// Command rag-inspect is a read-only diagnostic that shows how the RAG
// "thread-linking" between sessions looks from the user's side for ONE
// session. It:
//
//  1. resolves the patient_file for the target session,
//  2. lists every rag_memories row for that patient_file (the long-term
//     memory the worker accrued across sessions), decrypting the
//     pseudonymized summary/theme text, and
//  3. decrypts and prints the generated report for the target session,
//     where RAG surfaces as woven-in continuity references.
//
// Run it yourself (you hold the staging DB + KMS access):
//
//	cd superwizor-backend
//	export DATABASE_URL="$(gcloud secrets versions access latest --secret=postgres-database-url)"
//	go run ./cmd/rag-inspect <session-uuid>
//
// KMS key defaults to the staging app-data-key; override with KMS_KEY_URI.
// Nothing is written back — pure read.
package main

import (
	"context"
	"fmt"
	"os"
	"time"

	kms "cloud.google.com/go/kms/apiv1"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/pkg/cryptobox"
)

const defaultKMSKeyURI = "projects/superwizor-ai-25ecd/locations/europe-central2/keyRings/superwizor-keyring/cryptoKeys/app-data-key"

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: go run ./cmd/rag-inspect <session-uuid>")
		os.Exit(2)
	}
	sessionID := os.Args[1]

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		fmt.Println("DATABASE_URL is required")
		os.Exit(1)
	}
	keyURI := os.Getenv("KMS_KEY_URI")
	if keyURI == "" {
		keyURI = defaultKMSKeyURI
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		fatal("db connect", err)
	}
	defer pool.Close()

	kmsClient, err := kms.NewKeyManagementClient(ctx)
	if err != nil {
		fatal("kms client", err)
	}
	defer func() { _ = kmsClient.Close() }()
	crypto := cryptobox.NewCloudKMSBox(kmsClient, keyURI)

	// 1. Resolve the patient_file + session number for context.
	var patientFileID string
	var sessionNumber int
	err = pool.QueryRow(ctx,
		`SELECT patient_file_id, session_number FROM sessions WHERE id = $1`,
		sessionID).Scan(&patientFileID, &sessionNumber)
	if err != nil {
		fatal("resolve session", err)
	}
	fmt.Printf("Session %s  (session_number=%d)\n", sessionID, sessionNumber)
	fmt.Printf("Patient file: %s\n\n", patientFileID)

	// 2. The long-term memory accrued for this patient_file across all
	//    sessions. This IS the "thread linking" store. We show it ordered
	//    oldest→newest so you can see sessions #1/#2 feeding #3.
	fmt.Println("==================== RAG MEMORIES (rag_memories) ====================")
	rows, err := pool.Query(ctx, `
		SELECT chunk_type, importance_score, source_session_id, is_compacted,
		       created_at, summary_ciphertext, summary_encrypted_dek
		FROM rag_memories
		WHERE patient_file_id = $1
		ORDER BY created_at ASC`, patientFileID)
	if err != nil {
		fatal("query rag_memories", err)
	}
	defer rows.Close()

	n := 0
	for rows.Next() {
		var chunkType string
		var importance float64
		var srcSession *string
		var compacted bool
		var createdAt time.Time
		var ct, dek []byte
		if err := rows.Scan(&chunkType, &importance, &srcSession, &compacted, &createdAt, &ct, &dek); err != nil {
			fatal("scan rag row", err)
		}
		plain, derr := crypto.Decrypt(ctx, ct, dek)
		body := string(plain)
		if derr != nil {
			body = "<decrypt error: " + derr.Error() + ">"
		}
		src := "—"
		if srcSession != nil {
			src = (*srcSession)[:8]
		}
		n++
		fmt.Printf("\n[%d] type=%s importance=%.2f source_session=%s compacted=%v  %s\n",
			n, chunkType, importance, src, compacted, createdAt.Format("15:04:05"))
		fmt.Printf("    %s\n", body)
	}
	if err := rows.Err(); err != nil {
		fatal("iterate rag rows", err)
	}
	fmt.Printf("\n(%d memory rows total for this patient_file)\n", n)

	// 3. The generated report for THIS session — where RAG shows up as
	//    in-prose continuity references (there is no separate stored
	//    "previous sessions" section; the context block is prompt-only).
	fmt.Println("\n==================== REPORT (reports) ====================")
	var rct, rdek []byte
	err = pool.QueryRow(ctx,
		`SELECT report_ciphertext, report_encrypted_dek FROM reports WHERE session_id = $1`,
		sessionID).Scan(&rct, &rdek)
	if err != nil {
		fatal("query report", err)
	}
	report, err := crypto.Decrypt(ctx, rct, rdek)
	if err != nil {
		fatal("decrypt report", err)
	}
	fmt.Println(string(report))
}

func fatal(stage string, err error) {
	fmt.Printf("ERROR [%s]: %v\n", stage, err)
	os.Exit(1)
}
