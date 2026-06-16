// nip_handler.go — NIP (Polish tax ID) lookup proxy for the browser.
//
// GET /api/nip-lookup?nip=XXXXXXXXXX
//
// Proxies to the Polish Ministry of Finance's White List API:
//   https://wl-api.mf.gov.pl/api/search/nip/{nip}?date={today}
//
// Returns structured JSON with the parsed company data:
//   { legalName, taxId, vatIdEu, streetLine, buildingNumber, unitNumber, postalCode, city }
//
// This endpoint is unauthenticated (same as the old Next.js route) —
// it's a public government API proxy. The data is publicly available via
// https://www.podatki.gov.pl/wykaz-podatnikow-vat-wyszukiwarka
//
// Domain assignment: identity-svc (not billing-svc) because NIP lookup
// is an organization data function, not a billing function.
package http

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"time"
)

var nipDigitsRE = regexp.MustCompile(`^\d{10}$`)

// NIPHandler proxies NIP lookups to the Polish MF White List API.
type NIPHandler struct {
	logger *slog.Logger
	client *http.Client
}

// NewNIPHandler creates the handler with a bounded HTTP client.
func NewNIPHandler(logger *slog.Logger) *NIPHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &NIPHandler{
		logger: logger,
		client: &http.Client{Timeout: 10 * time.Second},
	}
}

// RegisterRoutes wires the handler into the mux.
func (h *NIPHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/nip-lookup", h.handleNIPLookup)
}

// ─── Types ─────────────────────────────────────────────────────────────────────

type mfResponse struct {
	Result struct {
		Subject *mfSubject `json:"subject"`
	} `json:"result"`
}

type mfSubject struct {
	Name             string `json:"name"`
	WorkingAddress   string `json:"workingAddress"`
	ResidenceAddress string `json:"residenceAddress"`
}

type nipLookupResponse struct {
	LegalName      string `json:"legalName"`
	TaxID          string `json:"taxId"`
	VatIDEU        string `json:"vatIdEu"`
	StreetLine     string `json:"streetLine"`
	BuildingNumber string `json:"buildingNumber"`
	UnitNumber     string `json:"unitNumber"`
	PostalCode     string `json:"postalCode"`
	City           string `json:"city"`
}

// ─── Handler ───────────────────────────────────────────────────────────────────

func (h *NIPHandler) handleNIPLookup(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	rawNIP := r.URL.Query().Get("nip")
	if rawNIP == "" {
		writeNIPJSON(w, http.StatusBadRequest, map[string]string{"error": "NIP jest wymagany"})
		return
	}

	// Normalize: remove spaces and hyphens.
	normalized := strings.Map(func(r rune) rune {
		if r == ' ' || r == '-' {
			return -1
		}
		return r
	}, rawNIP)

	if !nipDigitsRE.MatchString(normalized) {
		writeNIPJSON(w, http.StatusBadRequest, map[string]string{"error": "NIP musi składać się dokładnie z 10 cyfr"})
		return
	}

	// Get current date in Warsaw timezone (YYYY-MM-DD).
	loc, err := time.LoadLocation("Europe/Warsaw")
	if err != nil {
		loc = time.FixedZone("CET", 1*60*60)
	}
	date := time.Now().In(loc).Format("2006-01-02")

	apiURL := fmt.Sprintf("https://wl-api.mf.gov.pl/api/search/nip/%s?date=%s", normalized, date)
	h.logger.InfoContext(ctx, "nip-lookup: querying MF API", "url", apiURL)

	req2, err := http.NewRequestWithContext(ctx, http.MethodGet, apiURL, nil)
	if err != nil {
		writeNIPJSON(w, http.StatusInternalServerError, map[string]string{"error": "Wystąpił nieoczekiwany błąd"})
		return
	}
	req2.Header.Set("User-Agent", "SuperWizorAI/1.0")

	resp, err := h.client.Do(req2)
	if err != nil {
		h.logger.ErrorContext(ctx, "nip-lookup: MF API request failed", "error", err)
		writeNIPJSON(w, http.StatusBadGateway, map[string]string{"error": "Błąd podczas łączenia z rejestrem MF"})
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20)) // 1 MiB max
	if err != nil {
		writeNIPJSON(w, http.StatusInternalServerError, map[string]string{"error": "Błąd odczytu odpowiedzi MF"})
		return
	}

	if resp.StatusCode != http.StatusOK {
		h.logger.WarnContext(ctx, "nip-lookup: MF API error", "status", resp.StatusCode, "body", string(body))
		// Try to extract error message.
		var errResp struct {
			Message string `json:"message"`
		}
		if json.Unmarshal(body, &errResp) == nil && errResp.Message != "" {
			writeNIPJSON(w, resp.StatusCode, map[string]string{"error": errResp.Message})
			return
		}
		writeNIPJSON(w, resp.StatusCode, map[string]string{"error": "Błąd podczas łączenia z rejestrem MF"})
		return
	}

	var mf mfResponse
	if err := json.Unmarshal(body, &mf); err != nil {
		writeNIPJSON(w, http.StatusInternalServerError, map[string]string{"error": "Błąd parsowania odpowiedzi MF"})
		return
	}

	if mf.Result.Subject == nil {
		writeNIPJSON(w, http.StatusNotFound, map[string]string{
			"error": "Nie znaleziono podmiotu o podanym numerze NIP w rejestrze MF",
		})
		return
	}

	subject := mf.Result.Subject
	rawAddress := subject.WorkingAddress
	if rawAddress == "" {
		rawAddress = subject.ResidenceAddress
	}

	parsed := parsePolishAddress(rawAddress)

	result := nipLookupResponse{
		LegalName:      subject.Name,
		TaxID:          normalized,
		VatIDEU:        "PL" + normalized,
		StreetLine:     parsed.streetLine,
		BuildingNumber: parsed.buildingNumber,
		UnitNumber:     parsed.unitNumber,
		PostalCode:     parsed.postalCode,
		City:           parsed.city,
	}

	h.logger.InfoContext(ctx, "nip-lookup: found",
		"legal_name", result.LegalName,
		"nip", normalized)
	writeNIPJSON(w, http.StatusOK, result)
}

