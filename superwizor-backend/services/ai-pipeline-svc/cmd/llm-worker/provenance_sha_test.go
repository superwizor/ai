package llmworker

import (
	"testing"

	"github.com/superwizor-ai/backend/pkg/appconfig"
)

// Skrot tresci ontologii musi dojsc do sladu zapisywanego na raporcie —
// sama etykieta wersji nie mowi, ktora tresc szkicu obsluzyla przebieg.
func TestProweniencjaNiesieSkrotTresciOntologii(t *testing.T) {
	p := pipelineProvenance(pipelineDecision{
		Pipeline:              appconfig.PipelineOntology,
		OntologyVersion:       "0.1.1",
		OntologyContentSHA256: "42e21450139b5a035907cc8f267aec4a",
	})
	if p.OntologyContentSHA256 != "42e21450139b5a035907cc8f267aec4a" {
		t.Fatalf("skrot tresci zgubiony w proweniencji: %q", p.OntologyContentSHA256)
	}

	legacy := pipelineProvenance(pipelineDecision{
		Pipeline:              appconfig.PipelineLegacy,
		OntologyContentSHA256: "nie-powinno-trafic",
	})
	if legacy.OntologyContentSHA256 != "" {
		t.Fatal("raport legacy nie ma ontologii — skrot bylby falszem w kolumnie audytowej")
	}
}
