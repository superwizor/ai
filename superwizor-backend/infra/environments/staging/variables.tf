variable "project_id" {
  type        = string
  description = "The GCP project ID for staging"
  default     = "superwizor-ai-25ecd"
}

variable "project_number" {
  type        = string
  description = <<-EOT
    GCP project NUMBER (not project_id). Needed to construct the Pub/Sub
    service-agent principal `service-<NUMBER>@gcp-sa-pubsub.iam.gserviceaccount.com`,
    which is the identity that publishes to DLQ topics when a subscription
    crosses max_delivery_attempts. Without binding pubsub.publisher to this
    agent on each DLQ topic, dead-letter delivery silently fails.

    Lookup: `gcloud projects describe superwizor-ai-25ecd --format='value(projectNumber)'`.
  EOT
  default     = "344724821207"
}

variable "billing_svc_url" {
  type        = string
  description = <<-EOT
    Publicznie dostępny URL Cloud Run service `billing-svc` (HTTP port
    8081, dla admin crons + Stripe stub). Variable bo Cloud Run usługi
    są deployowane przez CI, nie terraform — pierwszy deploy wygeneruje
    URL którego wartość trzeba podać przez tfvars / env.

    Format: `https://billing-svc-<HASH>.<region>.run.app`.

    Lookup: `gcloud run services describe billing-svc --region=europe-central2 --format='value(status.url)'`.

    Empty value powoduje że Cloud Scheduler jobs są suspended (paused)
    przez handler w billing_crons.tf — fail-safe dla bootstrap środowiska.
  EOT
  default     = ""
}

variable "e2e_token_minters" {
  type        = list(string)
  description = <<-EOT
    Principals (e.g. `user:foo@example.com`, `serviceAccount:ci-runner@…`,
    `group:e2e-team@…`) that may impersonate the Firebase Admin SDK service
    account to mint custom tokens for end-to-end tests. Without this binding,
    `gcloud auth application-default login` users get
    `Permission 'iam.serviceAccounts.signBlob' denied` when the Firebase
    Admin SDK falls back to the IAM signBlob API.

    Keep this list small — granting `serviceAccountTokenCreator` here lets the
    member act as the Firebase Admin SA for any signing operation, including
    minting tokens for arbitrary end users.
  EOT
  default     = []
}

variable "stt_provider" {
  type = string
  # "chirp" od 2026-07-31 — wycofanie z Deepgrama (bylo "deepgram" od
  # 2026-07-17 po walidacji e2e docs/39 Faza 2/3).
  #
  # Powod: nova-3 deterministycznie urywa transkrypcje w polowie nagrania
  # na monotonnym materiale. Sesja 7 (62 s liczenia) → 13 slow, koniec na
  # 15,2 s; ten sam plik jako FLAC i jako m4a, z diarize/smart_format i
  # bez nich — zawsze identycznie. nova-2 urywa na 13,7 s. Model
  # "enhanced" (arch polaris) transkrybuje cale 62 s, ale to starsza
  # generacja wypychana z cennika Deepgrama i ~1,6x drozsza, wiec nie jest
  # to droga na produkcje.
  #
  # Uwaga: dgClient nadal wstaje (DEEPGRAM_API_KEY zostaje zamontowany),
  # wiec jednorazowy fallback deepgram→chirp w deepgram_path.go dziala
  # bez zmian. Kill-switch w druga strone = zmiana tego defaulta.
  #
  # 2026-07-31, decyzja operatora: z powrotem na "deepgram". Kompromis
  # jest swiadomy — Chirp nie diaryzuje pl-PL W OGOLE
  # (Chirp3DiarizationLanguages["pl-PL"]=false, recognizer eu/_ odrzuca
  # diarizationConfig bledem 400), a awarie nova-3 dotyczyly materialu
  # monotonnego (ciagle liczenie), nie rozmowy terapeutycznej. Na
  # nagraniach konwersacyjnych nova-3 dal 99,0-99,3% pokrycia i poprawna
  # liczbe mowcow (2 i 3).
  #
  # RYZYKO, ktore zostaje: nova-3 nie ma zadnego zabezpieczenia przed
  # urwaniem transkrypcji. Straznik pokrycia istnieje wylacznie na
  # sciezce ElevenLabs (internal/elevenlabs/coverage.go) — sciezka
  # Deepgram zapisze ucieta transkrypcje jako COMPLETED tak samo jak
  # przed 2026-07-31. Docelowo przeniesc straznik do wspolnego miejsca.
  default = "deepgram"
}

variable "stt_provider_allowlist" {
  type    = string
  default = ""
}

variable "stt_provider_canary" {
  type = string
  # Silnik, na ktory allowlista kieruje wskazanych terapeutow/organizacje.
  # Pusty = allowlista bezczynna (worker to loguje). Do canary Fazy 3
  # docs/59: TF_VAR_stt_provider_canary=elevenlabs razem z allowlista.
  default = ""
}

variable "elevenlabs_api_url" {
  type = string
  # Domyslnie host rezydencji EU. Przelaczenie na globalny wymaga RAZEM
  # z tym elevenlabs_allow_non_eu="true" — celowa podwojna zgoda,
  # inaczej worker odmowi startu.
  default = "https://api.eu.residency.elevenlabs.io"
}

variable "elevenlabs_allow_non_eu" {
  type = string
  # "true" = audio terapii opuszcza UE. TYLKO material testowy.
  # Wylaczyc natychmiast po uruchomieniu tenanta EU.
  default = ""
}

variable "elevenlabs_api_key_secret_id" {
  type = string
  # Pusty = provider ElevenLabs wylaczony: sekret nie jest montowany,
  # elClient zostaje nil, a STT_PROVIDER=elevenlabs wraca na chirpa
  # zamiast wywracac sesje. Ustawic na "elevenlabs-api-key" dopiero po
  # utworzeniu sekretu (docs/59 Faza 0 krok 3).
  default = ""
}

variable "stt_order_gate" {
  type = string
  # "on" od 2026-07-17 (walidacja e2e docs/40: serialization held,
  # 4x ordering_gate_wait, zero bypass). Jak wyzej — default utrwalony.
  default = "on"
}

variable "stt_order_gate_max_wait_h" {
  type    = string
  default = "12"
}

variable "llm_pseudonymize" {
  type = string
  # "all" od 2026-07-17 (docs/41: pii-eval GATE PASS x3, e2e strict
  # leaks=[]). Jak wyzej — default utrwalony, zeby zwykly terragrunt
  # apply bez TF_VAR nie cofnal pseudonimizacji na off.
  default = "all"
}

variable "llm_pseudonymize_canonical" {
  type = string
  # "on" od 2026-07-20 (docs/41 §10): pelna pseudonimizacja danych
  # kanonicznych — llm-worker nadpisuje blob transkrypcji + segmenty
  # zredagowana wersja. Default utrwalony z tego samego powodu co wyzej.
  default = "on"
}
