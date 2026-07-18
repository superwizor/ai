package grpc

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/emptypb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/pkg/analytics"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// Test doubles for the gRPC handler tests.
//
// Pattern: fakeQuerier embeds db.Querier as nil; only the methods set
// via function fields are real, every unset method panics with a clear
// nil-pointer message via the embedded nil interface — which is exactly
// what we want, because an unexpected query call in a test is a bug
// in the test or the handler under test.
//
// fakeTxOpener wraps a fakeQuerier (or a different one — handy for
// asserting "transactional path used the tx-scoped Querier, not the
// pool-level one") plus knobs for forcing Begin/Commit failures.

type fakeQuerier struct {
	db.Querier // nil embed — calls to unset methods panic loudly

	getPatientFileFn           func(ctx context.Context, id uuid.UUID) (db.PatientFile, error)
	getPatientFileWithUserFn   func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error)
	updatePatientFileFn        func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error)
	updatePatientUserFn        func(ctx context.Context, arg db.UpdatePatientUserParams) (db.UpdatePatientUserRow, error)
	deletePatientUserFn        func(ctx context.Context, id uuid.UUID) (int64, error)
	listSessionIDsForPatientFn func(ctx context.Context, pid pgtype.UUID) ([]uuid.UUID, error)
	listSessionIDsForPFFn      func(ctx context.Context, id uuid.UUID) ([]uuid.UUID, error)
	hardDeletePatientFileFn    func(ctx context.Context, arg db.HardDeletePatientFileParams) (int64, error)
	hardDeleteSessionFn        func(ctx context.Context, arg db.HardDeleteSessionParams) (int64, error)
	getSessionFn               func(ctx context.Context, id uuid.UUID) (db.Session, error)
	updateSessionNameFn        func(ctx context.Context, arg db.UpdateSessionNameParams) (db.Session, error)
	updateSessionStatusFn      func(ctx context.Context, arg db.UpdateSessionStatusParams) error
	getUserOrganizationIDFn    func(ctx context.Context, id uuid.UUID) (pgtype.UUID, error)

	resolvePatientEmailFn func(ctx context.Context, id uuid.UUID) (*string, error)

	getModalityDistributionFn func(ctx context.Context) ([]db.GetModalityDistributionRow, error)
	getAvgSessionDurationFn   func(ctx context.Context) (float64, error)
	getSessionDurationTrendFn func(ctx context.Context, since time.Time) ([]db.GetSessionDurationTrendRow, error)

	// DSAR & Purger fields
	getPatientNotesForExportFn      func(ctx context.Context, patientFileID uuid.UUID) ([]db.PatientNote, error)
	getSessionsForExportFn          func(ctx context.Context, patientFileID uuid.UUID) ([]db.Session, error)
	getTranscriptBySessionFn        func(ctx context.Context, sessionID uuid.UUID) (db.Transcript, error)
	listTranscriptSegmentsFn        func(ctx context.Context, transcriptID uuid.UUID) ([]db.TranscriptSegment, error)
	listReportsBySessionFn          func(ctx context.Context, sessionID uuid.UUID) ([]db.Report, error)
	softDeleteSessionsForDSARFn     func(ctx context.Context, patientFileID uuid.UUID) error
	softDeletePatientNotesForDSARFn func(ctx context.Context, patientFileID uuid.UUID) error
	softDeletePatientFileForDSARFn  func(ctx context.Context, arg db.SoftDeletePatientFileForDSARParams) (int64, error)
	softDeletePatientUserForDSARFn  func(ctx context.Context, id uuid.UUID) (int64, error)
	createAuditEventFn              func(ctx context.Context, arg db.CreateAuditEventParams) error

	// Admin Prompt Studio (docs/31)
	adminListModalityPromptsFn       func(ctx context.Context) ([]db.AdminListModalityPromptsRow, error)
	getLatestModalityPromptVersionFn func(ctx context.Context, id uuid.UUID) (int32, error)
	updateModalityLivePromptFn       func(ctx context.Context, arg db.UpdateModalityLivePromptParams) error
	insertModalityPromptVersionFn    func(ctx context.Context, arg db.InsertModalityPromptVersionParams) (db.InsertModalityPromptVersionRow, error)
	listModalityPromptVersionsFn     func(ctx context.Context, arg db.ListModalityPromptVersionsParams) ([]db.ListModalityPromptVersionsRow, error)

	// Call recorders — set non-nil to record args for later assertion.
	deletePatientUserCalls    []uuid.UUID
	hardDeletePatientFileArgs []db.HardDeletePatientFileParams
	updateSessionStatusCalls  []db.UpdateSessionStatusParams
}

