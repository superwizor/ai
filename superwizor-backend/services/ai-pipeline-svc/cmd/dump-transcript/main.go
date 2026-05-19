// dump-transcript — small CLI that pulls a session's transcript from
// PG, decrypts it via Cloud KMS, and writes the human-readable
// chunked text to a file (or stdout). Use this to seed llm-eval with
// real transcripts without copy-pasting from the Flutter app.
//
// The output format matches what llm-worker.loadTranscriptText
// produces — `[CHUNK N] (startMs-endMs) text\n` per line — so the
// transcript bodies used in eval are the same the production prompt
// sees.
//
// Usage:
//
//   # Dump one session by ID (writes to ./testdata/transcripts/<id>.txt):
//   DATABASE_URL=postgres://... \
//   KMS_KEY_URI=projects/.../cryptoKeys/transcripts \
//   go run ./cmd/dump-transcript -session 865b7557-4859-455e-ab19-cde6b7954211
//
//   # List recent completed sessions (no decrypt — just IDs + metadata):
//   DATABASE_URL=postgres://... \
//   go run ./cmd/dump-transcript -list
//
// Auth:
//
//   - DATABASE_URL: standard libpq DSN. For Cloud SQL via IAM proxy
//     run `cloud-sql-proxy --port=5432 <instance>` in another shell
//     then point DATABASE_URL at localhost:5432.
//   - KMS_KEY_URI: required for decryption (mockbox is used only when
//     unset, useful for syntax checks against an empty DB).
//   - Application-default credentials must have roles/cloudkms.cryptoKeyDecrypter
//     on the transcripts KMS key.

package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"time"

	kms "cloud.google.com/go/kms/apiv1"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/pkg/cryptobox"
)

func main() {
	var (
		sessionID = flag.String("session", "", "session UUID to dump")
		listOnly  = flag.Bool("list", false, "list recent completed sessions, don't decrypt")
		limit     = flag.Int("limit", 20, "with -list, how many rows")
		outDir    = flag.String("out", "./testdata/transcripts", "output directory (with -session)")
		toStdout  = flag.Bool("stdout", false, "print transcript to stdout instead of writing a file")
	)
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	dbDSN := os.Getenv("DATABASE_URL")
	if dbDSN == "" {
		fatal("DATABASE_URL required")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbDSN)
	if err != nil {
		fatal(fmt.Sprintf("db: %v", err))
	}
	defer pool.Close()

	if *listOnly {
		listSessions(ctx, pool, *limit)
		return
	}

	if *sessionID == "" {
		fatal("-session required (or use -list)")
	}

	// Cryptobox setup. Mockbox is fine for the -list path; -session
	// path needs real KMS.
	var crypto cryptobox.CryptoBox
	if uri := os.Getenv("KMS_KEY_URI"); uri != "" {
		kmsClient, err := kms.NewKeyManagementClient(ctx)
		if err != nil {
			fatal(fmt.Sprintf("kms client: %v", err))
		}
		crypto = cryptobox.NewCloudKMSBox(kmsClient, uri)
	} else {
		slog.Warn("KMS_KEY_URI unset, using mockbox — decrypt will fail on real data")
		crypto = cryptobox.NewMockBox()
	}

	text, err := dumpSession(ctx, pool, crypto, *sessionID)
	if err != nil {
		fatal(fmt.Sprintf("dump session %s: %v", *sessionID, err))
	}

	if *toStdout {
		fmt.Print(text)
		return
	}

	if err := os.MkdirAll(*outDir, 0o755); err != nil {
		fatal(fmt.Sprintf("mkdir out: %v", err))
	}
	outPath := filepath.Join(*outDir, *sessionID+".txt")
	if err := os.WriteFile(outPath, []byte(text), 0o644); err != nil {
		fatal(fmt.Sprintf("write: %v", err))
	}
	slog.Info("wrote transcript", "path", outPath, "bytes", len(text))
}

