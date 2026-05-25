package pubsub

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/google/uuid"
)

type mockAudioPublisher struct {
	published []struct {
		sessionID  string
		uploadID   string
		objectPath string
	}
	err error
}

func (m *mockAudioPublisher) PublishAudioUploaded(ctx context.Context, sessionID, uploadID, objectPath string) error {
	m.published = append(m.published, struct {
		sessionID  string
		uploadID   string
		objectPath string
	}{sessionID, uploadID, objectPath})
	return m.err
}

func TestParseSessionIDFromObjectPath(t *testing.T) {
	therapistUUID := uuid.New().String()
	sessionUUID := uuid.New().String()

	cases := []struct {
		name    string
		path    string
		want    string
		wantErr bool
	}{
		{
			name:    "Happy Path FLAC",
			path:    therapistUUID + "/" + sessionUUID + "/17162524.flac",
			want:    sessionUUID,
			wantErr: false,
		},
		{
			name:    "Happy Path M4A",
			path:    therapistUUID + "/" + sessionUUID + "/17162524.m4a",
			want:    sessionUUID,
			wantErr: false,
		},
		{
			name:    "Invalid format - too few parts",
			path:    therapistUUID + "/17162524.m4a",
			want:    "",
			wantErr: true,
		},
		{
			name:    "Invalid therapist UUID",
			path:    "not-a-uuid/" + sessionUUID + "/17162524.m4a",
			want:    "",
			wantErr: true,
		},
		{
			name:    "Invalid session UUID",
			path:    therapistUUID + "/not-a-uuid/17162524.m4a",
			want:    "",
			wantErr: true,
		},
		{
			// Defensive — if someone sneaks a nested prefix into the
			// object path (e.g. `audio-chunks-staging/{therapist}/{session}/...`)
			// we should still pick the right session UUID out of position 1.
			// This test guards against a refactor that loosens the strict
			// "parts[0]=therapist, parts[1]=session" assumption.
			name:    "Path with extra trailing component is still parseable",
			path:    therapistUUID + "/" + sessionUUID + "/subdir/audio.flac",
			want:    sessionUUID,
			wantErr: false,
		},
		{
			name:    "Empty string",
			path:    "",
			want:    "",
			wantErr: true,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := parseSessionIDFromObjectPath(tc.path)
			if (err != nil) != tc.wantErr {
				t.Fatalf("parseSessionIDFromObjectPath(%q) returned err = %v, wantErr = %v", tc.path, err, tc.wantErr)
			}
			if !tc.wantErr {
				if got.String() != tc.want {
					t.Errorf("parseSessionIDFromObjectPath(%q) = %q, want %q", tc.path, got.String(), tc.want)
				}
			}
		})
	}
}

// Regression guard: the JSON shape emitted by google_storage_notification
// with payload_format = "JSON_API_V1" must be parseable into
// StorageObjectData. If GCS ever changes the field names ("bucket",
// "name") this test fails at build time instead of at 3am in production.
//
// Sample payload pulled from the official GCS docs:
// https://cloud.google.com/storage/docs/json_api/v1/objects#resource
func TestStorageObjectData_UnmarshalsCanonicalGCSPayload(t *testing.T) {
	// Trimmed JSON_API_V1 sample — real GCS payloads contain ~30
	// fields but the subscriber only consumes bucket + name.
	raw := []byte(`{
		"kind": "storage#object",
		"id": "supervisor-staging-audio-uploads/abc/def/123.flac/1716250000",
		"selfLink": "https://www.googleapis.com/...",
		"name": "abc/def/123.flac",
		"bucket": "supervisor-staging-audio-uploads",
		"generation": "1716250000000000",
		"contentType": "audio/flac",
		"timeCreated": "2026-05-25T10:00:00.000Z",
		"size": "12345"
	}`)

	var d StorageObjectData
	if err := json.Unmarshal(raw, &d); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if d.Bucket != "supervisor-staging-audio-uploads" {
		t.Errorf("Bucket = %q, want supervisor-staging-audio-uploads", d.Bucket)
	}
	if d.Name != "abc/def/123.flac" {
		t.Errorf("Name = %q, want abc/def/123.flac", d.Name)
	}
}

// mockAudioPublisher captures the calls handleMessage makes when it
// republishes the structured audio.uploaded event. Used by future
// handler-level tests (which need a Cloud SQL test harness — not yet
// in place for ingestion-svc). Kept here so the wiring exists when
// that harness lands.
func TestMockAudioPublisher_Captures(t *testing.T) {
	m := &mockAudioPublisher{}
	_ = m.PublishAudioUploaded(context.Background(), "s1", "u1", "p1")
	if len(m.published) != 1 {
		t.Fatalf("len(published) = %d, want 1", len(m.published))
	}
	if m.published[0].sessionID != "s1" || m.published[0].uploadID != "u1" || m.published[0].objectPath != "p1" {
		t.Errorf("captured wrong values: %+v", m.published[0])
	}
}
