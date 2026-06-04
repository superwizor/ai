package storage

import (
	"testing"
)

func TestPlanCutTargets(t *testing.T) {
	cases := []struct {
		name           string
		durationSec    int
		maxChunkSec    int
		wantTargetsMS  []int64
	}{
		{
			"under max — no cuts",
			600, 1140, nil,
		},
		{
			"exactly max — no cuts",
			1140, 1140, nil,
		},
		{
			"slight over — one cut, two even chunks",
			// 2280s / 2 chunks = 1140s each → one cut at 1140s
			2280, 1140, []int64{1_140_000},
		},
		{
			"70 min — 4 chunks of ~17.5 min each",
			// 4200s / ceil(4200/1140)=4 chunks = 1050s each
			// cuts at 1050s, 2100s, 3150s
			4200, 1140, []int64{1_050_000, 2_100_000, 3_150_000},
		},
		{
			// 3600s / 1140s = 3.16 → ceil=4 chunks → 3 cuts.
			// chunkLen = 3600s / 4 = 900s each.
			"60 min — 4 chunks of 15 min each (just over 3×1140)",
			3600, 1140, []int64{900_000, 1_800_000, 2_700_000},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := planCutTargets(tc.durationSec, tc.maxChunkSec)
			if len(got) != len(tc.wantTargetsMS) {
				t.Fatalf("len = %d, want %d (got %v)", len(got), len(tc.wantTargetsMS), got)
			}
			for i := range got {
				if got[i] != tc.wantTargetsMS[i] {
					t.Errorf("target[%d] = %d ms, want %d", i, got[i], tc.wantTargetsMS[i])
				}
			}
		})
	}
}

func TestChooseCutPoint(t *testing.T) {
	silences := []silenceRange{
		{StartMS: 1_000_000, EndMS: 1_001_000}, // 1000–1001s
		{StartMS: 1_130_000, EndMS: 1_133_000}, // 1130–1133s — near 1140s target
		{StartMS: 1_200_000, EndMS: 1_205_000}, // 1200–1205s
		{StartMS: 5_000_000, EndMS: 5_002_000}, // way past
	}

	// Wide bounds → unchanged behavior (the cap-bounding is exercised in
	// TestSelectCutPoints_NeverExceedsHardCap below).
	const noMin, wideMax = int64(0), int64(1_000_000_000)

	// Target 1_140_000ms (19 min): nearest mid is (1130+1133)/2 = 1131.5s
	// → 1_131_500ms; delta = 8500ms < 60000ms (search window).
	got := chooseCutPoint(silences, 1_140_000, noMin, wideMax)
	if !got.OnSilence {
		t.Errorf("expected OnSilence=true; got false")
	}
	if got.AtMS != 1_131_500 {
		t.Errorf("AtMS = %d, want 1_131_500", got.AtMS)
	}

	// Target 3_000_000ms: no silence within 60s — fallback to target.
	got = chooseCutPoint(silences, 3_000_000, noMin, wideMax)
	if got.OnSilence {
		t.Errorf("expected fallback (OnSilence=false); got true")
	}
	if got.AtMS != 3_000_000 {
		t.Errorf("AtMS = %d, want 3_000_000 (target)", got.AtMS)
	}
}

