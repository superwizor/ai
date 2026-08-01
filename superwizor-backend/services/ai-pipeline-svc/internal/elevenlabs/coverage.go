package elevenlabs

// Coverage guard — docs/59 §6.1.
//
// This is the reason this package exists in the shape it does.
//
// Deepgram Nova-3 went to production on 2026-07-17 and was withdrawn on
// 2026-07-31 because it stopped emitting words partway through Polish
// recordings while reporting the correct audio duration. A 62.07 s
// session yielded 13 words ending at 15.2 s — and the pipeline stored
// that as a COMPLETED transcript, because nothing ever asked whether the
// transcript reached the end of the audio.
//
// The validation phase did not catch it: the runbook checked latency,
// speaker count and role mapping, all of which were green, on fixtures
// short enough that truncation was invisible. So coverage is not a
// dashboard metric here. It is an invariant checked on every session,
// and a bad enough value is treated as a provider failure.

// Coverage thresholds. Deliberately round numbers: the real
// distribution is unknown until this runs in production, and any
// threshold beats the previous state of having none. Revisit once there
// is a histogram to look at.
const (
	// CoverageOK is the floor for the normal path. Healthy runs measured
	// 98.7–99.9% across four recordings and four engines.
	CoverageOK = 0.95
	// CoverageFloor is the point below which the transcript is treated as
	// a provider failure rather than a partial result. Nova-3 on the
	// session-7 recording scored 0.245.
	CoverageFloor = 0.50
)

// CoverageVerdict is what the caller should do with a transcript.
type CoverageVerdict int

const (
	// CoverageAccept — transcript reaches the end of the audio.
	CoverageAccept CoverageVerdict = iota
	// CoverageDegraded — a real chunk of the tail is missing. Store it
	// anyway (a partial transcript beats none for the therapist) but
	// alert: this is what silent truncation looks like on the way in.
	CoverageDegraded
	// CoverageReject — the transcript covers so little of the recording
	// that storing it would be worse than retrying. Treated as a
	// transient provider failure: NACK, retry, then watchdog fallback.
	CoverageReject
)

func (v CoverageVerdict) String() string {
	switch v {
	case CoverageAccept:
		return "accept"
	case CoverageDegraded:
		return "degraded"
	case CoverageReject:
		return "reject"
	}
	return "unknown"
}

// Coverage returns the fraction of the recording the transcript spans:
// the end of the last word divided by the provider-reported audio
// duration. Returns 0 when there is nothing to measure against, which
// CheckCoverage treats as a rejection rather than as a pass.
//
// Uses the LAST word's end rather than the maximum, because the words
// are already in emission order and a single corrupt timestamp must not
// decide the verdict — Chirp emitted one word ending at 8486.92 s in an
// 820 s recording, which under a max-based rule reads as 1034% coverage
// and would mask a genuinely truncated transcript. Timestamps beyond the
// audio duration are ignored entirely.
func (r *Result) Coverage() float64 {
	if r == nil || r.AudioDurationSec <= 0 || len(r.Words) == 0 {
		return 0
	}
	// Tolerate a hair over the reported duration (rounding at the tail),
	// but nothing wilder.
	limitMS := int64(r.AudioDurationSec * 1000 * 1.02)
	var lastMS int64
	for _, w := range r.Words {
		if w.EndMS <= limitMS && w.EndMS > lastMS {
			lastMS = w.EndMS
		}
	}
	return float64(lastMS) / (r.AudioDurationSec * 1000)
}

// BogusTimestamps counts words whose end lies beyond the reported audio
// duration. Non-zero means the provider emitted impossible timings —
// worth a metric even when coverage is fine.
func (r *Result) BogusTimestamps() int {
	if r == nil || r.AudioDurationSec <= 0 {
		return 0
	}
	limitMS := int64(r.AudioDurationSec * 1000 * 1.02)
	n := 0
	for _, w := range r.Words {
		if w.EndMS > limitMS {
			n++
		}
	}
	return n
}

// CheckCoverage turns the ratio into a verdict.
//
// An empty transcript for a non-trivial recording is a rejection, not an
// "accept with 0 words": that is precisely the shape nova-3 returned for
// a 13-minute file (HTTP 200, correct duration, zero words). Recordings
// shorter than minSpeechSec are exempt, since a genuinely silent clip is
// a legitimate answer we should not retry forever.
func (r *Result) CheckCoverage() (CoverageVerdict, float64) {
	const minSpeechSec = 5

	if r == nil {
		return CoverageReject, 0
	}
	// No duration reported — we cannot judge, so do not block the
	// session on a metric we failed to obtain.
	if r.AudioDurationSec <= 0 {
		return CoverageAccept, 0
	}
	if r.AudioDurationSec < minSpeechSec {
		return CoverageAccept, r.Coverage()
	}

	c := r.Coverage()
	switch {
	case c >= CoverageOK:
		return CoverageAccept, c
	case c >= CoverageFloor:
		return CoverageDegraded, c
	default:
		return CoverageReject, c
	}
}

// WordsPerSecond is the companion metric coverage cannot provide.
// Coverage only looks at where the LAST word sits, so a transcript that
// drops three quarters of the middle still scores ~99%. Speechmatics did
// exactly that on a mistagged-language recording: 99% coverage at 0.81
// words/s where the other engines produced 2.9.
func (r *Result) WordsPerSecond() float64 {
	if r == nil || r.AudioDurationSec <= 0 {
		return 0
	}
	return float64(r.WordCount) / r.AudioDurationSec
}
