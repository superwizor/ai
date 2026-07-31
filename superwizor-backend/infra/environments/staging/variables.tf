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
  # 2026-07-31, decyzja operatora: "elevenlabs" dla wszystkich.
  #
  # Podstawa: canary na jednym terapeucie przeszedl trzy sesje, w tym
  # 65-minutowa — pokrycie 0,99996 (werdykt accept), 8535 slow, 4 mowcow,
  # 67 s przetwarzania, zero prob ponownych i zero fallbackow. Wczesniej
  # benchmark na czterech nagraniach dal 5/5 poprawnej diaryzacji przy
  # pokryciu 98,7-99,9%.
  #
  # Alternatywy odpadly: Chirp NIE diaryzuje pl-PL w ogole
  # (Chirp3DiarizationLanguages["pl-PL"]=false, recognizer eu/_ odrzuca
  # diarizationConfig bledem 400), a nova-3 urywal transkrypcje na
  # monotonnym materiale (sesja 62 s -> 24,5% pokrycia) i myli mowcow
  # (2 osoby -> 1).
  #
  # UWAGA co do fallbacku: gdy ElevenLabs zawiedzie trzy razy, watchdog
  # przerzuca sesje na Chirpa — a ten nie diaryzuje polskiego. Fallback
  # oznacza wiec degradacje jakosci, nie samo opoznienie.
  default = "elevenlabs"
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
  # DOCELOWO host rezydencji EU. Dzis globalny, bo tenant EU nie jest
  # udostepniony na koncie: ten sam klucz daje HTTP 200 na
  # api.elevenlabs.io i 400 invalid_api_key na
  # api.eu.residency.elevenlabs.io (smieciowy klucz dostaje tam 401,
  # wiec endpoint rozroznia nasz klucz i odmawia mu dostepu).
  #
  # Przelaczenie na globalny wymaga RAZEM z tym
  # elevenlabs_allow_non_eu="true" — celowa podwojna zgoda; sam
  # zmieniony URL bez flagi konczy sie odmowa startu workera.
  #
  # PRZYWROCIC na host rezydencji, gdy tenant EU ruszy. To jest jedna
  # linia i powinna byc pierwsza rzecza po potwierdzeniu od ElevenLabs.
  default = "https://api.elevenlabs.io"
}

variable "elevenlabs_allow_non_eu" {
  type = string
  # "true" = audio terapii OPUSZCZA UE.
  #
  # 2026-07-31, decyzja operatora: wlaczone jako default razem z
  # przelaczeniem stt_provider na elevenlabs, z zastrzezeniem, ze
  # rezydencje pokryje kontrakt zawierany offline. Od tego momentu
  # dotyczy to nagran PRAWDZIWYCH sesji, nie tylko materialu testowego —
  # audio terapii to dane szczegolnej kategorii wg GDPR art. 9.
  #
  # Wylaczyc razem z przywroceniem elevenlabs_api_url na host
  # rezydencji, gdy tenant EU bedzie dzialal.
  default = "true"
}

variable "elevenlabs_api_key_secret_id" {
  type = string
  # Sekret utworzony 2026-07-31 (wersja 2; wersja 1 z bledna wartoscia
  # wylaczona). Pusty wylaczalby providera: sekret nie bylby montowany,
  # elClient zostalby nil, a STT_PROVIDER=elevenlabs wrocilby na chirpa
  # zamiast wywracac sesje.
  default = "elevenlabs-api-key"
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
