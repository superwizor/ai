package grpc

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/actionplan"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// Patient notes + action plan (docs/22). Notes are clinical PHI: the
// title + text are envelope-encrypted at this layer (s.crypto) and
// persisted as (ciphertext, encrypted_dek) BYTEA blobs, mirroring
// transcripts/reports. Authz is the standard kartoteka-ownership check:
// the note's patient_file.therapist_id must equal the ctx therapist.

// validNoteKinds gates the proto-supplied kind against the DB CHECK
// constraint (migration 000040). Empty defaults to FREE_NOTE.
var validNoteKinds = map[string]struct{}{
	"FREE_NOTE":   {},
	"ACTION_PLAN": {},
}

func normalizeNoteKind(kind string) (string, bool) {
	if kind == "" {
		return "FREE_NOTE", true
	}
	if _, ok := validNoteKinds[kind]; ok {
		return kind, true
	}
	return "", false
}

// therapistFromCtx extracts + parses the auth-context therapist UUID.
// Same pattern as UpdatePatientUser.
func (s *Server) therapistFromCtx(ctx context.Context) (uuid.UUID, error) {
	idStr, ok := ctx.Value(UserIDKey).(string)
	if !ok || idStr == "" {
		return uuid.Nil, status.Error(codes.Unauthenticated, "missing user ID in context")
	}
	id, err := uuid.Parse(idStr)
	if err != nil {
		return uuid.Nil, status.Error(codes.InvalidArgument, "invalid therapist_id in context")
	}
	return id, nil
}

// ownPatientFile fetches a patient_file and verifies the ctx therapist
// owns it. A not-found OR wrong-therapist row is reported as NotFound to
// avoid leaking ownership.
func (s *Server) ownPatientFile(ctx context.Context, therapistID, pfID uuid.UUID) (db.PatientFile, error) {
	pf, err := s.queries.GetPatientFile(ctx, pfID)
	if err != nil {
		return db.PatientFile{}, status.Error(codes.NotFound, "patient file not found")
	}
	if pf.TherapistID != therapistID {
		return db.PatientFile{}, status.Error(codes.NotFound, "patient file not found")
	}
	return pf, nil
}

// encryptNote envelope-encrypts the title + text plaintext.
func (s *Server) encryptNote(ctx context.Context, title, text string) (titleCT, titleDEK, textCT, textDEK []byte, err error) {
	titleCT, titleDEK, err = s.crypto.Encrypt(ctx, []byte(title))
	if err != nil {
		return nil, nil, nil, nil, fmt.Errorf("encrypt title: %w", err)
	}
	textCT, textDEK, err = s.crypto.Encrypt(ctx, []byte(text))
	if err != nil {
		return nil, nil, nil, nil, fmt.Errorf("encrypt text: %w", err)
	}
	return titleCT, titleDEK, textCT, textDEK, nil
}

// toProtoPatientNote decrypts the title + text blobs and maps the row to
// the proto. A decrypt failure is fatal (KMS-misconfig signal, same as
// reports).
func (s *Server) toProtoPatientNote(ctx context.Context, n db.PatientNote) (*clinicalv1.PatientNote, error) {
	titleBytes, err := s.crypto.Decrypt(ctx, n.TitleCiphertext, n.TitleEncryptedDek)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "decrypt note title: %v", err)
	}
	textBytes, err := s.crypto.Decrypt(ctx, n.TextCiphertext, n.TextEncryptedDek)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "decrypt note text: %v", err)
	}
	out := &clinicalv1.PatientNote{
		Id:            n.ID.String(),
		PatientFileId: n.PatientFileID.String(),
		Kind:          n.Kind,
		Title:         string(titleBytes),
		Text:          string(textBytes),
		CreatedAt:     timestamppb.New(n.CreatedAt),
		UpdatedAt:     timestamppb.New(n.UpdatedAt),
	}
	if n.SourceSessionID.Valid {
		out.SourceSessionId = uuid.UUID(n.SourceSessionID.Bytes).String()
	}
	if n.SentToPatientAt.Valid {
		out.SentToPatientAt = timestamppb.New(n.SentToPatientAt.Time)
	}
	if n.SentToEmail != nil {
		out.SentToEmail = *n.SentToEmail
	}
	return out, nil
}

