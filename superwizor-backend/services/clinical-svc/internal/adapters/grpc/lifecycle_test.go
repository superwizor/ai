package grpc

// Tests for the lifecycle_status feature (migration 000058).
//
// Covers:
//   - UpdatePatientFile with lifecycle_status propagation
//   - lifecycle_status reflected in proto response
//   - is_process_closed derived from lifecycle_status
//   - Empty lifecycle_status is a no-op (keeps existing value)
//   - All three valid values: ACTIVE, COMPLETED, PAUSED

import (
	"context"
	"testing"

	"github.com/google/uuid"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"
)

// =================================================================
//   UpdatePatientFile — lifecycle_status
// =================================================================

// When lifecycle_status is sent, the handler must forward it to the
// SQL params and the response must reflect the updated value.
func TestUpdatePatientFile_LifecycleStatusPropagates(t *testing.T) {
	tests := []struct {
		name            string
		lifecycleStatus string
		wantInParams    string
		wantInResponse  string
	}{
		{
			name:            "set COMPLETED",
			lifecycleStatus: "COMPLETED",
			wantInParams:    "COMPLETED",
			wantInResponse:  "COMPLETED",
		},
		{
			name:            "set PAUSED",
			lifecycleStatus: "PAUSED",
			wantInParams:    "PAUSED",
			wantInResponse:  "PAUSED",
		},
		{
			name:            "set ACTIVE",
			lifecycleStatus: "ACTIVE",
			wantInParams:    "ACTIVE",
			wantInResponse:  "ACTIVE",
		},
		{
			name:            "empty lifecycle_status (no change)",
			lifecycleStatus: "",
			wantInParams:    "",
			wantInResponse:  "ACTIVE", // fixture default from refetch
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pfID := uuid.New()
			therapistID := uuid.New()
			patientID := uuid.New()

			var receivedParams db.UpdatePatientFileParams
			q := &fakeQuerier{
				updatePatientFileFn: func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
					receivedParams = arg
					return db.PatientFile{ID: arg.ID}, nil
				},
				getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
					row := withUserRowFixture(id, therapistID, &patientID)
					// Simulate what the DB would return after the update.
					if tt.lifecycleStatus != "" {
						row.LifecycleStatus = tt.lifecycleStatus
					} else {
						row.LifecycleStatus = "ACTIVE"
					}
					return row, nil
				},
			}
			srv := newTestServer(q, nil, nil)

			resp, err := srv.UpdatePatientFile(context.Background(), &clinicalv1.UpdatePatientFileRequest{
				PatientFileId:   pfID.String(),
				LifecycleStatus: tt.lifecycleStatus,
			})
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			// Verify the params forwarded to SQL.
			if receivedParams.Column6 != tt.wantInParams {
				t.Errorf("UpdatePatientFileParams.Column6 (lifecycle_status): want %q, got %q",
					tt.wantInParams, receivedParams.Column6)
			}

			// Verify the response proto carries the value.
			if resp.LifecycleStatus != tt.wantInResponse {
				t.Errorf("response.LifecycleStatus: want %q, got %q",
					tt.wantInResponse, resp.LifecycleStatus)
			}
		})
	}
}

