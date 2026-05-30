# Superwizor AI - Integracje z Oprogramowaniem Firm Trzecich (Etap 5)

Dokument zawiera wytyczne techniczne oraz zbiór komend dla dwóch kluczowych integracji zewnętrznych w systemie Superwizor AI.

## 1. Integracja Gemini API Key za pomocą GCP Secret Manager
Chociaż główna integracja opiera się na Google Cloud i Vertex AI (Gemini i Chirp), w przypadku chęci zastosowania samodzielnego klucza Gemini API (np. z Google AI Studio do deweloperskich testów lokalnych), należy przechować API Key na poziomie Google Cloud Platform, aby aplikacja na Cloud Run (Go) bezpiecznie odpytywała model. Poniżej znajduje się instrukcja dla GCP Secret Manager.

**Wymagania:** Musisz być połączony z kontem Google Cloud przez `gcloud auth login` w konkretnym projekcie.

### Zapis sekretu:
1. Przejdź na platformę Google AI Studio: [Gemini API Keys](https://aistudio.google.com/app/apikey) i wygeneruj nowy klucz.
2. Uruchom polecenie by stworzyć magazyn klucza w Secret Manager:
   ```bash
   gcloud secrets create gemini_api_key --replication-policy="automatic"
   ```
3. Wstrzyknij wygenerowany ciąg znaków do utworzonego sekretu:
   ```bash
   echo -n "TUTAJ_WKLEJ_SWOJ_KLUCZ_GEMINI" | gcloud secrets versions add gemini_api_key --data-file=-
   ```
4. **Uprawnienia na Cloud Run:** Instancja backendu, która będzie wysyłać żądania, musi nosić przypisaną sobie rolę Secret Accessor:
   ```bash
   gcloud projects add-iam-policy-binding [ID_PROJEKTU] \
     --member="serviceAccount:[KONTO_USŁUGI_CLOUD_RUN]@developer.gserviceaccount.com" \
     --role="roles/secretmanager.secretAccessor"
   ```

## 2. Instrukcja zorganizowania konta Stripe i Webhooków (System płatności)

**Cel:** Zebranie kluczy prywatnych i Webhook Secret dla `billing-svc` z dokumentacji architektury (punkt 4.2.2 - rozliczenia).

### A. Zakładanie konta i generacja klucza głównego:
1. Załóż konto deweloperskie na stronie [Stripe](https://stripe.com).
2. Przejdź do trybu **Test Mode** (przełącznik u góry po prawej stronie kokpitu).
3. Przejdź do sekcji **Developers > API Keys**.
4. Skopiuj swój **Secret key** (powinien zaczynać się od `sk_test_...`).
5. (Opcjonalne) Umieść ten klucz natychmiastowo w GCP:
   ```bash
   gcloud secrets create stripe_secret_key --replication-policy="automatic"
   echo -n "sk_test_..." | gcloud secrets versions add stripe_secret_key --data-file=-
   ```

### B. Generacja Webhooków:
Serwis Bilingowy w Cloud Run wymaga bezpiecznego Webhook Endpointu do odbierania zdarzeń typu `invoice.payment_succeeded`. Gdy uruchomimy `billing-svc`, będziemy pracować na środowisku lokalnym. Do tego wykorzystuje się paczkę **Stripe CLI**.

**Zabezpieczenie przy pracy poprzez terminal:**
Aplikacja Stripe poprosi Cię wtedy na środowisku developerskim o wpisanie loginu i przekaże bezpieczny most lokalny. Zrób na terminalu:
```bash
brew install stripe/stripe-cli/stripe
stripe login
```
Następnie aby słuchać zdarzeń (Stripe do `billing-svc`) w Go, odpalisz w przyszłości nasłuchiwanie lokalne:
```bash
stripe listen --forward-to localhost:8080/stripe/webhook
```
Z konsoli zostanie wydrukowany tzw. **Webhook Secret** (zaczynający się od `whsec_...`).
Również zapisz go do GCloud:
```bash
gcloud secrets create stripe_webhook_secret --replication-policy="automatic"
echo -n "whsec_..." | gcloud secrets versions add stripe_webhook_secret --data-file=-
```

Dokument zaktualizowany na potrzeby konfiguracji CI/CD w Go, zgodnie z dyrektywą Superwizor AI MVP Phase 2.