// CreatePatientNote creates a free note or action plan under a kartoteka
// the caller owns.
func (s *Server) CreatePatientNote(ctx context.Context, req *clinicalv1.CreatePatientNoteRequest) (*clinicalv1.PatientNote, error) {
	therapistID, err := s.therapistFromCtx(ctx)
	if err != nil {
		return nil, err
	}
	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	kind, ok := normalizeNoteKind(req.Kind)
	if !ok {
		return nil, status.Error(codes.InvalidArgument, "invalid kind (want FREE_NOTE or ACTION_PLAN)")
	}
	if _, err := s.ownPatientFile(ctx, therapistID, pfID); err != nil {
		return nil, err
	}

	var sourceSession pgtype.UUID
	if req.SourceSessionId != "" {
		sid, err := uuid.Parse(req.SourceSessionId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid source_session_id")
		}
		sourceSession = pgtype.UUID{Bytes: sid, Valid: true}
	}

	titleCT, titleDEK, textCT, textDEK, err := s.encryptNote(ctx, req.Title, req.Text)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "%v", err)
	}

	note, err := s.queries.CreatePatientNote(ctx, db.CreatePatientNoteParams{
		PatientFileID:     pfID,
		TherapistID:       therapistID,
		Kind:              kind,
		SourceSessionID:   sourceSession,
		TitleCiphertext:   titleCT,
		TitleEncryptedDek: titleDEK,
		TextCiphertext:    textCT,
		TextEncryptedDek:  textDEK,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "create patient note: %v", err)
	}
	return s.toProtoPatientNote(ctx, note)
}

// ListPatientNotes returns all live notes for a kartoteka the caller owns,
// newest first.
func (s *Server) ListPatientNotes(ctx context.Context, req *clinicalv1.ListPatientNotesRequest) (*clinicalv1.ListPatientNotesResponse, error) {
	therapistID, err := s.therapistFromCtx(ctx)
	if err != nil {
		return nil, err
	}
	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	if _, err := s.ownPatientFile(ctx, therapistID, pfID); err != nil {
		return nil, err
	}

	notes, err := s.queries.ListPatientNotesByFile(ctx, pfID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list patient notes: %v", err)
	}
	resp := &clinicalv1.ListPatientNotesResponse{Notes: make([]*clinicalv1.PatientNote, 0, len(notes))}
	for _, n := range notes {
		p, err := s.toProtoPatientNote(ctx, n)
		if err != nil {
			return nil, err
		}
		resp.Notes = append(resp.Notes, p)
	}
	return resp, nil
}

// noteWithOwnership fetches a note by id and verifies the ctx therapist
// owns the note's patient_file. Returns the note + its patient_file.
func (s *Server) noteWithOwnership(ctx context.Context, therapistID uuid.UUID, noteIDStr string) (db.PatientNote, db.PatientFile, error) {
	noteID, err := uuid.Parse(noteIDStr)
	if err != nil {
		return db.PatientNote{}, db.PatientFile{}, status.Error(codes.InvalidArgument, "invalid note_id")
	}
	note, err := s.queries.GetPatientNote(ctx, noteID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return db.PatientNote{}, db.PatientFile{}, status.Error(codes.NotFound, "note not found")
		}
		return db.PatientNote{}, db.PatientFile{}, status.Errorf(codes.Internal, "get patient note: %v", err)
	}
	pf, err := s.ownPatientFile(ctx, therapistID, note.PatientFileID)
	if err != nil {
		// Mask as note-not-found to avoid leaking existence.
		return db.PatientNote{}, db.PatientFile{}, status.Error(codes.NotFound, "note not found")
	}
	return note, pf, nil
}

// UpdatePatientNote re-encrypts and replaces the note's title + text.
func (s *Server) UpdatePatientNote(ctx context.Context, req *clinicalv1.UpdatePatientNoteRequest) (*clinicalv1.PatientNote, error) {
	therapistID, err := s.therapistFromCtx(ctx)
	if err != nil {
		return nil, err
	}
	note, _, err := s.noteWithOwnership(ctx, therapistID, req.NoteId)
	if err != nil {
		return nil, err
	}

	titleCT, titleDEK, textCT, textDEK, err := s.encryptNote(ctx, req.Title, req.Text)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "%v", err)
	}
	updated, err := s.queries.UpdatePatientNote(ctx, db.UpdatePatientNoteParams{
		ID:                note.ID,
		TitleCiphertext:   titleCT,
		TitleEncryptedDek: titleDEK,
		TextCiphertext:    textCT,
		TextEncryptedDek:  textDEK,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update patient note: %v", err)
	}
	return s.toProtoPatientNote(ctx, updated)
}

// DeletePatientNote soft-deletes a note the caller owns.
func (s *Server) DeletePatientNote(ctx context.Context, req *clinicalv1.DeletePatientNoteRequest) (*emptypb.Empty, error) {
	therapistID, err := s.therapistFromCtx(ctx)
	if err != nil {
		return nil, err
	}
	note, _, err := s.noteWithOwnership(ctx, therapistID, req.NoteId)
	if err != nil {
		return nil, err
	}
	if err := s.queries.SoftDeletePatientNote(ctx, note.ID); err != nil {
		return nil, status.Errorf(codes.Internal, "delete patient note: %v", err)
	}
	return &emptypb.Empty{}, nil
}

