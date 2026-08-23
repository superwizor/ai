package llmworker

import (
	"encoding/json"
	"strings"
	"testing"
)

// TestLegacySchemaBezOgraniczen pilnuje, ze rozszerzenie
// schemaToVertexSchema o minItems/maxItems/maxLength NIE dotyka starej
// sciezki generacji.
//
// Do 2026-08-23 mapowanie gubilo te klucze po cichu. Potok ontologiczny
// na nich polega (kontrola rozmiaru nalezy do schematu, nie do promptu),
// wiec musialy zaczac dojezdzac — a to znaczy, ze gdyby
// report_schema.json kiedykolwiek je zawieral, call-1 zmienilby
// zachowanie bez zmiany w swoim wlasnym kodzie.
//
// Test jest wiec o schemacie, nie o funkcji: mowi "jesli ktos doda
// maxItems do report_schema.json, ma to zrobic SWIADOMIE".
func TestLegacySchemaBezOgraniczen(t *testing.T) {
	var s map[string]any
	if err := json.Unmarshal(reportSchemaBytes, &s); err != nil {
		t.Fatalf("report_schema.json nie parsuje sie: %v", err)
	}
	zakazane := []string{"minItems", "maxItems", "maxLength", "minimum", "maximum"}
	var znalezione []string
	var chodz func(v any, sciezka string)
	chodz = func(v any, sciezka string) {
		switch t := v.(type) {
		case map[string]any:
			for _, k := range zakazane {
				if _, ok := t[k]; ok {
					znalezione = append(znalezione, sciezka+"."+k)
				}
			}
			for k, vv := range t {
				chodz(vv, sciezka+"."+k)
			}
		case []any:
			for i, vv := range t {
				chodz(vv, sciezka+"[]")
				_ = i
			}
		}
	}
	chodz(s, "$")

	if len(znalezione) > 0 {
		t.Fatalf("report_schema.json zyskal ograniczenia rozmiaru: %s\n\n"+
			"Od 2026-08-23 schemaToVertexSchema przenosi je do Vertexa, wiec "+
			"call-1 zacznie je EGZEKWOWAC. Jesli to jest zamierzone — zaktualizuj "+
			"ten test razem ze schematem. Jesli nie — usun je ze schematu.",
			strings.Join(znalezione, ", "))
	}
}

// TestOgraniczeniaDojezdzajaDoVertexa: druga polowa tej samej umowy —
// klucze, ktore potok ontologiczny deklaruje, musza faktycznie dotrzec.
func TestOgraniczeniaDojezdzajaDoVertexa(t *testing.T) {
	vs := schemaToVertexSchema(map[string]any{
		"type": "array",
		"items": map[string]any{
			"type": "string", "maxLength": int64(600),
		},
		"minItems": int64(1),
		"maxItems": int64(3),
	})
	if vs.MinItems == nil || *vs.MinItems != 1 {
		t.Error("minItems nie dojechalo")
	}
	if vs.MaxItems == nil || *vs.MaxItems != 3 {
		t.Error("maxItems nie dojechalo")
	}
	if vs.Items == nil || vs.Items.MaxLength == nil || *vs.Items.MaxLength != 600 {
		t.Error("maxLength w items nie dojechalo")
	}
}

func TestZakresLiczbowyDojezdza(t *testing.T) {
	vs := schemaToVertexSchema(map[string]any{
		"type": "number", "minimum": 0, "maximum": 1,
	})
	if vs.Minimum == nil || *vs.Minimum != 0 {
		t.Error("minimum nie dojechalo")
	}
	if vs.Maximum == nil || *vs.Maximum != 1 {
		t.Error("maximum nie dojechalo")
	}
}