func (f *fakeQuerier) GetPatientFile(ctx context.Context, id uuid.UUID) (db.PatientFile, error) {
	return f.getPatientFileFn(ctx, id)
}

func (f *fakeQuerier) GetPatientFileWithUser(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
	return f.getPatientFileWithUserFn(ctx, id)
}

func (f *fakeQuerier) UpdatePatientFile(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
	return f.updatePatientFileFn(ctx, arg)
}

func (f *fakeQuerier) UpdatePatientUser(ctx context.Context, arg db.UpdatePatientUserParams) (db.UpdatePatientUserRow, error) {
	return f.updatePatientUserFn(ctx, arg)
}

func (f *fakeQuerier) DeletePatientUser(ctx context.Context, id uuid.UUID) (int64, error) {
	f.deletePatientUserCalls = append(f.deletePatientUserCalls, id)
	return f.deletePatientUserFn(ctx, id)
}

func (f *fakeQuerier) ListSessionIDsForPatient(ctx context.Context, pid pgtype.UUID) ([]uuid.UUID, error) {
	return f.listSessionIDsForPatientFn(ctx, pid)
}

func (f *fakeQuerier) ListSessionIDsForPatientFile(ctx context.Context, id uuid.UUID) ([]uuid.UUID, error) {
	return f.listSessionIDsForPFFn(ctx, id)
}

func (f *fakeQuerier) HardDeletePatientFile(ctx context.Context, arg db.HardDeletePatientFileParams) (int64, error) {
	f.hardDeletePatientFileArgs = append(f.hardDeletePatientFileArgs, arg)
	return f.hardDeletePatientFileFn(ctx, arg)
}

func (f *fakeQuerier) HardDeleteSession(ctx context.Context, arg db.HardDeleteSessionParams) (int64, error) {
	return f.hardDeleteSessionFn(ctx, arg)
}

func (f *fakeQuerier) GetSession(ctx context.Context, id uuid.UUID) (db.Session, error) {
	return f.getSessionFn(ctx, id)
}

func (f *fakeQuerier) UpdateSessionName(ctx context.Context, arg db.UpdateSessionNameParams) (db.Session, error) {
	return f.updateSessionNameFn(ctx, arg)
}

func (f *fakeQuerier) UpdateSessionStatus(ctx context.Context, arg db.UpdateSessionStatusParams) error {
	f.updateSessionStatusCalls = append(f.updateSessionStatusCalls, arg)
	if f.updateSessionStatusFn == nil {
		return nil
	}
	return f.updateSessionStatusFn(ctx, arg)
}

func (f *fakeQuerier) GetUserOrganizationID(ctx context.Context, id uuid.UUID) (pgtype.UUID, error) {
	return f.getUserOrganizationIDFn(ctx, id)
}

// ResolvePatientEmail defaults to "no address on file" (nil) so tests
// that don't care about the e-mail leg keep passing. Set
// resolvePatientEmailFn to return an address or inject an error.
func (f *fakeQuerier) ResolvePatientEmail(ctx context.Context, id uuid.UUID) (*string, error) {
	if f.resolvePatientEmailFn == nil {
		return nil, nil
	}
	return f.resolvePatientEmailFn(ctx, id)
}