// maskEmail renders an e-mail as "p***@domain" — first char of the local
// part + "***@" + domain. Empty input yields empty output.
func maskEmail(email string) string {
	at := strings.LastIndex(email, "@")
	if at <= 0 {
		return ""
	}
	local, domain := email[:at], email[at+1:]
	if local == "" || domain == "" {
		return ""
	}
	return local[:1] + "***@" + domain
}

// GetActionPlanDraft loads the latest report for a session the caller
// owns, extracts the action-plan section, and returns it as a draft to
// seed the note editor — plus the patient's (masked) contact e-mail so
// the UI can offer "save and send".
func (s *Server) GetActionPlanDraft(ctx context.Context, req *clinicalv1.GetActionPlanDraftRequest) (*clinicalv1.ActionPlanDraft, error) {
	therapistID, err := s.therapistFromCtx(ctx)
	if err != nil {
		return nil, err
	}
	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	// Authz: the session's patient_file therapist must be the caller.
	session, err := s.queries.GetSession(ctx, sessionID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "session not found")
	}
	pf, err := s.ownPatientFile(ctx, therapistID, session.PatientFileID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "session not found")
	}

	// Latest report (ListReportsBySession is ORDER BY created_at DESC).
	reports, err := s.queries.ListReportsBySession(ctx, sessionID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list reports: %v", err)
	}

	suggestedText := ""
	if len(reports) > 0 {
		latest := reports[0]
		contentBytes, derr := s.crypto.Decrypt(ctx, latest.ReportCiphertext, latest.ReportEncryptedDek)
		if derr != nil {
			slog.ErrorContext(ctx, "GetActionPlanDraft: decrypt report failed",
				"session_id", req.SessionId, "report_id", latest.ID.String(), "error", derr.Error())
			return nil, status.Error(codes.Internal, "decrypt report failed")
		}
		suggestedText = actionplan.Extract(string(contentBytes))
	}

	draft := &clinicalv1.ActionPlanDraft{
		// PL default; the Flutter app overrides the title (it appends
		// the session date) — see docs/22.
		SuggestedTitle: "Plan działania",
		SuggestedText:  suggestedText,
	}
	if pf.PatientEmail != nil && *pf.PatientEmail != "" {
		draft.PatientHasEmail = true
		draft.PatientEmailMasked = maskEmail(*pf.PatientEmail)
	}
	return draft, nil
}

// SavePatientNote upserts a note (create when note_id is empty, else
// update) and, when send_to_patient is set, e-mails the action plan to
// the patient via notification-svc.
//
// The note is always persisted first. If the send leg then fails (no
// patient e-mail, notification client not wired, or notification-svc
// error), the note stays saved and we return an error / sent=false — the
// therapist never loses their text.
func (s *Server) SavePatientNote(ctx context.Context, req *clinicalv1.SavePatientNoteRequest) (*clinicalv1.SavePatientNoteResponse, error) {
	therapistID, err := s.therapistFromCtx(ctx)
	if err != nil {
		return nil, err
	}

	var (
		note db.PatientNote
		pf   db.PatientFile
	)

	titleCT, titleDEK, textCT, textDEK, err := s.encryptNote(ctx, req.Title, req.Text)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "%v", err)
	}

	if req.NoteId == "" {
		// Create path.
		pfID, perr := uuid.Parse(req.PatientFileId)
		if perr != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
		}
		kind, ok := normalizeNoteKind(req.Kind)
		if !ok {
			return nil, status.Error(codes.InvalidArgument, "invalid kind (want FREE_NOTE or ACTION_PLAN)")
		}
		pf, err = s.ownPatientFile(ctx, therapistID, pfID)
		if err != nil {
			return nil, err
		}
		var sourceSession pgtype.UUID
		if req.SourceSessionId != "" {
			sid, serr := uuid.Parse(req.SourceSessionId)
			if serr != nil {
				return nil, status.Error(codes.InvalidArgument, "invalid source_session_id")
			}
			sourceSession = pgtype.UUID{Bytes: sid, Valid: true}
		}
		note, err = s.queries.CreatePatientNote(ctx, db.CreatePatientNoteParams{
			PatientFileID:     pfID,
			TherapistID:       therapistID,
			Kind:              kind,
			SourceSessionID:   sourceSession,
			TitleCiphertext:   titleCT,
			TitleEncryptedDek: titleDEK,
			TextCiphertext:    textCT,
			TextEncryptedDek:  textDEK,
		})
		if err != nil {
			return nil, status.Errorf(codes.Internal, "create patient note: %v", err)
		}
	} else {
		// Update path.
		var existing db.PatientNote
		existing, pf, err = s.noteWithOwnership(ctx, therapistID, req.NoteId)
		if err != nil {
			return nil, err
		}
		note, err = s.queries.UpdatePatientNote(ctx, db.UpdatePatientNoteParams{
			ID:                existing.ID,
			TitleCiphertext:   titleCT,
			TitleEncryptedDek: titleDEK,
			TextCiphertext:    textCT,
			TextEncryptedDek:  textDEK,
		})
		if err != nil {
			return nil, status.Errorf(codes.Internal, "update patient note: %v", err)
		}
	}

	sent := false
	if req.SendToPatient {
		note, err = s.sendActionPlan(ctx, therapistID, note, pf)
		if err != nil {
			return nil, err
		}
		sent = true
	}

	protoNote, err := s.toProtoPatientNote(ctx, note)
	if err != nil {
		return nil, err
	}
	return &clinicalv1.SavePatientNoteResponse{Note: protoNote, Sent: sent}, nil
}

