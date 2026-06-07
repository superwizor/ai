package analytics

import (
	"context"
	"log/slog"
)

// LogEvent wypisuje ustrukturyzowany log analityczny, który jest wyłapywany przez Log Router w GCP.
// Używane w Cloud Functions, gdzie buforowany Collector nie mógłby spuścić bufora (flush) przed wyjściem procesu.
// Klucz "ae" to znacznik (discriminator), po którym Log Router filtruje te logi: jsonPayload.ae="stt.submitted"
func LogEvent(ctx context.Context, name string, attrs ...slog.Attr) {
	// Kopiujemy atrybuty i wstawiamy na początek tag analityki "ae"
	allAttrs := make([]slog.Attr, 0, len(attrs)+1)
	allAttrs = append(allAttrs, slog.String("ae", name))
	allAttrs = append(allAttrs, attrs...)

	slog.LogAttrs(ctx, slog.LevelInfo, "analytics", allAttrs...)
}