// TestSelectCutPoints_NeverExceedsHardCap reproduces the failure mode of
// session e55b7c1e: a silence just forward of the ~19-min target used to
// snap chunk_0 to ≥20 min, which Chirp BatchRecognize rejects with
// INVALID_ARGUMENT ("file too long"). The bounded selectCutPoints must
// keep every chunk under the 20-min hard cap.
func TestSelectCutPoints_NeverExceedsHardCap(t *testing.T) {
	const durationSec = 2280 // 38 min → 2 chunks at maxChunkSec=1140
	durationMS := int64(durationSec) * 1000
	targets := planCutTargets(durationSec, defaultMaxChunkSec) // [1_140_000]

	// Silence whose midpoint sits 60s PAST the 1140s target (mid=1_200_000).
	// Pre-fix, chooseCutPoint snapped chunk_0's end here → a 1200s chunk,
	// over the cap. Post-fix it's outside maxAtMS and must be rejected.
	silences := []silenceRange{
		{StartMS: 1_199_000, EndMS: 1_201_000}, // mid = 1_200_000
	}

	cuts := selectCutPoints(targets, silences, durationMS, overlapTargetMS)
	chunks := buildChunkPlan(cuts, durationMS, overlapTargetMS)

	hardCapMS := int64(maxChunkSecHardCap) * 1000 // 1_200_000
	for _, ch := range chunks {
		span := ch.EndOffsetMS - ch.StartOffsetMS
		if span > hardCapMS {
			t.Errorf("chunk %d span %dms exceeds hard cap %dms (%+v)",
				ch.ChunkIndex, span, hardCapMS, ch)
		}
	}
	// And specifically: chunk_0 must NOT have snapped to the over-cap
	// silence at 1_200_000.
	if cuts[0].AtMS >= 1_200_000 {
		t.Errorf("chunk_0 cut snapped to/over the cap: AtMS=%d", cuts[0].AtMS)
	}
}

func TestBuildChunkPlan(t *testing.T) {
	// 3 cuts at silence → 4 chunks. 30 min total. 10s overlap.
	cuts := []cutPoint{
		{AtMS: 450_000, OnSilence: true},   // 7m30s
		{AtMS: 900_000, OnSilence: true},   // 15m
		{AtMS: 1_350_000, OnSilence: false}, // 22m30s — fallback
	}
	const overlap = int64(10_000)
	const durationMS = int64(1_800_000) // 30 min

	chunks := buildChunkPlan(cuts, durationMS, overlap)
	if len(chunks) != 4 {
		t.Fatalf("len = %d, want 4", len(chunks))
	}

	// Chunk 0: [0, 450_000], seam=450_000, overlap=0, cut_on_silence=true
	if chunks[0].StartOffsetMS != 0 || chunks[0].SeamOffsetMS != 450_000 ||
		chunks[0].EndOffsetMS != 450_000 || chunks[0].OverlapMS != 0 || !chunks[0].CutOnSilence {
		t.Errorf("chunk 0 = %+v", chunks[0])
	}

	// Chunk 1: [440_000, 900_000], seam=900_000, overlap=10_000, cut_on_silence=true
	if chunks[1].StartOffsetMS != 440_000 || chunks[1].SeamOffsetMS != 900_000 ||
		chunks[1].EndOffsetMS != 900_000 || chunks[1].OverlapMS != 10_000 || !chunks[1].CutOnSilence {
		t.Errorf("chunk 1 = %+v", chunks[1])
	}

	// Chunk 2: [890_000, 1_350_000], seam=1_350_000, overlap=10_000.
	// Was preceded by a NON-silence cut (cuts[1] → cuts[2] transition;
	// cuts[1].OnSilence=true; the FALLBACK marker on this chunk
	// reflects cuts[i-1]'s OnSilence — for chunk 2, that's cuts[1]=true).
	if chunks[2].StartOffsetMS != 890_000 || chunks[2].SeamOffsetMS != 1_350_000 ||
		!chunks[2].CutOnSilence {
		t.Errorf("chunk 2 = %+v", chunks[2])
	}

	// Chunk 3: [1_340_000, 1_800_000], seam=duration, overlap=10_000.
	// cuts[2].OnSilence=false → cut_on_silence=false on chunk 3.
	if chunks[3].StartOffsetMS != 1_340_000 || chunks[3].SeamOffsetMS != 1_800_000 ||
		chunks[3].EndOffsetMS != 1_800_000 || chunks[3].CutOnSilence {
		t.Errorf("chunk 3 = %+v", chunks[3])
	}
}

func TestMsToSecondsArg(t *testing.T) {
	cases := map[int64]string{
		0:        "0.000",
		1234567:  "1234.567",
		60_000:   "60.000",
		60_001:   "60.001",
		999:      "0.999",
	}
	for ms, want := range cases {
		if got := msToSecondsArg(ms); got != want {
			t.Errorf("msToSecondsArg(%d) = %q, want %q", ms, got, want)
		}
	}
}