// listSessions prints recent sessions joined with patient_files +
// transcripts, sorted by created_at desc. Useful for "which
// session_id should I evaluate?" — gives status, language, alias.
func listSessions(ctx context.Context, pool *pgxpool.Pool, limit int) {
	rows, err := pool.Query(ctx, `
		SELECT
			s.id,
			s.created_at,
			s.status,
			s.language_code,
			pf.working_alias,
			t.word_count,
			t.confidence_avg,
			t.speaker_count
		FROM sessions s
		LEFT JOIN patient_files pf ON pf.id = s.patient_file_id
		LEFT JOIN transcripts t ON t.session_id = s.id
		WHERE s.deleted_at IS NULL
		ORDER BY s.created_at DESC
		LIMIT $1`, limit)
	if err != nil {
		fatal(fmt.Sprintf("list: %v", err))
	}
	defer rows.Close()

	fmt.Printf("%-38s  %-25s  %-12s  %-7s  %-25s  %-8s  %-6s  %-7s\n",
		"session_id", "created_at", "status", "lang", "alias", "words", "conf", "speakers")
	for rows.Next() {
		var (
			id          uuid.UUID
			created     time.Time
			status      string
			lang        string
			alias       *string
			wordCount   *int
			confAvg     *float64
			speakerCnt  *int
		)
		if err := rows.Scan(&id, &created, &status, &lang, &alias, &wordCount, &confAvg, &speakerCnt); err != nil {
			slog.Warn("scan row", "err", err)
			continue
		}
		aliasStr := "—"
		if alias != nil {
			aliasStr = truncate(*alias, 25)
		}
		wc := "—"
		if wordCount != nil {
			wc = fmt.Sprintf("%d", *wordCount)
		}
		ca := "—"
		if confAvg != nil {
			ca = fmt.Sprintf("%.2f", *confAvg)
		}
		sc := "—"
		if speakerCnt != nil {
			sc = fmt.Sprintf("%d", *speakerCnt)
		}
		fmt.Printf("%s  %s  %-12s  %-7s  %-25s  %-8s  %-6s  %-7s\n",
			id, created.Format("2006-01-02 15:04:05"), status, lang, aliasStr, wc, ca, sc)
	}
}

// dumpSession is the mirror of llm-worker.loadTranscriptText —
// pulls ciphertext+dek for the session's transcript row, decrypts,
// and renders the chunked plain text. Kept here rather than in a
// shared package because (a) it's a 30-line function and (b) we want
// this tool to depend on nothing that would force it to ship as
// production code.
func dumpSession(ctx context.Context, pool *pgxpool.Pool, crypto cryptobox.CryptoBox, sessionIDStr string) (string, error) {
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		return "", fmt.Errorf("invalid session UUID: %w", err)
	}

	var transcriptID uuid.UUID
	var ciphertext, encryptedDEK []byte
	err = pool.QueryRow(ctx, `
		SELECT id, transcript_ciphertext, transcript_encrypted_dek
		FROM transcripts
		WHERE session_id = $1
		ORDER BY created_at DESC
		LIMIT 1`, sessionID).Scan(&transcriptID, &ciphertext, &encryptedDEK)
	if err != nil {
		return "", fmt.Errorf("query transcript: %w", err)
	}

	plain, err := crypto.Decrypt(ctx, ciphertext, encryptedDEK)
	if err != nil {
		return "", fmt.Errorf("decrypt: %w", err)
	}

	type BlobLine struct {
		ChunkIdx     int     `json:"chunk_idx"`
		Text         string  `json:"text"`
		StartMS      int64   `json:"start_ms"`
		EndMS        int64   `json:"end_ms"`
		WordCount    int     `json:"word_count"`
		Confidence   float32 `json:"confidence"`
		SpeakerTag   *int32  `json:"speaker_tag,omitempty"`
		SpeakerLabel *string `json:"speaker_label,omitempty"`
	}

	var lines []BlobLine
	if err := json.Unmarshal(plain, &lines); err != nil {
		return "", fmt.Errorf("unmarshal blob: %w", err)
	}

	var sb strings.Builder
	for _, l := range lines {
		if l.SpeakerLabel != nil && *l.SpeakerLabel != "" {
			fmt.Fprintf(&sb, "[CHUNK %d / %s] (%dms-%dms) %s\n",
				l.ChunkIdx, *l.SpeakerLabel, l.StartMS, l.EndMS, l.Text)
		} else {
			fmt.Fprintf(&sb, "[CHUNK %d] (%dms-%dms) %s\n",
				l.ChunkIdx, l.StartMS, l.EndMS, l.Text)
		}
	}

	slog.Info("decrypted transcript",
		"session_id", sessionID,
		"transcript_id", transcriptID,
		"chunks", len(lines),
		"chars", sb.Len())
	return sb.String(), nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n-1] + "…"
}

func fatal(msg string) {
	fmt.Fprintln(os.Stderr, "fatal:", msg)
	os.Exit(2)
}