// Verify that is_process_closed is correctly derived from lifecycle_status
// in the request. When lifecycle_status is "COMPLETED", is_process_closed
// should be true (server does this via SQL CASE), but the handler must
// still forward the request's is_process_closed field as-is; the SQL
// CASE only overrides when lifecycle_status is non-empty.
func TestUpdatePatientFile_IsProcessClosedDerivation(t *testing.T) {
	tests := []struct {
		name                string
		lifecycleStatus     string
		isProcessClosed     bool
		wantIsProcessClosed bool
	}{
		{
			name:                "lifecycle empty, explicit is_process_closed=true",
			lifecycleStatus:     "",
			isProcessClosed:     true,
			wantIsProcessClosed: true,
		},
		{
			name:                "lifecycle empty, explicit is_process_closed=false",
			lifecycleStatus:     "",
			isProcessClosed:     false,
			wantIsProcessClosed: false,
		},
		{
			name:                "lifecycle COMPLETED overrides is_process_closed to true in SQL",
			lifecycleStatus:     "COMPLETED",
			isProcessClosed:     false, // ignored when lifecycle is set
			wantIsProcessClosed: false, // handler passes through; SQL CASE does the override
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var receivedParams db.UpdatePatientFileParams
			q := &fakeQuerier{
				updatePatientFileFn: func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
					receivedParams = arg
					return db.PatientFile{ID: arg.ID}, nil
				},
				getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
					return withUserRowFixture(id, uuid.New(), nil), nil
				},
			}
			srv := newTestServer(q, nil, nil)

			_, err := srv.UpdatePatientFile(context.Background(), &clinicalv1.UpdatePatientFileRequest{
				PatientFileId:   uuid.New().String(),
				LifecycleStatus: tt.lifecycleStatus,
				IsProcessClosed: tt.isProcessClosed,
			})
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if receivedParams.IsProcessClosed != tt.wantIsProcessClosed {
				t.Errorf("IsProcessClosed: want %v, got %v",
					tt.wantIsProcessClosed, receivedParams.IsProcessClosed)
			}
		})
	}
}

// Lifecycle status must appear in the proto response via the JOIN mapper.
// This tests the mapper path specifically.
func TestUpdatePatientFile_LifecycleInRefetchResponse(t *testing.T) {
	pfID := uuid.New()
	therapistID := uuid.New()
	patientID := uuid.New()

	q := &fakeQuerier{
		updatePatientFileFn: func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
			return db.PatientFile{ID: arg.ID}, nil
		},
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			row := withUserRowFixture(id, therapistID, &patientID)
			row.LifecycleStatus = "PAUSED"
			return row, nil
		},
	}
	srv := newTestServer(q, nil, nil)

	resp, err := srv.UpdatePatientFile(context.Background(), &clinicalv1.UpdatePatientFileRequest{
		PatientFileId:   pfID.String(),
		LifecycleStatus: "PAUSED",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if resp.LifecycleStatus != "PAUSED" {
		t.Errorf("response must carry lifecycle_status from the JOINed row; got %q", resp.LifecycleStatus)
	}
}

// Verify that the existing HappyPath test still works — regression guard.
// The lifecycle_status defaults to "" when not set, which the SQL treats
// as a no-op for the lifecycle column.
func TestUpdatePatientFile_LegacyWithoutLifecycle(t *testing.T) {
	pfID := uuid.New()
	therapistID := uuid.New()

	var received db.UpdatePatientFileParams
	q := &fakeQuerier{
		updatePatientFileFn: func(ctx context.Context, arg db.UpdatePatientFileParams) (db.PatientFile, error) {
			received = arg
			return db.PatientFile{ID: arg.ID}, nil
		},
		getPatientFileWithUserFn: func(ctx context.Context, id uuid.UUID) (db.GetPatientFileWithUserRow, error) {
			row := withUserRowFixture(id, therapistID, nil)
			row.LifecycleStatus = "ACTIVE"
			return row, nil
		},
	}
	srv := newTestServer(q, nil, nil)

	resp, err := srv.UpdatePatientFile(context.Background(), &clinicalv1.UpdatePatientFileRequest{
		PatientFileId: pfID.String(),
		WorkingAlias:  "Legacy Update",
		// No lifecycle_status set — old client behavior.
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// lifecycle_status must be "" in params (SQL no-op).
	if received.Column6 != "" {
		t.Errorf("legacy update must not set lifecycle_status; got %q", received.Column6)
	}

	// Response still carries the DB value.
	if resp.LifecycleStatus != "ACTIVE" {
		t.Errorf("response.LifecycleStatus: want ACTIVE, got %q", resp.LifecycleStatus)
	}
}