// ─── Polish address parser ─────────────────────────────────────────────────────

type parsedAddress struct {
	streetLine     string
	buildingNumber string
	unitNumber     string
	postalCode     string
	city           string
}

var (
	postalCodeRE   = regexp.MustCompile(`(\d{2}-\d{3})`)
	buildingNumRE  = regexp.MustCompile(`\s+(\d+[a-zA-Z]*(?:/\d+[a-zA-Z]*)?)$`)
	unitNumberRE   = regexp.MustCompile(`(?i)\s+(?:m\.|lok\.|m|lok)\s*([a-zA-Z0-9\-]+)$`)
	streetPrefixRE = regexp.MustCompile(`(?i)^(?:ul\.\s+|ulica\s+)`)
)

func parsePolishAddress(raw string) parsedAddress {
	result := parsedAddress{}
	if raw == "" {
		return result
	}

	// Normalize whitespace.
	normalized := strings.Join(strings.Fields(raw), " ")

	commaIdx := strings.LastIndex(normalized, ",")
	if commaIdx != -1 {
		leftPart := strings.TrimSpace(normalized[:commaIdx])
		rightPart := strings.TrimSpace(normalized[commaIdx+1:])

		// Parse right part: "00-001 WARSZAWA"
		if m := postalCodeRE.FindStringSubmatchIndex(rightPart); m != nil {
			result.postalCode = rightPart[m[2]:m[3]]
			result.city = strings.TrimSpace(rightPart[m[3]:])
		} else {
			result.city = rightPart
		}

		streetAndBuilding := leftPart

		// Check for unit number (m., lok.)
		if m := unitNumberRE.FindStringSubmatchIndex(streetAndBuilding); m != nil {
			result.unitNumber = streetAndBuilding[m[2]:m[3]]
			streetAndBuilding = strings.TrimSpace(streetAndBuilding[:m[0]])
		}

		// Building number at end.
		if m := buildingNumRE.FindStringSubmatchIndex(streetAndBuilding); m != nil {
			bld := streetAndBuilding[m[2]:m[3]]
			result.streetLine = strings.TrimSpace(streetAndBuilding[:m[0]])
			if strings.Contains(bld, "/") {
				parts := strings.SplitN(bld, "/", 2)
				result.buildingNumber = parts[0]
				if result.unitNumber == "" {
					result.unitNumber = parts[1]
				}
			} else {
				result.buildingNumber = bld
			}
		} else {
			result.streetLine = streetAndBuilding
		}
	} else {
		// Fallback: no comma — try to find postal code anywhere.
		if m := postalCodeRE.FindStringIndex(normalized); m != nil {
			result.postalCode = normalized[m[0]:m[1]]
			leftPart := strings.TrimSpace(normalized[:m[0]])
			result.city = strings.TrimSpace(normalized[m[1]:])

			if bm := buildingNumRE.FindStringSubmatchIndex(leftPart); bm != nil {
				bld := leftPart[bm[2]:bm[3]]
				result.streetLine = strings.TrimSpace(leftPart[:bm[0]])
				if strings.Contains(bld, "/") {
					parts := strings.SplitN(bld, "/", 2)
					result.buildingNumber = parts[0]
					result.unitNumber = parts[1]
				} else {
					result.buildingNumber = bld
				}
			} else {
				result.streetLine = leftPart
			}
		} else {
			result.streetLine = normalized
		}
	}

	// Remove leading "UL." or "ULICA" prefix.
	result.streetLine = streetPrefixRE.ReplaceAllString(result.streetLine, "")
	result.streetLine = strings.TrimSpace(result.streetLine)

	return result
}

// writeNIPJSON writes a JSON response (standalone to avoid import cycles).
func writeNIPJSON(w http.ResponseWriter, code int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(payload)
}
