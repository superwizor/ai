package main

import (
	"bufio"
	"bytes"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type Config struct {
	IssuerID       string
	KeyID          string
	PrivateKeyPath string
}

type AppInfosResponse struct {
	Data []struct {
		ID         string `json:"id"`
		Attributes struct {
			AppStoreState string `json:"appStoreState"`
		} `json:"attributes"`
	} `json:"data"`
}

type VersionsResponse struct {
	Data []struct {
		ID         string `json:"id"`
		Attributes struct {
			VersionString string `json:"versionString"`
			AppStoreState string `json:"appStoreState"`
		} `json:"attributes"`
	} `json:"data"`
}

type CreateVersionResponse struct {
	Data struct {
		ID string `json:"id"`
	} `json:"data"`
}

type LocalizationsResponse struct {
	Data []struct {
		ID         string `json:"id"`
		Attributes struct {
			Locale string `json:"locale"`
		} `json:"attributes"`
	} `json:"data"`
}

type JWTHeader struct {
	Alg string `json:"alg"`
	Kid string `json:"kid"`
	Typ string `json:"typ"`
}

type JWTPayload struct {
	Iss string `json:"iss"`
	Exp int64  `json:"exp"`
	Aud string `json:"aud"`
}

func main() {
	appID := "6774975751" // SuperWizor AI App ID

	// 1. Load config
	config, err := loadConfig()
	if err != nil {
		fmt.Printf("❌ Błąd konfiguracji: %v\n", err)
		os.Exit(1)
	}

	// 2. Generate JWT
	token, err := generateJWT(config.IssuerID, config.KeyID, config.PrivateKeyPath)
	if err != nil {
		fmt.Printf("❌ Błąd podczas generowania tokenu JWT: %v\n", err)
		os.Exit(1)
	}

	client := &http.Client{Timeout: 20 * time.Second}

	// ==========================================
	// KROK 1: Sprawdzenie wersji 1.0.1 (musi istnieć przed modyfikacją kategorii wersji roboczej!)
	// ==========================================
	fmt.Println("⚙️ 1. Sprawdzanie i tworzenie wersji 1.0.1...")
	versionID, err := getOrCreateVersion101(client, token, appID)
	if err != nil {
		fmt.Printf("❌ Błąd wersji 1.0.1: %v\n", err)
		os.Exit(1)
	}

	// ==========================================
	// KROK 2: Zmiana kategorii na Produktywność dla wersji roboczej
	// ==========================================
	fmt.Println("\n⚙️ 2. Aktualizacja kategorii dla SuperWizor AI (wersja robocza)...")
	appInfoID, err := fetchDraftAppInfoID(client, token, appID)
	if err != nil {
		fmt.Printf("❌ Błąd pobierania draft appInfo ID: %v\n", err)
		os.Exit(1)
	}

	err = updateCategories(client, token, appInfoID)
	if err != nil {
		fmt.Printf("❌ Błąd aktualizacji kategorii: %v\n", err)
	} else {
		fmt.Println("✅ Sukces: Zmieniono kategorię główną na PRODUCTIVITY, a dodatkową na HEALTH_AND_FITNESS!")
	}

	// ==========================================
	// KROK 3: Aktualizacja WhatsNew
	// ==========================================
	fmt.Println("\n⚙️ 3. Aktualizacja pola WhatsNew dla wersji 1.0.1...")
	err = updateWhatsNew(client, token, versionID)
	if err != nil {
		fmt.Printf("❌ Błąd aktualizacji WhatsNew: %v\n", err)
	} else {
		fmt.Println("✅ Sukces: Zaktualizowano opisy 'Co nowego w tej wersji' w języku polskim i angielskim!")
	}
}

func fetchDraftAppInfoID(client *http.Client, token, appID string) (string, error) {
	url := fmt.Sprintf("https://api.appstoreconnect.apple.com/v1/apps/%s/appInfos", appID)
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("status HTTP %d: %s", resp.StatusCode, string(body))
	}

	var response AppInfosResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return "", err
	}

	// Znajdź appInfo w stanie PREPARE_FOR_SUBMISSION (wersja robocza)
	for _, info := range response.Data {
		if info.Attributes.AppStoreState == "PREPARE_FOR_SUBMISSION" {
			return info.ID, nil
		}
	}

	return "", errors.New("nie znaleziono wersji roboczej (PREPARE_FOR_SUBMISSION) w appInfos. Upewnij się, że nowa wersja została dodana w panelu.")
}

