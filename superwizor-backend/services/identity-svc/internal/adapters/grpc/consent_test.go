package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

type consentFakeQuerier struct {
	db.Querier
	getUserByIDFn    func(ctx context.Context, id uuid.UUID) (db.User, error)
	recordConsentFn  func(ctx context.Context, arg db.RecordConsentParams) (db.ConsentRecord, error)
	userByFirebaseUID db.User
}

func (f *consentFakeQuerier) GetUserByID(ctx context.Context, id uuid.UUID) (db.User, error) {
	if f.getUserByIDFn != nil {
		return f.getUserByIDFn(ctx, id)
	}
	return db.User{}, pgx.ErrNoRows
}

func (f *consentFakeQuerier) GetUserByFirebaseUID(ctx context.Context, uid *string) (db.User, error) {
	return f.userByFirebaseUID, nil
}

func (f *consentFakeQuerier) RecordConsent(ctx context.Context, arg db.RecordConsentParams) (db.ConsentRecord, error) {
	if f.recordConsentFn != nil {
		return f.recordConsentFn(ctx, arg)
	}
	return db.ConsentRecord{}, nil
}

func TestRecordConsent_Self(t *testing.T) {
	callerID := uuid.New()
	fbUID := "fb-caller-123"
	email := "therapist@example.com"

	queries := &consentFakeQuerier{
		userByFirebaseUID: db.User{
			ID:          callerID,
			Role:        "THERAPIST",
			FirebaseUid: &fbUID,
			Email:       &email,
		},
	}

	verifier := &mockTokenVerifier{
		uid: fbUID,
	}

	srv := NewServer(nil, queries, verifier, "test", nil)

	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs("authorization", "Bearer token-123"))

	recorded := false
	queries.recordConsentFn = func(ctx context.Context, arg db.RecordConsentParams) (db.ConsentRecord, error) {
		assert.Equal(t, callerID, arg.UserID)
		assert.Equal(t, "TOS", arg.ConsentType)
		assert.True(t, arg.Granted)
		assert.Equal(t, "v1.0", *arg.ConsentVersion)
		assert.Equal(t, "127.0.0.1", *arg.IpAddress)
		assert.Equal(t, "Mozilla/5.0", *arg.UserAgent)
		recorded = true
		return db.ConsentRecord{
			ID:         uuid.New(),
			UserID:     callerID,
			RecordedAt: time.Now(),
		}, nil
	}

	resp, err := srv.RecordConsent(ctx, &identityv1.RecordConsentRequest{
		UserId:         callerID.String(),
		ConsentType:    "TOS",
		Granted:        true,
		ConsentVersion: "v1.0",
		IpAddress:      "127.0.0.1",
		UserAgent:      "Mozilla/5.0",
	})

	require.NoError(t, err)
	assert.True(t, recorded)
	assert.NotEmpty(t, resp.ConsentRecordId)
}

func TestRecordConsent_TherapistOnBehalfOfPatient(t *testing.T) {
	therapistID := uuid.New()
	patientID := uuid.New()
	fbUID := "fb-therapist-123"
	email := "therapist@example.com"

	queries := &consentFakeQuerier{
		userByFirebaseUID: db.User{
			ID:          therapistID,
			Role:        "THERAPIST",
			FirebaseUid: &fbUID,
			Email:       &email,
		},
	}

	queries.getUserByIDFn = func(ctx context.Context, id uuid.UUID) (db.User, error) {
		if id == patientID {
			return db.User{
				ID:   patientID,
				Role: "PATIENT",
			}, nil
		}
		return db.User{}, pgx.ErrNoRows
	}

	verifier := &mockTokenVerifier{
		uid: fbUID,
	}

	srv := NewServer(nil, queries, verifier, "test", nil)
	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs("authorization", "Bearer token-123"))

	recorded := false
	queries.recordConsentFn = func(ctx context.Context, arg db.RecordConsentParams) (db.ConsentRecord, error) {
		assert.Equal(t, patientID, arg.UserID)
		assert.Equal(t, "RECORDING", arg.ConsentType)
		assert.True(t, arg.Granted)
		recorded = true
		return db.ConsentRecord{
			ID:         uuid.New(),
			UserID:     patientID,
			RecordedAt: time.Now(),
		}, nil
	}

	resp, err := srv.RecordConsent(ctx, &identityv1.RecordConsentRequest{
		UserId:      patientID.String(),
		ConsentType: "RECORDING",
		Granted:     true,
	})

	require.NoError(t, err)
	assert.True(t, recorded)
	assert.NotEmpty(t, resp.ConsentRecordId)
}

func TestRecordConsent_PermissionDenied(t *testing.T) {
	therapistID := uuid.New()
	otherTherapistID := uuid.New()
	fbUID := "fb-therapist-123"
	email := "therapist@example.com"

	queries := &consentFakeQuerier{
		userByFirebaseUID: db.User{
			ID:          therapistID,
			Role:        "THERAPIST",
			FirebaseUid: &fbUID,
			Email:       &email,
		},
	}

	queries.getUserByIDFn = func(ctx context.Context, id uuid.UUID) (db.User, error) {
		if id == otherTherapistID {
			return db.User{
				ID:   otherTherapistID,
				Role: "THERAPIST",
			}, nil
		}
		return db.User{}, pgx.ErrNoRows
	}

	verifier := &mockTokenVerifier{
		uid: fbUID,
	}

	srv := NewServer(nil, queries, verifier, "test", nil)
	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs("authorization", "Bearer token-123"))

	_, err := srv.RecordConsent(ctx, &identityv1.RecordConsentRequest{
		UserId:      otherTherapistID.String(),
		ConsentType: "TOS",
		Granted:     true,
	})

	require.Error(t, err)
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}