func (f *fakeQuerier) GetModalityDistribution(ctx context.Context) ([]db.GetModalityDistributionRow, error) {
	if f.getModalityDistributionFn == nil {
		return nil, nil
	}
	return f.getModalityDistributionFn(ctx)
}

func (f *fakeQuerier) GetAvgSessionDuration(ctx context.Context) (float64, error) {
	if f.getAvgSessionDurationFn == nil {
		return 0, nil
	}
	return f.getAvgSessionDurationFn(ctx)
}

func (f *fakeQuerier) GetSessionDurationTrend(ctx context.Context, since time.Time) ([]db.GetSessionDurationTrendRow, error) {
	if f.getSessionDurationTrendFn == nil {
		return nil, nil
	}
	return f.getSessionDurationTrendFn(ctx, since)
}

func (f *fakeQuerier) GetPatientNotesForExport(ctx context.Context, patientFileID uuid.UUID) ([]db.PatientNote, error) {
	return f.getPatientNotesForExportFn(ctx, patientFileID)
}

func (f *fakeQuerier) GetSessionsForExport(ctx context.Context, patientFileID uuid.UUID) ([]db.Session, error) {
	return f.getSessionsForExportFn(ctx, patientFileID)
}

func (f *fakeQuerier) GetTranscriptBySession(ctx context.Context, sessionID uuid.UUID) (db.Transcript, error) {
	return f.getTranscriptBySessionFn(ctx, sessionID)
}

func (f *fakeQuerier) ListTranscriptSegments(ctx context.Context, transcriptID uuid.UUID) ([]db.TranscriptSegment, error) {
	return f.listTranscriptSegmentsFn(ctx, transcriptID)
}

func (f *fakeQuerier) ListReportsBySession(ctx context.Context, sessionID uuid.UUID) ([]db.Report, error) {
	return f.listReportsBySessionFn(ctx, sessionID)
}

func (f *fakeQuerier) SoftDeleteSessionsForDSAR(ctx context.Context, patientFileID uuid.UUID) error {
	return f.softDeleteSessionsForDSARFn(ctx, patientFileID)
}

func (f *fakeQuerier) SoftDeletePatientNotesForDSAR(ctx context.Context, patientFileID uuid.UUID) error {
	return f.softDeletePatientNotesForDSARFn(ctx, patientFileID)
}

func (f *fakeQuerier) SoftDeletePatientFileForDSAR(ctx context.Context, arg db.SoftDeletePatientFileForDSARParams) (int64, error) {
	return f.softDeletePatientFileForDSARFn(ctx, arg)
}

func (f *fakeQuerier) SoftDeletePatientUserForDSAR(ctx context.Context, id uuid.UUID) (int64, error) {
	return f.softDeletePatientUserForDSARFn(ctx, id)
}

func (f *fakeQuerier) CreateAuditEvent(ctx context.Context, arg db.CreateAuditEventParams) error {
	if f.createAuditEventFn == nil {
		return nil
	}
	return f.createAuditEventFn(ctx, arg)
}

// fakeTxOpener — supplies Begin/Commit/Rollback failure injection plus
// a tx-scoped fakeQuerier (defaults to the same pointer as the
// pool-level one in most tests, but separable if a test wants to prove
// "tx-side mutations went to the tx, not the pool").
type fakeTxOpener struct {
	q             *fakeQuerier // tx-scoped Querier; nil → reuse parent
	beginErr      error
	commitErr     error
	rollbackErr   error
	beginCalls    int
	commitCalls   int
	rollbackCalls int
}

func (o *fakeTxOpener) Begin(ctx context.Context) (Tx, error) {
	o.beginCalls++
	if o.beginErr != nil {
		return nil, o.beginErr
	}
	return &fakeTx{parent: o}, nil
}