func updateCategories(client *http.Client, token, appInfoID string) error {
	url := fmt.Sprintf("https://api.appstoreconnect.apple.com/v1/appInfos/%s", appInfoID)

	patchBody := map[string]interface{}{
		"data": map[string]interface{}{
			"type": "appInfos",
			"id":   appInfoID,
			"relationships": map[string]interface{}{
				"primaryCategory": map[string]interface{}{
					"data": map[string]interface{}{
						"type": "appCategories",
						"id":   "PRODUCTIVITY",
					},
				},
				"secondaryCategory": map[string]interface{}{
					"data": map[string]interface{}{
						"type": "appCategories",
						"id":   "HEALTH_AND_FITNESS",
					},
				},
				"primarySubcategoryOne": map[string]interface{}{
					"data": nil,
				},
				"primarySubcategoryTwo": map[string]interface{}{
					"data": nil,
				},
				"secondarySubcategoryOne": map[string]interface{}{
					"data": nil,
				},
				"secondarySubcategoryTwo": map[string]interface{}{
					"data": nil,
				},
			},
		},
	}

	bodyBytes, _ := json.Marshal(patchBody)
	req, _ := http.NewRequest("PATCH", url, bytes.NewBuffer(bodyBytes))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("status HTTP %d: %s", resp.StatusCode, string(body))
	}

	return nil
}

func getOrCreateVersion101(client *http.Client, token, appID string) (string, error) {
	url := fmt.Sprintf("https://api.appstoreconnect.apple.com/v1/apps/%s/appStoreVersions", appID)
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var response VersionsResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return "", err
	}

	for _, ver := range response.Data {
		if ver.Attributes.VersionString == "1.0.1" {
			fmt.Printf("ℹ️ Wersja 1.0.1 już istnieje (ID: %s, Status: %s).\n", ver.ID, ver.Attributes.AppStoreState)
			return ver.ID, nil
		}
	}

	fmt.Println("ℹ️ Wersja 1.0.1 nie została znaleziona. Tworzenie nowej wersji 1.0.1...")
	createUrl := "https://api.appstoreconnect.apple.com/v1/appStoreVersions"
	createBody := map[string]interface{}{
		"data": map[string]interface{}{
			"type": "appStoreVersions",
			"attributes": map[string]interface{}{
				"platform":      "IOS",
				"versionString": "1.0.1",
			},
			"relationships": map[string]interface{}{
				"app": map[string]interface{}{
					"data": map[string]interface{}{
						"type": "apps",
						"id":   appID,
					},
				},
			},
		},
	}

	createBytes, _ := json.Marshal(createBody)
	createReq, _ := http.NewRequest("POST", createUrl, bytes.NewBuffer(createBytes))
	createReq.Header.Set("Authorization", "Bearer "+token)
	createReq.Header.Set("Content-Type", "application/json")

	createResp, err := client.Do(createReq)
	if err != nil {
		return "", err
	}
	defer createResp.Body.Close()

	createBodyBytes, _ := io.ReadAll(createResp.Body)
	if createResp.StatusCode != http.StatusCreated {
		return "", fmt.Errorf("błąd HTTP %d: %s", createResp.StatusCode, string(createBodyBytes))
	}

	var createRespData CreateVersionResponse
	if err := json.Unmarshal(createBodyBytes, &createRespData); err != nil {
		return "", err
	}

	fmt.Printf("✅ Pomyślnie utworzono nową wersję 1.0.1 (ID: %s)!\n", createRespData.Data.ID)
	return createRespData.Data.ID, nil
}

