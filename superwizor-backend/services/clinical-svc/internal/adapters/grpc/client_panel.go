package grpc

import (
	"context"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	notificationv1 "github.com/superwizor-ai/backend/gen/go/notification/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/grouping"
)

// Client (patient) panel — docs/39. A separate, read-mostly RPC family
// with its own object-level gate: the caller must BE the kartoteka's
// patient (role PATIENT + patient_files.patient_id == caller). Denials
// are NotFound — same no-enumeration-oracle contract as the therapist
// side. Therapist content is additionally gated by the explicit
// sharing markers (D2): unshared rows do not exist as far as the
// client is concerned.

// clientFromCtx returns the authenticated PATIENT caller's user id.
func clientFromCtx(ctx context.Context) (uuid.UUID, error) {
	role, _ := ctx.Value(UserRoleKey).(string)
	if role != "PATIENT" {
		return uuid.Nil, status.Error(codes.PermissionDenied,
			"client panel is available to client accounts only")
	}
	idStr, _ := ctx.Value(UserIDKey).(string)
	id, err := uuid.Parse(idStr)
	if err != nil {
		return uuid.Nil, status.Error(codes.Unauthenticated, "missing caller identity")
	}
	return id, nil
}

// requireClientFileAccess loads the kartoteka and verifies the caller
// is ITS patient. NotFound on any mismatch.
func (s *Server) requireClientFileAccess(ctx context.Context, patientFileID uuid.UUID) (db.PatientFile, uuid.UUID, error) {
	callerID, err := clientFromCtx(ctx)
	if err != nil {
		return db.PatientFile{}, uuid.Nil, err
	}
	pf, err := s.queries.GetPatientFile(ctx, patientFileID)
	if err != nil {
		return db.PatientFile{}, uuid.Nil, status.Error(codes.NotFound, "not found")
	}
	if !pf.PatientID.Valid || uuid.UUID(pf.PatientID.Bytes) != callerID {
		return db.PatientFile{}, uuid.Nil, status.Error(codes.NotFound, "not found")
	}
	return pf, callerID, nil
}

// ── Client reads ────────────────────────────────────────────────────

func (s *Server) ClientGetMyOverview(ctx context.Context, _ *emptypb.Empty) (*clinicalv1.ClientOverview, error) {
	callerID, err := clientFromCtx(ctx)
	if err != nil {
		return nil, err
	}
	rows, err := s.queries.ClientListKartoteki(ctx, pgtype.UUID{Bytes: callerID, Valid: true})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "overview: %v", err)
	}
	out := &clinicalv1.ClientOverview{}
	for _, r := range rows {
		out.Kartoteki = append(out.Kartoteki, &clinicalv1.ClientKartoteka{
			PatientFileId:    r.PatientFileID.String(),
			TherapistName:    r.TherapistName,
			OrganizationName: r.OrganizationName,
			SharedSessions:   r.SharedSessions,
			SharedNotes:      r.SharedNotes,
			UnreadNotes:      r.UnreadNotes,
		})
	}
	return out, nil
}

func (s *Server) ClientListSessions(ctx context.Context, req *clinicalv1.ClientListSessionsRequest) (*clinicalv1.ClientListSessionsResponse, error) {
	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	if _, _, err := s.requireClientFileAccess(ctx, pfID); err != nil {
		return nil, err
	}
	rows, err := s.queries.ClientListSharedSessions(ctx, pfID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list sessions: %v", err)
	}
	out := &clinicalv1.ClientListSessionsResponse{}
	for _, r := range rows {
		info := &clinicalv1.ClientSessionInfo{
			SessionId:     r.ID.String(),
			SessionDate:   r.SessionDate.Time.Format("2006-01-02"),
			SessionNumber: r.SessionNumber,
			HasTranscript: r.HasTranscript,
		}
		if r.DurationSeconds != nil {
			info.DurationSeconds = *r.DurationSeconds
		}
		if r.SharedWithClientAt.Valid {
			info.SharedAt = timestamppb.New(r.SharedWithClientAt.Time)
		}
		out.Sessions = append(out.Sessions, info)
	}
	return out, nil
}