type fakeTx struct {
	parent *fakeTxOpener
}

func (t *fakeTx) Queries() db.Querier { return t.parent.q }

// Raw is unused by the update/delete handlers under test, but the
// interface requires it. Return nil — any handler that actually calls
// Raw().<method>(...) will panic loudly, signaling the test caught
// something it didn't expect.
func (t *fakeTx) Raw() pgx.Tx { return nil }

func (t *fakeTx) Commit(ctx context.Context) error {
	t.parent.commitCalls++
	return t.parent.commitErr
}

func (t *fakeTx) Rollback(ctx context.Context) error {
	t.parent.rollbackCalls++
	return t.parent.rollbackErr
}

// fakePublisher records every PublishSessionDeleted call. publishErr
// (when set) is returned for every publish, lets us prove the handler
// keeps going on pubsub failures.
type fakePublisher struct {
	calls           []publisherCall
	statusChanged   []publisherCall
	analyticsEvents []analytics.Event
	publishErr      error
}

type publisherCall struct {
	sessionID, therapistID string
}

func (p *fakePublisher) PublishSessionDeleted(ctx context.Context, sessionID, therapistID string) error {
	p.calls = append(p.calls, publisherCall{sessionID: sessionID, therapistID: therapistID})
	return p.publishErr
}

func (p *fakePublisher) PublishSessionStatusChanged(ctx context.Context, sessionID, statusStr string) error {
	p.statusChanged = append(p.statusChanged, publisherCall{sessionID: sessionID, therapistID: statusStr})
	return p.publishErr
}

func (p *fakePublisher) PublishAnalyticsEvent(ctx context.Context, event analytics.Event) error {
	p.analyticsEvents = append(p.analyticsEvents, event)
	return p.publishErr
}

// errSentinel — used in tests that just need "any non-nil error" out
// of a stubbed DB call. Distinct value so tests can match it directly
// when the handler wraps it.
var errSentinel = errors.New("stub error")

// fakeBilling implements just enough of billingv1.BillingServiceClient
// for the CancelSession release path. The nil embed makes every other
// method panic loudly — an unexpected billing call in a test is a bug.
type fakeBilling struct {
	billingv1.BillingServiceClient // nil embed

	releaseErr   error
	releaseCalls []*billingv1.ReleaseCreditRequest
}

func (b *fakeBilling) ReleaseCredit(ctx context.Context, in *billingv1.ReleaseCreditRequest, _ ...grpc.CallOption) (*emptypb.Empty, error) {
	b.releaseCalls = append(b.releaseCalls, in)
	if b.releaseErr != nil {
		return nil, b.releaseErr
	}
	return &emptypb.Empty{}, nil
}

// ─── Admin Prompt Studio fakes (docs/31) ────────────────────────────

func (f *fakeQuerier) AdminListModalityPrompts(ctx context.Context) ([]db.AdminListModalityPromptsRow, error) {
	return f.adminListModalityPromptsFn(ctx)
}

func (f *fakeQuerier) GetLatestModalityPromptVersion(ctx context.Context, id uuid.UUID) (int32, error) {
	return f.getLatestModalityPromptVersionFn(ctx, id)
}

func (f *fakeQuerier) UpdateModalityLivePrompt(ctx context.Context, arg db.UpdateModalityLivePromptParams) error {
	return f.updateModalityLivePromptFn(ctx, arg)
}

func (f *fakeQuerier) InsertModalityPromptVersion(ctx context.Context, arg db.InsertModalityPromptVersionParams) (db.InsertModalityPromptVersionRow, error) {
	return f.insertModalityPromptVersionFn(ctx, arg)
}

func (f *fakeQuerier) ListModalityPromptVersions(ctx context.Context, arg db.ListModalityPromptVersionsParams) ([]db.ListModalityPromptVersionsRow, error) {
	return f.listModalityPromptVersionsFn(ctx, arg)
}