// sendActionPlan resolves the patient e-mail, calls notification-svc, and
// stamps the note as sent. The note is already persisted by the caller;
// errors here leave it saved-but-unsent.
func (s *Server) sendActionPlan(ctx context.Context, therapistID uuid.UUID, note db.PatientNote, pf db.PatientFile) (db.PatientNote, error) {
	if pf.PatientEmail == nil || *pf.PatientEmail == "" {
		// Note is saved; surface a typed precondition the UI maps to a
		// "add the patient's e-mail first" prompt.
		return note, status.Error(codes.FailedPrecondition, "PATIENT_EMAIL_MISSING")
	}
	toEmail := *pf.PatientEmail

	if s.notification == nil {
		// NOTIFICATION_SVC_URL unset (local dev). The note is saved;
		// we just can't deliver the e-mail. Signal it clearly rather
		// than silently claiming success.
		return note, status.Error(codes.Unavailable, "EMAIL_NOT_CONFIGURED")
	}

	// Therapist display name for the e-mail body. Best-effort: a lookup
	// failure shouldn't block delivery, so fall back to empty.
	displayName := ""
	if nameRow, nerr := s.queries.GetUserDisplayName(ctx, therapistID); nerr == nil {
		displayName = strings.TrimSpace(nameRow.FirstName + " " + nameRow.LastName)
	}

	// Decrypt the note text for the e-mail body.
	textBytes, derr := s.crypto.Decrypt(ctx, note.TextCiphertext, note.TextEncryptedDek)
	if derr != nil {
		return note, status.Errorf(codes.Internal, "decrypt note text: %v", derr)
	}

	// Formatted session date (dd.MM.yyyy) when the note is tied to a
	// source session; empty otherwise.
	sessionDate := ""
	if note.SourceSessionID.Valid {
		if sess, serr := s.queries.GetSession(ctx, uuid.UUID(note.SourceSessionID.Bytes)); serr == nil && sess.SessionDate.Valid {
			sessionDate = sess.SessionDate.Time.Format("02.01.2006")
		}
	}

	// Forward incoming metadata (tracing); the OIDC token for
	// notification-svc is injected by the outbound client.
	outCtx := ctx
	if md, ok := metadata.FromIncomingContext(ctx); ok {
		outCtx = metadata.NewOutgoingContext(ctx, md)
	}

	if _, serr := s.notification.SendActionPlanEmail(outCtx, &notificationv1.SendActionPlanEmailRequest{
		ToEmail:              toEmail,
		TherapistDisplayName: displayName,
		ActionPlanText:       string(textBytes),
		SessionDate:          sessionDate,
		IdempotencyKey:       note.ID.String(),
	}); serr != nil {
		slog.ErrorContext(ctx, "SavePatientNote: SendActionPlanEmail failed",
			"note_id", note.ID.String(), "error", serr.Error(),
			"grpc_code", status.Code(serr).String())
		return note, status.Errorf(codes.Internal, "send action plan e-mail failed: %v", serr)
	}

	emailCopy := toEmail
	stamped, merr := s.queries.MarkPatientNoteSent(ctx, db.MarkPatientNoteSentParams{
		ID:          note.ID,
		SentToEmail: &emailCopy,
	})
	if merr != nil {
		// E-mail went out but we couldn't record it. Log loudly; the
		// note is still saved (just missing the sent stamp).
		slog.ErrorContext(ctx, "SavePatientNote: MarkPatientNoteSent failed after send",
			"note_id", note.ID.String(), "error", merr.Error())
		return note, status.Errorf(codes.Internal, "mark note sent failed: %v", merr)
	}
	return stamped, nil
}