// ClientGetTranscript — the ONLY decrypted-PHI read on the client side.
// Guarded threefold: PATIENT self-access, the session belongs to the
// caller's kartoteka, and the therapist shared it (D2).
func (s *Server) ClientGetTranscript(ctx context.Context, req *clinicalv1.ClientGetTranscriptRequest) (*clinicalv1.ClientGetTranscriptResponse, error) {
	callerID, err := clientFromCtx(ctx)
	if err != nil {
		return nil, err
	}
	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}
	sess, err := s.queries.ClientGetSharedSession(ctx, sessionID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "not found")
	}
	if !sess.PatientID.Valid || uuid.UUID(sess.PatientID.Bytes) != callerID {
		return nil, status.Error(codes.NotFound, "not found")
	}
	if !sess.SharedWithClientAt.Valid {
		return nil, status.Error(codes.NotFound, "not found") // unshared ⇒ invisible
	}

	info := &clinicalv1.ClientSessionInfo{
		SessionId:     sess.ID.String(),
		SessionDate:   sess.SessionDate.Time.Format("2006-01-02"),
		SessionNumber: sess.SessionNumber,
		SharedAt:      timestamppb.New(sess.SharedWithClientAt.Time),
	}
	if sess.DurationSeconds != nil {
		info.DurationSeconds = *sess.DurationSeconds
	}
	resp := &clinicalv1.ClientGetTranscriptResponse{Session: info}

	transcript, err := s.queries.GetTranscriptBySession(ctx, sessionID)
	if err != nil {
		return resp, nil // shared session without transcript yet
	}
	protoTranscript := &clinicalv1.Transcript{Id: transcript.ID.String()}
	// Same fast/slow decrypt strategy as the therapist's
	// GetSessionDetails (see session.go for the rationale).
	if segs, ok := tryCanonicalBlobSegments(ctx, s.crypto, transcript); ok {
		protoTranscript.Segments = segs
		protoTranscript.Turns = grouping.GroupSegmentsIntoTurns(segs)
	} else {
		segs, fatalErr := loadSegmentsViaPerSegmentLoop(ctx, s.queries, s.crypto, transcript.ID, req.SessionId)
		if fatalErr != nil {
			return nil, fatalErr
		}
		protoTranscript.Segments = segs
		protoTranscript.Turns = grouping.GroupSegmentsIntoTurns(segs)
	}
	resp.Transcript = protoTranscript
	info.HasTranscript = true
	return resp, nil
}

func (s *Server) ClientListNotes(ctx context.Context, req *clinicalv1.ClientListNotesRequest) (*clinicalv1.ClientListNotesResponse, error) {
	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	if _, _, err := s.requireClientFileAccess(ctx, pfID); err != nil {
		return nil, err
	}
	rows, err := s.queries.ClientListVisibleNotes(ctx, pfID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list notes: %v", err)
	}
	out := &clinicalv1.ClientListNotesResponse{}
	for _, n := range rows {
		note, err := s.toClientNote(ctx, n)
		if err != nil {
			continue // single decrypt failure must not hide the rest
		}
		out.Notes = append(out.Notes, note)
	}
	return out, nil
}

func (s *Server) ClientCreateNote(ctx context.Context, req *clinicalv1.ClientCreateNoteRequest) (*clinicalv1.ClientNote, error) {
	pfID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}
	pf, _, err := s.requireClientFileAccess(ctx, pfID)
	if err != nil {
		return nil, err
	}
	title := strings.TrimSpace(req.Title)
	text := strings.TrimSpace(req.Text)
	if title == "" && text == "" {
		return nil, status.Error(codes.InvalidArgument, "empty note")
	}

	titleCT, titleDEK, textCT, textDEK, err := s.encryptNote(ctx, title, text)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "%v", err)
	}
	note, err := s.queries.CreateClientNote(ctx, db.CreateClientNoteParams{
		PatientFileID:     pfID,
		TherapistID:       pf.TherapistID,
		TitleCiphertext:   titleCT,
		TitleEncryptedDek: titleDEK,
		TextCiphertext:    textCT,
		TextEncryptedDek:  textDEK,
		Column7:           req.SendToTherapist,
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "create note: %v", err)
	}
	// PR9: tell the therapist a client note arrived — PHI-free (no
	// client identity, no content). Drafts (000068) stay private: the
	// signal fires only on delivery.
	if req.SendToTherapist {
		if row, terr := s.queries.GetUserEmailForNotify(ctx, pf.TherapistID); terr == nil && row.Email != nil {
			s.notifyClientPanelEvent(ctx, *row.Email, row.UiLanguage, "CLIENT_NOTE_RECEIVED", "",
				pf.TherapistID.String(), pfID.String())
		}
	}
	return s.toClientNote(ctx, note)
}

