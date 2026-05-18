package grpc

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"
)

// TestHealthCheck verifies basic server liveness
func TestHealthCheck(t *testing.T) {
	srv := NewServer(nil, nil, "test-1.0")
	resp, err := srv.HealthCheck(context.Background(), &emptypb.Empty{})
	require.NoError(t, err)
	assert.Equal(t, "OK", resp.Status)
	assert.Equal(t, "test-1.0", resp.Version)
}

func TestToProtoRole(t *testing.T) {
	tests := []struct {
		dbRole   db.UserRole
		expected identityv1.UserRole
	}{
		{"THERAPIST", identityv1.UserRole_USER_ROLE_THERAPIST},
		{"PATIENT", identityv1.UserRole_USER_ROLE_PATIENT},
		{"UNKNOWN", identityv1.UserRole_USER_ROLE_UNSPECIFIED},
	}

	for _, tt := range tests {
		t.Run(string(tt.dbRole), func(t *testing.T) {
			assert.Equal(t, tt.expected, toProtoRole(tt.dbRole))
		})
	}
}

func TestToProtoUser(t *testing.T) {
	id := uuid.New()
	orgID := uuid.New()

	fbUID := "firebase-uid-123"
	email := "test@example.com"
	user := db.User{
		ID:             id,
		Role:           "THERAPIST",
		OrganizationID: pgtype.UUID{Bytes: orgID, Valid: true},
		FirebaseUid:    &fbUID,
		Email:          &email,
		FirstName:      "Anna",
		LastName:       "Kowalska",
		UiLanguage:     "pl",
		Timezone:       "Europe/Warsaw",
		HasAcceptedTos: true,
	}

	proto := toProtoUser(user)

	assert.Equal(t, id.String(), proto.Id)
	assert.Equal(t, identityv1.UserRole_USER_ROLE_THERAPIST, proto.Role)
	assert.Equal(t, orgID.String(), proto.OrganizationId)
	assert.Equal(t, "test@example.com", proto.Email)
	assert.Equal(t, "Anna", proto.FirstName)
}
