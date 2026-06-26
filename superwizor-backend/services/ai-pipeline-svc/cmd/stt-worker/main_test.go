package sttworker

import (
	"fmt"
	"testing"
	"time"

	"cloud.google.com/go/speech/apiv2/speechpb"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/genproto/googleapis/rpc/status"
	"google.golang.org/grpc/codes"
	grpcstatuspkg "google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/durationpb"

	"github.com/superwizor-ai/backend/pkg/transcription/chunker"
)

// TestParseChirp3Results — default flow (USE_NATIVE_DIARIZATION=false).
// Słowa są zwracane bez speaker_tag — LLM zrobi diarization (ADR-IMPL-007).
func TestParseChirp3Results(t *testing.T) {
	resp := &speechpb.BatchRecognizeResponse{
		Results: map[string]*speechpb.BatchRecognizeFileResult{
			"file1": {
				Result: &speechpb.BatchRecognizeFileResult_InlineResult{
					InlineResult: &speechpb.InlineResult{
						Transcript: &speechpb.BatchRecognizeResults{
							Results: []*speechpb.SpeechRecognitionResult{
								{
									Alternatives: []*speechpb.SpeechRecognitionAlternative{
										{
											Transcript: "Hello world. How are you?",
											Confidence: 0.9,
											Words: []*speechpb.WordInfo{
												{Word: "Hello", StartOffset: durationpb.New(100 * time.Millisecond), EndOffset: durationpb.New(500 * time.Millisecond)},
												{Word: "world.", StartOffset: durationpb.New(500 * time.Millisecond), EndOffset: durationpb.New(1000 * time.Millisecond)},
												{Word: "How", StartOffset: durationpb.New(1700 * time.Millisecond), EndOffset: durationpb.New(1800 * time.Millisecond)},
												{Word: "are", StartOffset: durationpb.New(1800 * time.Millisecond), EndOffset: durationpb.New(1900 * time.Millisecond)},
												{Word: "you?", StartOffset: durationpb.New(1900 * time.Millisecond), EndOffset: durationpb.New(2100 * time.Millisecond)},
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}

	result, err := ParseChirp3Results(resp, false, "pl-PL")
	assert.NoError(t, err)

	assert.NotNil(t, result)
	assert.Equal(t, "pl-PL", result.LanguageCode)
	assert.Equal(t, 5, result.WordCount)
	assert.Equal(t, float32(0.9), result.ConfidenceAvg)
	assert.False(t, result.HasNativeDiarization)
	assert.Equal(t, 0, result.SpeakerCount)
	assert.Len(t, result.Words, 5)

	// Words → chunker robi grouping. Pauza 700ms (1000→1700) → split.
	chunks := chunker.ChunkByPauses(result.Words, chunker.DefaultConfig())
	assert.Len(t, chunks, 2)
	assert.Equal(t, "Hello world.", chunks[0].Text)
	assert.Equal(t, "How are you?", chunks[1].Text)
}

// TestParseChirp3Results_DropsImplausibleWordOffsets — regression guard for
// session 12d8c857 (2026-06-08): Chirp emitted a word whose StartOffset was
// ~281.6 million seconds (281,646,122,235 ms). Faithfully carrying it
// overflowed the int4 transcript_segments.start_offset_ms column →
// persistTranscript failed → the session hung in TRANSCRIBING forever.
// ParseChirp3Results must now drop such garbage words and keep the good ones.
func TestParseChirp3Results_DropsImplausibleWordOffsets(t *testing.T) {
	// The exact production value: 281,646,122,235 ms ≈ 8.9 years.
	garbageOffset := durationpb.New(281646122235 * time.Millisecond)
	resp := &speechpb.BatchRecognizeResponse{
		Results: map[string]*speechpb.BatchRecognizeFileResult{
			"file1": {
				Result: &speechpb.BatchRecognizeFileResult_InlineResult{
					InlineResult: &speechpb.InlineResult{
						Transcript: &speechpb.BatchRecognizeResults{
							Results: []*speechpb.SpeechRecognitionResult{
								{
									LanguageCode: "pl-PL",
									Alternatives: []*speechpb.SpeechRecognitionAlternative{
										{
											Confidence: 0.9,
											Words: []*speechpb.WordInfo{
												{Word: "Dzień", StartOffset: durationpb.New(100 * time.Millisecond), EndOffset: durationpb.New(500 * time.Millisecond)},
												// Garbage: absurd absolute offset (the prod bug).
												{Word: "GARBAGE", StartOffset: garbageOffset, EndOffset: durationpb.New(garbageOffset.AsDuration() + 200*time.Millisecond)},
												// Garbage: end before start.
												{Word: "REVERSED", StartOffset: durationpb.New(900 * time.Millisecond), EndOffset: durationpb.New(800 * time.Millisecond)},
												// Garbage: negative offset.
												{Word: "NEG", StartOffset: durationpb.New(-5 * time.Millisecond), EndOffset: durationpb.New(10 * time.Millisecond)},
												{Word: "dobry.", StartOffset: durationpb.New(600 * time.Millisecond), EndOffset: durationpb.New(1000 * time.Millisecond)},
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}

	result, err := ParseChirp3Results(resp, false, "pl-PL")
	require.NoError(t, err)
	require.NotNil(t, result)

	// Only the two plausible words survive.
	assert.Equal(t, 2, result.WordCount)
	require.Len(t, result.Words, 2)
	assert.Equal(t, "Dzień", result.Words[0].Text)
	assert.Equal(t, "dobry.", result.Words[1].Text)

	// Every surviving offset is within int4 range (the overflow is gone).
	for _, w := range result.Words {
		assert.LessOrEqual(t, w.StartMS, int64(maxPlausibleWordOffsetMS))
		assert.GreaterOrEqual(t, w.StartMS, int64(0))
		assert.GreaterOrEqual(t, w.EndMS, w.StartMS)
		assert.Less(t, w.StartMS, int64(2147483647), "must fit int4 transcript_segments.start_offset_ms")
	}
}

// TestParseChirp3Results_NativeDiarization — feature flag USE_NATIVE_DIARIZATION=true
// (przyszła ścieżka gdy polski będzie supported).
func TestParseChirp3Results_NativeDiarization(t *testing.T) {
	resp := &speechpb.BatchRecognizeResponse{
		Results: map[string]*speechpb.BatchRecognizeFileResult{
			"file1": {
				Result: &speechpb.BatchRecognizeFileResult_InlineResult{
					InlineResult: &speechpb.InlineResult{
						Transcript: &speechpb.BatchRecognizeResults{
							Results: []*speechpb.SpeechRecognitionResult{
								{
									Alternatives: []*speechpb.SpeechRecognitionAlternative{
										{
											Confidence: 0.9,
											Words: []*speechpb.WordInfo{
												{Word: "Hi", StartOffset: durationpb.New(0), EndOffset: durationpb.New(200 * time.Millisecond), SpeakerLabel: "speaker_1"},
												{Word: "Hello", StartOffset: durationpb.New(300 * time.Millisecond), EndOffset: durationpb.New(600 * time.Millisecond), SpeakerLabel: "speaker_2"},
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}

	result, err := ParseChirp3Results(resp, true, "pl-PL")
	assert.NoError(t, err)

	assert.True(t, result.HasNativeDiarization)
	assert.Equal(t, 2, result.SpeakerCount)
}

// TestParseChirp3Results_FileError — the silent-failure regression that
// produced WordCount=0 sessions when Chirp 3 rejected the codec (M4A/AAC).
// We must propagate fileResult.Error so the caller fails the session
// loudly instead of treating "empty transcript + INTERNAL error" as success.
func TestParseChirp3Results_FileError(t *testing.T) {
	resp := &speechpb.BatchRecognizeResponse{
		Results: map[string]*speechpb.BatchRecognizeFileResult{
			"gs://bucket/sample.m4a": {
				Error: &status.Status{
					Code:    13, // INTERNAL
					Message: "Internal error encountered.",
				},
			},
		},
	}

	result, err := ParseChirp3Results(resp, false, "pl-PL")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "code=13")
	assert.Contains(t, err.Error(), "Internal error encountered")
	// We still return a (zero-valued) result so the caller has language /
	// useNativeDiarization context for logging if it wants — but the error
	// is the primary signal.
	assert.NotNil(t, result)
	assert.Equal(t, 0, result.WordCount)
}

// TestFillSpeakerLabels — Chirp 3 native diarization occasionally
// drops per-word speaker labels. fillSpeakerLabels recovers most by
// forward/backward-propagating the nearest labeled neighbor, bounded
// by the chunker's pause threshold so we don't silently propagate
// across a speaker change.
func TestFillSpeakerLabels(t *testing.T) {
	t.Run("forward fill within continuous speech", func(t *testing.T) {
		// "1" "" "" "1" — gap-less, last two should inherit "1".
		words := []chunker.Word{
			{Text: "a", StartMS: 0, EndMS: 100, SpeakerLabel: "1"},
			{Text: "b", StartMS: 100, EndMS: 200, SpeakerLabel: ""},
			{Text: "c", StartMS: 200, EndMS: 300, SpeakerLabel: ""},
			{Text: "d", StartMS: 300, EndMS: 400, SpeakerLabel: "1"},
		}
		fillSpeakerLabels(words, 600)
		assert.Equal(t, []string{"1", "1", "1", "1"}, labelsOf(words))
	})

	t.Run("forward fill stops at pause boundary", func(t *testing.T) {
		// "1" "" [800ms pause] "" "2" — first "" inherits "1", second
		// "" stays "" because the pause crossed first (then gets the
		// backward "2" treatment).
		words := []chunker.Word{
			{Text: "a", StartMS: 0, EndMS: 100, SpeakerLabel: "1"},
			{Text: "b", StartMS: 100, EndMS: 200, SpeakerLabel: ""},
			{Text: "c", StartMS: 1000, EndMS: 1100, SpeakerLabel: ""}, // 800ms gap from "b"
			{Text: "d", StartMS: 1100, EndMS: 1200, SpeakerLabel: "2"},
		}
		fillSpeakerLabels(words, 600)
		// b: inherits "1" (no pause from a, gap=0)
		// c: forward pass cuts at pause; backward pass picks "2" (gap c↔d = 0)
		assert.Equal(t, []string{"1", "1", "2", "2"}, labelsOf(words))
	})

	t.Run("backward fill leading unlabeled words", func(t *testing.T) {
		// "" "" "1" — both leading words should backward-inherit "1".
		words := []chunker.Word{
			{Text: "a", StartMS: 0, EndMS: 100, SpeakerLabel: ""},
			{Text: "b", StartMS: 100, EndMS: 200, SpeakerLabel: ""},
			{Text: "c", StartMS: 200, EndMS: 300, SpeakerLabel: "1"},
		}
		fillSpeakerLabels(words, 600)
		assert.Equal(t, []string{"1", "1", "1"}, labelsOf(words))
	})

	t.Run("all unlabeled stays unlabeled", func(t *testing.T) {
		// No labels at all — nothing to propagate. Preserves the
		// "Chirp couldn't diarize" degradation path (downstream LLM
		// clustering handles it).
		words := []chunker.Word{
			{Text: "a", StartMS: 0, EndMS: 100, SpeakerLabel: ""},
			{Text: "b", StartMS: 100, EndMS: 200, SpeakerLabel: ""},
		}
		fillSpeakerLabels(words, 600)
		assert.Equal(t, []string{"", ""}, labelsOf(words))
	})

	t.Run("all labeled is no-op", func(t *testing.T) {
		// Defense against regression — labeled words must never be
		// overwritten by fill (the forward pass only touches "").
		words := []chunker.Word{
			{Text: "a", StartMS: 0, EndMS: 100, SpeakerLabel: "1"},
			{Text: "b", StartMS: 200, EndMS: 300, SpeakerLabel: "2"},
			{Text: "c", StartMS: 400, EndMS: 500, SpeakerLabel: "1"},
		}
		fillSpeakerLabels(words, 600)
		assert.Equal(t, []string{"1", "2", "1"}, labelsOf(words))
	})

	t.Run("empty slice is safe", func(t *testing.T) {
		fillSpeakerLabels([]chunker.Word{}, 600) // must not panic
	})

	t.Run("session 26ecf316 shape — sparse labeling of one speaker", func(t *testing.T) {
		// Simulates the production regression: speaker_1 labeled
		// consistently, speaker_2 returned without labels. After fill
		// the un-labeled words in the patient's turn should NOT
		// inherit speaker_1 because there's a pause between turns.
		words := []chunker.Word{
			// Therapist turn (labeled "1")
			{Text: "t1", StartMS: 0, EndMS: 200, SpeakerLabel: "1"},
			{Text: "t2", StartMS: 200, EndMS: 500, SpeakerLabel: "1"},
			// 800ms pause — speaker change
			// Patient turn (labels dropped)
			{Text: "p1", StartMS: 1300, EndMS: 1500, SpeakerLabel: ""},
			{Text: "p2", StartMS: 1500, EndMS: 1800, SpeakerLabel: ""},
		}
		fillSpeakerLabels(words, 600)
		// Therapist words preserved, patient words stay "" because
		// the pause across speakers prevented propagation. The
		// downstream llm-worker fallback handles tag=0 reattach.
		assert.Equal(t, []string{"1", "1", "", ""}, labelsOf(words))
	})
}

func labelsOf(words []chunker.Word) []string {
	out := make([]string, len(words))
	for i, w := range words {
		out[i] = w.SpeakerLabel
	}
	return out
}

// TestIsTerminalSTTError codifies the terminal-vs-retryable
// classification for the Pub/Sub ack policy (added 2026-05-20).
//
// Coverage rules:
//   - Terminal codes (InvalidArgument, OutOfRange, NotFound,
//     PermissionDenied, Unauthenticated) ⇒ true.
//   - Transient codes (Internal, Unavailable, DeadlineExceeded) ⇒ false.
//   - File-level errors from ParseChirp3Results (text starting with
//     "chirp 3 returned") ⇒ true regardless of inner code.
//   - String fallbacks for codec-rejection signatures ⇒ true.
//   - nil ⇒ false.
//   - Plain errors (no grpc code, no known signature) ⇒ false
//     (default to retry — safer to over-retry than under-retry).
func TestIsTerminalSTTError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{"nil error", nil, false},

		// gRPC code path — terminal.
		{"InvalidArgument", grpcstatuspkg.Error(codes.InvalidArgument, "bad codec"), true},
		{"OutOfRange", grpcstatuspkg.Error(codes.OutOfRange, "file too big"), true},
		{"NotFound", grpcstatuspkg.Error(codes.NotFound, "missing gcs object"), true},
		{"PermissionDenied", grpcstatuspkg.Error(codes.PermissionDenied, "no iam"), true},
		{"Unauthenticated", grpcstatuspkg.Error(codes.Unauthenticated, "no token"), true},

		// Wrapped gRPC errors must also surface the code via
		// grpcstatus.FromError; verifies the %w chain works.
		{
			"wrapped InvalidArgument",
			fmt.Errorf("batch recognize: %w", grpcstatuspkg.Error(codes.InvalidArgument, "bad codec")),
			true,
		},

		// gRPC code path — retryable.
		{"Internal", grpcstatuspkg.Error(codes.Internal, "chirp 5xx"), false},
		{"Unavailable", grpcstatuspkg.Error(codes.Unavailable, "network blip"), false},
		{"DeadlineExceeded", grpcstatuspkg.Error(codes.DeadlineExceeded, "timeout"), false},

		// File-level errors from ParseChirp3Results — always terminal.
		// The literal "chirp 3 returned" prefix is what stt-worker
		// emits; we match on it directly.
		{
			"chirp file-level error",
			fmt.Errorf("chirp 3 returned 1 file-level error(s): code: INTERNAL"),
			true,
		},

		// String fallbacks for codec-rejection signatures embedded in
		// non-grpc errors (e.g. wrapped op.Wait outputs).
		{"INVALID_ARGUMENT signature", fmt.Errorf("await: code = INVALID_ARGUMENT: bad audio"), true},
		{"unsupported codec signature", fmt.Errorf("await: unsupported codec"), true},
		{"audio too long", fmt.Errorf("await: audio is too long"), true},

		// Default — unrecognized error → retry.
		{"plain string error", fmt.Errorf("connection refused"), false},
		{"db error", fmt.Errorf("pgxpool: connection timeout"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isTerminalSTTError(tt.err)
			if got != tt.want {
				t.Errorf("isTerminalSTTError(%v) = %v, want %v", tt.err, got, tt.want)
			}
		})
	}
}

// TestIsTerminalStatusCode pins the numeric classifier the watchdog's
// per-file path uses. The regression that motivated it (incident
// 12c76823): a Chirp per-file code=13 INTERNAL was treated as terminal
// and killed a 49-min clinical session. It MUST classify as transient
// so the chunk gets re-submitted instead.
func TestIsTerminalStatusCode(t *testing.T) {
	tests := []struct {
		name string
		code codes.Code
		want bool
	}{
		// Terminal — the input is bad; every retry returns the same.
		{"InvalidArgument (codec)", codes.InvalidArgument, true},
		{"OutOfRange (too long)", codes.OutOfRange, true},
		{"NotFound (source GC'd)", codes.NotFound, true},
		{"PermissionDenied (IAM)", codes.PermissionDenied, true},
		{"Unauthenticated", codes.Unauthenticated, true},

		// Transient — Google-side / transport fault; re-submit recovers.
		{"INTERNAL (the 12c76823 regression)", codes.Internal, false},
		{"Unavailable", codes.Unavailable, false},
		{"DeadlineExceeded", codes.DeadlineExceeded, false},
		{"ResourceExhausted (rate limit)", codes.ResourceExhausted, false},
		{"Unknown", codes.Unknown, false},
		{"OK / zero code", codes.OK, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isTerminalStatusCode(tt.code); got != tt.want {
				t.Errorf("isTerminalStatusCode(%v) = %v, want %v", tt.code, got, tt.want)
			}
		})
	}
}

// TestShouldGiveUpOnPendingOp pins the hung-PENDING trigger. The
// 12c76823 follow-up: an op pending past the give-up window whose
// server-side update_time has frozen is "hung" and must be cancelled +
// re-submitted; a merely-slow-but-progressing op (fresh update_time)
// must NOT be, to avoid a cancel-and-resubmit storm during a Chirp-wide
// slowdown.
func TestShouldGiveUpOnPendingOp(t *testing.T) {
	const giveUp = 3 * time.Hour
	const staleLimit = 45 * time.Minute

	tests := []struct {
		name            string
		age             time.Duration
		hasUpdateTime   bool
		updateStaleness time.Duration
		want            bool
	}{
		{"young op, no signal yet", 10 * time.Minute, false, 0, false},
		{"young op even if stale", 30 * time.Minute, true, 2 * time.Hour, false},
		{"old but no update_time signal → refuse to cancel", 4 * time.Hour, false, 0, false},
		{"old but progressing (fresh update_time) → wait", 4 * time.Hour, true, 5 * time.Minute, false},
		{"old AND stale → hung (the 12c76823 case)", 4 * time.Hour, true, 90 * time.Minute, true},
		{"exactly at give-up + exactly at stale limit → hung", giveUp, true, staleLimit, true},
		{"past give-up, staleness 1s under limit → wait", giveUp + time.Second, true, staleLimit - time.Second, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := shouldGiveUpOnPendingOp(tt.age, tt.hasUpdateTime, tt.updateStaleness, giveUp, staleLimit)
			if got != tt.want {
				t.Errorf("shouldGiveUpOnPendingOp(age=%v, has=%v, stale=%v) = %v, want %v",
					tt.age, tt.hasUpdateTime, tt.updateStaleness, got, tt.want)
			}
		})
	}
}

// TestPerFileClassificationParity guards the invariant that the
// watchdog's per-file branch and isTerminalSTTError agree on the gRPC
// code set — they must, since both gate the same FAILED decision. If a
// future edit adds a terminal code to one classifier but not the other,
// this catches the drift.
func TestPerFileClassificationParity(t *testing.T) {
	allCodes := []codes.Code{
		codes.OK, codes.Canceled, codes.Unknown, codes.InvalidArgument,
		codes.DeadlineExceeded, codes.NotFound, codes.AlreadyExists,
		codes.PermissionDenied, codes.ResourceExhausted, codes.FailedPrecondition,
		codes.Aborted, codes.OutOfRange, codes.Unimplemented, codes.Internal,
		codes.Unavailable, codes.DataLoss, codes.Unauthenticated,
	}
	for _, c := range allCodes {
		viaCode := isTerminalStatusCode(c)
		viaErr := isTerminalSTTError(grpcstatuspkg.Error(c, "x"))
		// isTerminalSTTError has a non-grpc string fallback, but for a
		// pure grpc error with a non-terminal code it returns the same
		// as isTerminalStatusCode.
		if viaCode != viaErr {
			t.Errorf("classification drift for %v: isTerminalStatusCode=%v isTerminalSTTError=%v",
				c, viaCode, viaErr)
		}
	}
}