// ClientSendNote delivers a previously saved draft (000068) to the
// therapist. Idempotent: a delivered note keeps its first timestamp
// and does not re-notify.
func (s *Server) ClientSendNote(ctx context.Context, req *clinicalv1.ClientSendNoteRequest) (*clinicalv1.ClientNote, error) {
	noteID, err := uuid.Parse(req.NoteId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid note_id")
	}
	note, err := s.queries.GetPatientNote(ctx, noteID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "not found")
	}
	pf, _, err := s.requireClientFileAccess(ctx, note.PatientFileID)
	if err != nil {
		return nil, err
	}
	if note.Kind != "CLIENT_NOTE" {
		// Therapist notes aren't the client's to send — same
		// no-enumeration contract as everywhere else in this family.
		return nil, status.Error(codes.NotFound, "not found")
	}
	wasDraft := !note.SentToTherapistAt.Valid
	sent, err := s.queries.MarkClientNoteSentToTherapist(ctx, noteID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "send note: %v", err)
	}
	if wasDraft {
		if row, terr := s.queries.GetUserEmailForNotify(ctx, pf.TherapistID); terr == nil && row.Email != nil {
			s.notifyClientPanelEvent(ctx, *row.Email, row.UiLanguage, "CLIENT_NOTE_RECEIVED", "",
				pf.TherapistID.String(), note.PatientFileID.String())
		}
	}
	return s.toClientNote(ctx, sent)
}

func (s *Server) ClientMarkNoteRead(ctx context.Context, req *clinicalv1.ClientMarkNoteReadRequest) (*emptypb.Empty, error) {
	noteID, err := uuid.Parse(req.NoteId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid note_id")
	}
	note, err := s.queries.GetPatientNote(ctx, noteID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "not found")
	}
	if _, _, err := s.requireClientFileAccess(ctx, note.PatientFileID); err != nil {
		return nil, err
	}
	if err := s.queries.MarkNoteReadByClient(ctx, noteID); err != nil {
		return nil, status.Errorf(codes.Internal, "mark read: %v", err)
	}
	return &emptypb.Empty{}, nil
}

// toClientNote decrypts and maps a row to the client-facing shape.
func (s *Server) toClientNote(ctx context.Context, n db.PatientNote) (*clinicalv1.ClientNote, error) {
	titleBytes, err := s.crypto.Decrypt(ctx, n.TitleCiphertext, n.TitleEncryptedDek)
	if err != nil {
		return nil, err
	}
	textBytes, err := s.crypto.Decrypt(ctx, n.TextCiphertext, n.TextEncryptedDek)
	if err != nil {
		return nil, err
	}
	out := &clinicalv1.ClientNote{
		Id:         n.ID.String(),
		Kind:       n.Kind,
		Title:      string(titleBytes),
		Text:       string(textBytes),
		AuthorRole: string(n.AuthorRole),
		CreatedAt:  timestamppb.New(n.CreatedAt),
		Read:       n.ReadByClientAt.Valid,
	}
	if n.SharedWithClientAt.Valid {
		out.SharedAt = timestamppb.New(n.SharedWithClientAt.Time)
	}
	if n.SentToTherapistAt.Valid {
		out.SentToTherapistAt = timestamppb.New(n.SentToTherapistAt.Time)
	}
	return out, nil
}

