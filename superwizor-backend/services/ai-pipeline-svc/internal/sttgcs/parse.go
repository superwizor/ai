// Package sttgcs holds pure functions for the GCS-callback STT flow:
// parsing Chirp's output object paths and merging per-chunk results
// into a single transcript stream. No GCS/DB/Speech client
// dependencies — everything here is fixture-testable in isolation.
//
// Stage 1 (current): single-chunk per session, no overlap, no
// alignment. MergeChirpResults degenerates to passthrough for one
// ChunkResult.
//
// Stage 2 (forthcoming): multi-chunk with overlapping audio,
// time-anchored speaker-label alignment via AlignAndMapSpeakers.
// See docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md.
package sttgcs

import (
	"fmt"
	"path"
	"strconv"
	"strings"

	"github.com/google/uuid"
)

// OutputObjectPath identifies a Chirp BatchRecognize output file
// inside the transcripts-raw bucket.
//
// Path convention (controlled by stt-submit's outputPrefixFor helper):
//
//	{session_id}/chunk_{chunk_index}/transcript_{op_hash}.json
//
// The session_id + chunk_index pair lets the finalize handler look up
// the matching stt_operations row idempotently. We don't try to
// predict the {op_hash} portion of the filename — Chirp picks it.
type OutputObjectPath struct {
	SessionID  uuid.UUID
	ChunkIndex int
}

// ParseOutputObjectPath extracts (session_id, chunk_index) from the
// GCS object name reported by OBJECT_FINALIZE. Returns ok=false for
// any path that doesn't match the expected three-segment shape —
// callers should silently skip those (sidecar metadata files, junk
// uploads, etc.) instead of failing the function invocation.
//
// Expected shape:
//
//	{session_uuid}/chunk_{int}/transcript_{anything}.json
//
// Rejected (ok=false):
//   - fewer than 3 path components
//   - top-level segment not a valid UUID
//   - middle segment not "chunk_<int>"
//   - leaf filename not "transcript_*.json"
func ParseOutputObjectPath(objectName string) (OutputObjectPath, bool) {
	// Strip a leading slash if some Eventarc payload variant adds one.
	objectName = strings.TrimPrefix(objectName, "/")
	parts := strings.Split(objectName, "/")
	if len(parts) != 3 {
		return OutputObjectPath{}, false
	}

	sid, err := uuid.Parse(parts[0])
	if err != nil {
		return OutputObjectPath{}, false
	}

	const chunkPrefix = "chunk_"
	if !strings.HasPrefix(parts[1], chunkPrefix) {
		return OutputObjectPath{}, false
	}
	chunkStr := strings.TrimPrefix(parts[1], chunkPrefix)
	chunkIdx, err := strconv.Atoi(chunkStr)
	if err != nil || chunkIdx < 0 {
		return OutputObjectPath{}, false
	}

	leaf := parts[2]
	if !strings.HasPrefix(leaf, "transcript_") || path.Ext(leaf) != ".json" {
		return OutputObjectPath{}, false
	}

	return OutputObjectPath{SessionID: sid, ChunkIndex: chunkIdx}, true
}

// OutputPrefixFor returns the gs://-stripped prefix that
// stt-submit writes into BatchRecognizeRequest.GcsOutputConfig.Uri
// for the given (session_id, chunk_index). Format mirrors
// ParseOutputObjectPath above so any prefix produced here will round-
// trip through the parser when Chirp drops the transcript file.
//
// Caller usually wraps with "gs://<bucket>/" for the actual URI.
func OutputPrefixFor(sessionID uuid.UUID, chunkIndex int) string {
	return fmt.Sprintf("%s/chunk_%d/", sessionID.String(), chunkIndex)
}