func updateWhatsNew(client *http.Client, token, versionID string) error {
	url := fmt.Sprintf("https://api.appstoreconnect.apple.com/v1/appStoreVersions/%s/appStoreVersionLocalizations", versionID)
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var response LocalizationsResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return err
	}

	if len(response.Data) == 0 {
		return errors.New("brak dostępnych lokalizacji")
	}

	for _, loc := range response.Data {
		text := ""
		if loc.Attributes.Locale == "pl" {
			text = "Poprawki stabilności nagrywania sesji w tle."
		} else if loc.Attributes.Locale == "en-US" {
			text = "Stability and performance improvements for background recording."
		} else {
			continue
		}

		fmt.Printf("   📝 Aktualizacja języka '%s'... ", loc.Attributes.Locale)
		err := patchWhatsNewText(client, token, loc.ID, text)
		if err != nil {
			fmt.Printf("❌ BŁĄD: %v\n", err)
		} else {
			fmt.Println("✅ Gotowe")
		}
	}

	return nil
}

func patchWhatsNewText(client *http.Client, token, localizationID, text string) error {
	url := fmt.Sprintf("https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/%s", localizationID)

	patchBody := map[string]interface{}{
		"data": map[string]interface{}{
			"type": "appStoreVersionLocalizations",
			"id":   localizationID,
			"attributes": map[string]interface{}{
				"whatsNew": text,
			},
		},
	}

	bodyBytes, _ := json.Marshal(patchBody)
	req, _ := http.NewRequest("PATCH", url, bytes.NewBuffer(bodyBytes))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("status HTTP %d: %s", resp.StatusCode, string(body))
	}

	return nil
}

func loadConfig() (*Config, error) {
	envPath := "credentials.env"
	found := false
	for i := 0; i < 4; i++ {
		if _, err := os.Stat(envPath); err == nil {
			found = true
			break
		}
		envPath = filepath.Join("..", envPath)
	}

	if !found {
		return nil, errors.New("nie znaleziono pliku 'credentials.env'")
	}

	file, err := os.Open(envPath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	config := &Config{}
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])

		switch key {
		case "APP_STORE_ISSUER_ID":
			config.IssuerID = val
		case "APP_STORE_KEY_ID":
			config.KeyID = val
		case "APP_STORE_PRIVATE_KEY_PATH":
			config.PrivateKeyPath = val
		}
	}

	if !filepath.IsAbs(config.PrivateKeyPath) {
		baseDir := filepath.Dir(envPath)
		config.PrivateKeyPath = filepath.Clean(filepath.Join(baseDir, config.PrivateKeyPath))
	}

	return config, nil
}

func generateJWT(issuerID, keyID, privateKeyPath string) (string, error) {
	keyBytes, err := os.ReadFile(privateKeyPath)
	if err != nil {
		return "", err
	}

	block, _ := pem.Decode(keyBytes)
	rawKey, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return "", err
	}
	privKey, _ := rawKey.(*ecdsa.PrivateKey)

	header := JWTHeader{Alg: "ES256", Kid: keyID, Typ: "JWT"}
	payload := JWTPayload{Iss: issuerID, Exp: time.Now().Add(20 * time.Minute).Unix(), Aud: "appstoreconnect-v1"}

	headerJSON, _ := json.Marshal(header)
	payloadJSON, _ := json.Marshal(payload)

	headerB64 := base64.RawURLEncoding.EncodeToString(headerJSON)
	payloadB64 := base64.RawURLEncoding.EncodeToString(payloadJSON)

	signingInput := headerB64 + "." + payloadB64
	hasher := sha256.New()
	hasher.Write([]byte(signingInput))
	hashed := hasher.Sum(nil)

	r, s, err := ecdsa.Sign(rand.Reader, privKey, hashed)
	if err != nil {
		return "", err
	}

	keySize := 32
	rBytes := r.Bytes()
	sBytes := s.Bytes()

	sigBytes := make([]byte, keySize*2)
	copy(sigBytes[keySize-len(rBytes):], rBytes)
	copy(sigBytes[keySize*2-len(sBytes):], sBytes)

	sigB64 := base64.RawURLEncoding.EncodeToString(sigBytes)

	return signingInput + "." + sigB64, nil
}