// notifyClientPanelEvent fires the PHI-free e-mail signal (docs/39
// PR9) in the background. Strictly best-effort: the share/create RPC
// has already succeeded, so any failure here is logged and dropped —
// never surfaced to the caller. nil notification client (local dev)
// short-circuits.
//
// event: ITEM_SHARED | CLIENT_NOTE_RECEIVED; itemKind: SESSION | NOTE.
// recipientUserID + patientFileID are used only by CLIENT_NOTE_RECEIVED
// (PR11) to fan a live FCM refresh push out to the therapist; empty for
// ITEM_SHARED (the client panel is web and pulls on focus).
func (s *Server) notifyClientPanelEvent(ctx context.Context, email, locale, event, itemKind, recipientUserID, patientFileID string) {
	if s.notification == nil || email == "" {
		return
	}
	// Detach from the request lifecycle but keep tracing metadata and
	// bound the send so a slow notification-svc can't leak goroutines.
	base := context.WithoutCancel(ctx)
	if md, ok := metadata.FromIncomingContext(ctx); ok {
		base = metadata.NewOutgoingContext(base, md)
	}
	go func() {
		sendCtx, cancel := context.WithTimeout(base, 15*time.Second)
		defer cancel()
		if _, err := s.notification.SendClientPanelEvent(sendCtx, &notificationv1.SendClientPanelEventRequest{
			RecipientEmail:  email,
			Event:           event,
			ItemKind:        itemKind,
			Locale:          locale,
			PanelUrl:        s.panelURL,
			RecipientUserId: recipientUserID,
			PatientFileId:   patientFileID,
		}); err != nil {
			slog.Warn("client panel event notification failed",
				"event", event, "item_kind", itemKind, "error", err)
		}
	}()
}

// notifyKartotekaClient resolves the kartoteka's client account and, if
// one is attached and active, signals a newly shared item.
func (s *Server) notifyKartotekaClient(ctx context.Context, patientFileID uuid.UUID, itemKind string) {
	row, err := s.queries.GetPatientUserEmailForFile(ctx, patientFileID)
	if err != nil || row.Email == nil {
		// No attached/active panel account — nothing to signal.
		return
	}
	// ITEM_SHARED targets the web client panel. PR12: pass the client's
	// user id + kartoteka id so notification-svc mirrors the event into
	// the client's Firestore inbox — the panel subscribes to it and
	// refreshes the timeline live (no web-push needed).
	s.notifyClientPanelEvent(ctx, *row.Email, row.UiLanguage, "ITEM_SHARED", itemKind,
		row.PatientID.String(), patientFileID.String())
}

// ── Therapist-side sharing toggles ──────────────────────────────────

func (s *Server) ShareSessionWithClient(ctx context.Context, req *clinicalv1.ShareSessionWithClientRequest) (*emptypb.Empty, error) {
	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}
	session, err := s.queries.GetSession(ctx, sessionID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "session not found")
	}
	if err := s.requireTherapistDataAccess(ctx, session.TherapistID); err != nil {
		return nil, err
	}
	if _, err := s.queries.SetSessionSharedWithClient(ctx, db.SetSessionSharedWithClientParams{
		ID:      sessionID,
		Column2: req.Shared,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "share session: %v", err)
	}
	// PR9: signal only the unshared→shared edge — re-sharing an already
	// shared session (idempotent toggle) must not re-notify.
	if req.Shared && !session.SharedWithClientAt.Valid {
		s.notifyKartotekaClient(ctx, session.PatientFileID, "SESSION")
	}
	return &emptypb.Empty{}, nil
}

func (s *Server) ShareNoteWithClient(ctx context.Context, req *clinicalv1.ShareNoteWithClientRequest) (*emptypb.Empty, error) {
	noteID, err := uuid.Parse(req.NoteId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid note_id")
	}
	note, err := s.queries.GetPatientNote(ctx, noteID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "note not found")
	}
	if err := s.requireTherapistDataAccess(ctx, note.TherapistID); err != nil {
		return nil, err
	}
	if note.Kind == "CLIENT_NOTE" {
		return nil, status.Error(codes.FailedPrecondition, "client notes are owned by the client")
	}
	if _, err := s.queries.SetNoteSharedWithClient(ctx, db.SetNoteSharedWithClientParams{
		ID:      noteID,
		Column2: req.Shared,
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "share note: %v", err)
	}
	// PR9: unshared→shared edge only (see ShareSessionWithClient).
	if req.Shared && !note.SharedWithClientAt.Valid {
		s.notifyKartotekaClient(ctx, note.PatientFileID, "NOTE")
	}
	return &emptypb.Empty{}, nil
}
