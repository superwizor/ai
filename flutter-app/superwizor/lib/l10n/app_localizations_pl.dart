// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get account_deleted_body =>
      'To konto terapeuty zostało zablokowane przez administratora Superwizor AI. Skontaktuj się z pomocą, jeśli uważasz, że to pomyłka.';

  @override
  String get account_deleted_title => 'Konto zablokowane';

  @override
  String account_not_found_body(String email) {
    return 'Zalogowano jako $email, ale to konto nie jest zarejestrowane w Superwizor AI. Jeśli otrzymałeś zaproszenie (terapeuta, manager lub klient), otwórz link z wiadomości e-mail. Konto terapeuty założysz w aplikacji: wyloguj się i wybierz „Załóż konto”.';
  }

  @override
  String get account_not_found_title => 'Nie znaleziono konta';

  @override
  String get action_plan_default_title => 'Plan działania';

  @override
  String get action_plan_fill_email_hint =>
      'Wypełnij adres e-mail klienta i ponów wysyłkę.';

  @override
  String get action_plan_no_email_body =>
      'Nie można wysłać planu, ponieważ klient nie ma zdefiniowanego adresu e-mail. Uzupełnij e-mail w kartotece.';

  @override
  String get action_plan_no_email_title => 'Brak adresu e-mail';

  @override
  String get action_plan_save_and_send => 'Zapisz i wyślij';

  @override
  String get action_plan_save_only => 'Zapisz';

  @override
  String get action_plan_saved_not_sent =>
      'Notatka zapisana, ale nie udało się wysłać e-maila. Spróbuj wysłać ponownie później.';

  @override
  String get action_plan_send_button => 'Wyślij plan działania do klienta';

  @override
  String get action_plan_send_cancel => 'Anuluj';

  @override
  String get action_plan_send_confirm_action => 'Wyślij';

  @override
  String action_plan_send_confirm_body(String email) {
    return 'Plan zostanie wysłany na adres: $email';
  }

  @override
  String get action_plan_send_confirm_title => 'Wyślij plan działania?';

  @override
  String get action_plan_sent_toast => 'Plan działania wysłany do klienta';

  @override
  String get activeAnalysis_analyzing => 'Analiza w toku';

  @override
  String get activeAnalysis_analyzing_desc =>
      'Sesja jest już na serwerze. Raport pojawi się za kilka minut.';

  @override
  String get activeAnalysis_check_details => 'Sprawdź szczegóły';

  @override
  String get activeAnalysis_converting => 'Konwertuję plik audio';

  @override
  String get activeAnalysis_converting_desc =>
      'Format pliku wymaga konwersji. Potrwa to chwilę.';

  @override
  String get activeAnalysis_preparing => 'Przygotowuję nagranie';

  @override
  String get activeAnalysis_preparing_desc =>
      'Sesja jest szyfrowana przed przesłaniem na serwer.';

  @override
  String get activeAnalysis_processing => 'Przetwarzanie sesji';

  @override
  String get activeAnalysis_processing_desc =>
      'Twoja sesja przechodzi kolejne etapy analizy.';

  @override
  String get activeAnalysis_quota_blocked_desc =>
      'Pula sesji została wyczerpana. Sesja jest bezpiecznie zapisana i zostanie przetworzona po odnowieniu planu.';

  @override
  String get activeAnalysis_upload_attention => 'Przesyłanie wymaga uwagi';

  @override
  String get activeAnalysis_upload_attention_desc =>
      'Sesja nie mogła zostać wgrana. Sprawdź szczegóły.';

  @override
  String get activeAnalysis_upload_interrupted =>
      'Przesyłanie zostało przerwane';

  @override
  String get activeAnalysis_upload_interrupted_desc =>
      'Próba wznowienia nastąpi automatycznie. Nagranie jest bezpieczne.';

  @override
  String get activeAnalysis_uploading => 'Sesja jest przesyłana na serwer.';

  @override
  String get activeAnalysis_uploading_desc =>
      'Plik trafia bezpiecznie na serwer. Możesz kontynuować pracę.';

  @override
  String activeAnalysis_uploading_status(int errors, int progress) {
    String _temp0 = intl.Intl.pluralLogic(
      errors,
      locale: localeName,
      other: 'błędów',
      many: 'błędów',
      few: 'błędy',
      one: 'błąd',
    );
    return 'Wgrywanie: $errors $_temp0, $progress w toku.';
  }

  @override
  String get activeAnalysis_uploading_status_desc =>
      'Część plików wymaga uwagi, ale przesyłanie reszty trwa bez zakłóceń.';

  @override
  String get activeAnalysis_view_details => 'Zobacz szczegóły';

  @override
  String get activeAnalysis_view_progress => 'Zobacz postęp';

  @override
  String get active_session_card_paused_subtitle => 'Wznów lub zakończ sesję';

  @override
  String get active_session_card_paused_title => 'Sesja wstrzymana';

  @override
  String get active_session_card_subtitle => 'Wróć do trwającej sesji';

  @override
  String get active_session_card_title => 'Sesja w toku...';

  @override
  String get addPatient_additional_data_title => 'Dodatkowe dane';

  @override
  String get addPatient_alias_hint =>
      'Twój prywatny skrót. Widoczny tylko dla Ciebie.';

  @override
  String get addPatient_alias_instruction =>
      'Wpisz inicjały, które kojarzą Ci się z klientem.';

  @override
  String get addPatient_alias_label => 'Etykieta robocza';

  @override
  String get addPatient_anonymization_description =>
      'Używamy wyłącznie pseudonimów. Wprowadź nazwę (np. inicjały lub fikcyjne imię), która nie pozwala osobom trzecim na identyfikację Twojego klienta.';

  @override
  String get addPatient_anonymization_title => 'Zasada anonimizacji danych';

  @override
  String get addPatient_avatar_format_hint =>
      'Litery, cyfry lub emoji (max. 2 znaki)';

  @override
  String get addPatient_background_color => 'KOLOR TŁA';

  @override
  String get addPatient_consent_label =>
      'Klient wyraził zgodę na nagrywanie i przetwarzanie danych zgodnie z Polityką Prywatności i DPA Superwizor AI.';

  @override
  String get addPatient_consent_link_label => 'Zobacz DPA';

  @override
  String get addPatient_email_label => 'E-mail klienta (opcjonalnie)';

  @override
  String get addPatient_email_privacy_hint =>
      'Adres e-mail jest szyfrowany i bezpiecznie przechowywany w celu wysłania klientowi notatek z sesji i transkrypcji.';

  @override
  String get addPatient_email_privacy_title => 'Bezpieczeństwo i szyfrowanie';

  @override
  String get addPatient_customize_label_title => 'Spersonalizuj oznaczenie';

  @override
  String get addPatient_discard_action => 'Porzuć';

  @override
  String get addPatient_discard_body => 'Nic nie zostanie zapisane.';

  @override
  String get addPatient_discard_stay => 'Kontynuuj edycję';

  @override
  String get addPatient_discard_title => 'Porzucić zmiany?';

  @override
  String get addPatient_duplicate_body =>
      'Masz już kartotekę z tym pseudonimem. Dodaj inicjał lub przydomek, aby uniknąć pomyłek.';

  @override
  String get addPatient_duplicate_header => 'Taki klient już istnieje';

  @override
  String get addPatient_duplicate_primary => 'Poprawię nazwę';

  @override
  String get addPatient_language_label =>
      'Język, w jakim rozmawiasz z klientem';

  @override
  String get addPatient_last_name_label => 'Pseudonim';

  @override
  String get addPatient_modality_label => 'Nurt terapeutyczny';

  @override
  String get addPatient_no_consent_body =>
      'Nie możemy rozpocząć sesji bez wyraźnej zgody klienta. Wymagają tego przepisy o ochronie danych.';

  @override
  String get addPatient_no_consent_header => 'Brak zgody na nagrywanie';

  @override
  String get addPatient_no_consent_primary => 'Rozumiem';

  @override
  String get addPatient_save_primary => 'Utwórz kartotekę';

  @override
  String get addPatient_skip_for_now => 'Pomiń na razie';

  @override
  String get addPatient_step1_next => 'Dalej';

  @override
  String get addPatient_step1_subtitle => 'Nadaj kartotece pseudonim';

  @override
  String get addPatient_step2_subtitle => 'Ustawienia, które trafią do AI.';

  @override
  String get addPatient_step2_title => 'Dopasuj do Twojej pracy';

  @override
  String get addPatient_subtitle =>
      'Uzupełnij dane klienta, aby utworzyć kartotekę.';

  @override
  String get addPatient_title => 'Nowa kartoteka';

  @override
  String get addSession_subtitle => 'Wybierz nurt dla tej sesji:';

  @override
  String get addSession_title => 'Nowa sesja';

  @override
  String get appLock_reason =>
      'Uwierzytelnij się, aby uzyskać dostęp do Superwizora';

  @override
  String get appLock_subtitle => 'Odblokuj, aby uzyskać dostęp do kartotek';

  @override
  String get appLock_title => 'Aplikacja zablokowana';

  @override
  String get appLock_unlock => 'Odblokuj';

  @override
  String get appLock_retry_hint =>
      'Nie udało się odblokować. Spróbuj ponownie.';

  @override
  String get appTitle => 'Superwizor AI';

  @override
  String get auth_email_label => 'Adres e-mail';

  @override
  String get auth_error_email_already_in_use =>
      'Konto z tym adresem e-mail już istnieje. Zaloguj się.';

  @override
  String get auth_error_generic => 'Wystąpił błąd logowania. Spróbuj ponownie.';

  @override
  String get auth_error_invalid_credential =>
      'Niepoprawny adres e-mail lub hasło.';

  @override
  String get auth_error_invalid_email => 'Niepoprawny format adresu e-mail.';

  @override
  String get auth_error_network =>
      'Brak połączenia z internetem. Spróbuj ponownie.';

  @override
  String get auth_error_too_many_requests =>
      'Zbyt wiele prób logowania. Poczekaj chwilę i spróbuj ponownie.';

  @override
  String get auth_error_user_disabled =>
      'To konto zostało wyłączone. Skontaktuj się z pomocą.';

  @override
  String get auth_error_weak_password =>
      'Hasło jest zbyt krótkie. Użyj minimum 6 znaków.';

  @override
  String get auth_forgot_password => 'Nie pamiętam hasła';

  @override
  String get auth_login_primary => 'Zaloguj się';

  @override
  String get auth_login_title => 'Zaloguj się';

  @override
  String get auth_or_use_email => 'Albo użyj adresu e-mail';

  @override
  String get auth_password_label => 'Hasło';

  @override
  String get auth_password_reset_sent_body =>
      'Wysłaliśmy link do zmiany hasła na Twój e-mail.';

  @override
  String get auth_password_reset_sent_title => 'Link do zmiany hasła wysłany';

  @override
  String get auth_register_primary => 'Załóż konto';

  @override
  String get auth_shared_machine_warning_body =>
      'Po zakończeniu pracy wyloguj się, aby Twoje dane sesji nie zostały dostępne dla kolejnego użytkownika tego komputera.';

  @override
  String get auth_shared_machine_warning_title =>
      'Korzystasz ze współdzielonego komputera?';

  @override
  String get auth_sign_in_with_apple => 'Zaloguj się z Apple';

  @override
  String get auth_sign_in_with_google => 'Kontynuuj z Google';

  @override
  String get auth_social_cancelled => 'Logowanie anulowane';

  @override
  String get auth_social_error =>
      'Logowanie przez konto zewnętrzne nie powiodło się. Spróbuj ponownie.';

  @override
  String get auth_toggle_to_login => 'Masz już konto? Zaloguj się';

  @override
  String get auth_toggle_to_register => 'Nie masz konta? ';

  @override
  String get avatar_customize_background_color => 'KOLOR TŁA';

  @override
  String get avatar_customize_desc =>
      'Nadaj swoim klientom unikalne oznaczenia, aby szybko znaleźć ich w kartotece.';

  @override
  String get billing_choose_plan_cta => 'Wybierz plan';

  @override
  String get billing_delete_confirm_action => 'Usuń trwale';

  @override
  String get billing_delete_confirm_body =>
      'Audio zostanie trwale usunięte z tego urządzenia. Tej operacji nie można cofnąć.';

  @override
  String get billing_delete_confirm_title => 'Usunąć nagranie sesji?';

  @override
  String get billing_delete_local_audio => 'Usuń';

  @override
  String get billing_dismiss_cta => 'Rozumiem, kontynuuj';

  @override
  String get billing_exhausted_dialog_body =>
      'Wykorzystałeś dostępne sesje. Możesz nadal nagrywać, audio zostanie bezpiecznie zaszyfrowane i zapisane lokalnie. Sprawdź swoją skrzynkę e-mail, aby dowiedzieć się więcej.';

  @override
  String get billing_exhausted_dialog_record_locally => 'Nagrywaj lokalnie';

  @override
  String get billing_exhausted_dialog_title => 'Pakiet sesji wyczerpany';

  @override
  String get billing_expand_plan_cta => 'Rozszerz plan';

  @override
  String get billing_past_due_body =>
      'Nie udało się pobrać opłaty za subskrypcję. Do czasu rozwiązania problemu nie będziemy przetwarzać nowych sesji.';

  @override
  String get billing_past_due_title => 'Problem z płatnością';

  @override
  String billing_pending_session_card_meta(
    String date,
    String time,
    int duration,
  ) {
    return 'Sesja z $date, $time ($duration min)';
  }

  @override
  String get billing_pending_session_subtitle =>
      'Audio zapisane lokalnie · Oczekuje na dostępny pakiet';

  @override
  String billing_pending_sessions_title(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Sesji oczekujących na przetworzenie ($n)',
      many: 'Sesji oczekujących na przetworzenie ($n)',
      few: 'Sesje oczekujące na przetworzenie ($n)',
      one: 'Sesja oczekująca na przetworzenie',
    );
    return '$_temp0';
  }

  @override
  String billing_period_end_label(String date) {
    return 'Pula odnawia się $date.';
  }

  @override
  String get billing_quota_critical_short =>
      'Została Ci ostatnia sesja w pakiecie.';

  @override
  String get billing_quota_exhausted_short => 'Pakiet sesji wyczerpany';

  @override
  String get billing_quota_exhausted_subtitle =>
      'Nowe sesje zapiszą się lokalnie do dnia odnowienia.';

  @override
  String billing_quota_warning_short(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Zostało Ci $n sesji w pakiecie.',
      many: 'Zostało Ci $n sesji w pakiecie.',
      few: 'Zostały Ci $n sesje w pakiecie.',
      one: 'Została Ci 1 sesja w pakiecie.',
    );
    return '$_temp0';
  }

  @override
  String get billing_reservation_expired_body =>
      'Rezerwacja sesji wygasła po 4 godzinach. Audio jest nadal zapisane lokalnie.';

  @override
  String get billing_reservation_expired_title =>
      'Przetwarzanie nie powiodło się';

  @override
  String get billing_resume_processing => 'Wznów przetwarzanie';

  @override
  String get billing_retry_cta => 'Spróbuj ponownie';

  @override
  String billing_tokens_available_required(int available, int required) {
    return 'Sesje w pakiecie: $available / Wymagane: $required';
  }

  @override
  String get cancelUpload_back_btn => 'Wróć';

  @override
  String get cancelUpload_confirm_body =>
      'Tej operacji nie można cofnąć. Nagranie i transkrypcja zostaną trwale usunięte.';

  @override
  String get cancelUpload_confirm_title => 'Na pewno?';

  @override
  String get cancelUpload_delete_btn => 'Usuń z analizy';

  @override
  String get cancelUpload_warning_text =>
      'Ta sesja jest w trakcie analizy. Usunięcie jej oznacza bezpowrotną utratę nagrania i transkrypcji. Nie będzie można tego cofnąć.';

  @override
  String get cancel_session_confirm_action => 'Tak, usuń';

  @override
  String get cancel_session_confirm_body =>
      'Sesja zostanie anulowana, a nagranie usunięte z kolejki. Tej operacji nie można cofnąć.';

  @override
  String get cancel_session_confirm_title => 'Anulować przetwarzanie?';

  @override
  String get cancel_session_keep => 'Nie, zostaw';

  @override
  String get cancel_session_success => 'Sesja anulowana';

  @override
  String get clientDetails_btn_delete_session => 'Usuń sesję';

  @override
  String get clientDetails_btn_delete_session_desc =>
      'Trwale usuń nagranie i analizę';

  @override
  String get clientDetails_btn_save_title => 'Zapisz tytuł';

  @override
  String get clientDetails_btn_yes_delete => 'Tak, usuń';

  @override
  String get clientDetails_copy_content => 'Kopiuj treść';

  @override
  String get clientDetails_copy_content_desc => 'Skopiuj notatkę do schowka';

  @override
  String get clientDetails_delete_note_desc => 'Trwale usuń tę notatkę';

  @override
  String get clientDetails_delete_session_desc =>
      'Sesja, nagranie i transkrypcja zostaną trwale usunięte. Tej operacji nie można cofnąć.';

  @override
  String get clientDetails_delete_session_title =>
      'Bezpowrotne usunięcie sesji';

  @override
  String get clientDetails_edit_note_subtitle =>
      'Zmień tytuł lub treść notatki';

  @override
  String get clientDetails_encryption_notice_part1 =>
      'Twoje dane są szyfrowane end-to-end. ';

  @override
  String get clientDetails_encryption_notice_part2 =>
      'Nikt poza Tobą nie ma do nich dostępu.';

  @override
  String clientDetails_error(String error) {
    return 'Błąd: $error';
  }

  @override
  String get clientDetails_manage_session => 'Zarządzaj sesją';

  @override
  String get clientDetails_manage_session_desc => 'Zmień tytuł lub usuń sesję';

  @override
  String get clientDetails_no_content => 'Brak treści';

  @override
  String clientDetails_note_sent_at(String date) {
    return 'Wysłano $date';
  }

  @override
  String get clientDetails_note_sent_badge => 'Wysłano';

  @override
  String get clientDetails_profile_not_loaded =>
      'Profil nie został jeszcze załadowany. Spróbuj za chwilę.';

  @override
  String get clientDetails_record_btn => 'ROZPOCZNIJ NAGRYWANIE';

  @override
  String get clientDetails_record_new_session =>
      'Nagraj nową sesję terapeutyczną';

  @override
  String get clientDetails_send_note_desc => 'Wyślij notatkę mailem do klienta';

  @override
  String clientDetails_session_error(String error) {
    return 'Błąd sesji: $error';
  }

  @override
  String get clientDetails_session_title => 'Sesja';

  @override
  String get clientDetails_session_title_label => 'Tytuł sesji';

  @override
  String get clientDetails_start_first_analysis =>
      'Rozpocznij pierwszą analizę';

  @override
  String get clientDetails_start_work => 'Rozpocznij pracę';

  @override
  String get clientDetails_filter_sessions => 'Sesje';

  @override
  String get clientDetails_filter_client_notes => 'Notatki od klienta';

  @override
  String get clientDetails_filter_own_notes => 'Moje notatki';

  @override
  String get clientDetails_filter_empty =>
      'Brak pozycji dla wybranych filtrów.';

  @override
  String get clientDetails_start_work_desc =>
      'Rozpocznij nagrywanie, a system zadba o bezpieczną transkrypcję i przygotuje raport.';

  @override
  String get clientDetails_status_analyzing => 'AI analizuje…';

  @override
  String get clientDetails_status_converting => 'Konwertuję audio…';

  @override
  String get clientDetails_status_error => 'Błąd analizy';

  @override
  String get clientDetails_status_finalizing => 'Finalizowanie sesji…';

  @override
  String get clientDetails_status_interrupted => 'Przesyłanie przerwane';

  @override
  String get clientDetails_status_new_report => 'Nowy raport';

  @override
  String get clientDetails_status_new_session => 'Nowa sesja';

  @override
  String get clientDetails_status_processing => 'W trakcie przetwarzania…';

  @override
  String get clientDetails_status_processing_audio => 'Przetwarzanie audio…';

  @override
  String get clientDetails_status_processing_label => 'Przetwarzanie';

  @override
  String get clientDetails_status_queued => 'W kolejce…';

  @override
  String get clientDetails_status_ready => 'Gotowy';

  @override
  String get clientDetails_status_requires_attention => 'Wymaga uwagi';

  @override
  String get clientDetails_status_uploading => 'Wysyłanie audio…';

  @override
  String get clientDetails_status_uploading_label => 'Wgrywanie…';

  @override
  String get clientDetails_status_waiting_audio => 'Oczekiwanie na audio…';

  @override
  String get clientDetails_subtitle => 'Nad czym dzisiaj pracujemy?';

  @override
  String get clientDetails_upload_file_btn => 'WGRAJ PLIK Z DYSKU';

  @override
  String get clientDetails_upload_recording => 'Prześlij nagranie z dyktafonu';

  @override
  String get client_action_delete => 'Usuń notatkę';

  @override
  String get client_action_hide => 'Ukryj z panelu';

  @override
  String get client_confirm_cancel => 'Anuluj';

  @override
  String get client_confirm_delete => 'Usuń';

  @override
  String get client_confirm_hide => 'Ukryj';

  @override
  String get client_delete_confirm_body =>
      'Tej notatki nie można przywrócić. Jeśli była wysłana do terapeuty, zniknie także u niego.';

  @override
  String get client_delete_confirm_title => 'Usunąć notatkę?';

  @override
  String get client_deleted_toast => 'Notatka usunięta';

  @override
  String get client_filter_all => 'Wszystko';

  @override
  String get client_filter_empty => 'Brak pozycji w tym filtrze.';

  @override
  String get client_filter_own => 'Notatki własne';

  @override
  String get client_filter_sessions => 'Sesje';

  @override
  String get client_filter_therapist => 'Zadania i notatki terapeuty';

  @override
  String get client_hidden_toast => 'Ukryto z panelu';

  @override
  String get client_hide_confirm_body =>
      'Pozycja zniknie z Twojego panelu. Terapeuta zachowa ją u siebie.';

  @override
  String get client_hide_confirm_title => 'Ukryć z panelu?';

  @override
  String get client_home_empty =>
      'Twój terapeuta nie udostępnił jeszcze żadnych materiałów.';

  @override
  String client_home_error(String error) {
    return 'Nie udało się załadować danych: $error';
  }

  @override
  String get client_home_subtitle =>
      'Materiały udostępnione przez terapeutę i Twoje notatki.';

  @override
  String get client_home_title => 'Twoje sesje';

  @override
  String get client_panel_title => 'Twój panel';

  @override
  String client_kartoteka_counts(int sessions, int notes) {
    return '$sessions sesji · $notes notatek';
  }

  @override
  String client_kartoteka_therapist(String name) {
    return 'Terapeuta: $name';
  }

  @override
  String get client_logout => 'Wyloguj się';

  @override
  String get client_new_badge => 'NOWA';

  @override
  String get client_note_close => 'Zamknij';

  @override
  String get client_note_draft_badge => 'SZKIC';

  @override
  String get client_note_empty_error => 'Notatka nie może być pusta.';

  @override
  String get client_note_from_therapist => 'Od terapeuty';

  @override
  String get client_note_mine => 'Moja notatka';

  @override
  String get client_note_mine_draft => 'Szkic (tylko dla Ciebie)';

  @override
  String get client_note_mine_sent => 'Wysłana do terapeuty';

  @override
  String get client_note_new => 'Nowa notatka';

  @override
  String get client_note_save => 'Zapisz';

  @override
  String get client_note_save_and_send => 'Zapisz i wyślij do terapeuty';

  @override
  String get client_note_saved_draft => 'Notatka zapisana w panelu.';

  @override
  String get client_note_send => 'Wyślij do terapeuty';

  @override
  String get client_note_sent => 'Notatka wysłana do terapeuty.';

  @override
  String get client_note_text_hint => 'Twoje przemyślenia…';

  @override
  String get client_note_title_hint => 'Tytuł';

  @override
  String get client_notes_empty =>
      'Brak notatek. Utwórz pierwszą i wyślij ją terapeucie.';

  @override
  String get client_session_add_note => 'Dodaj notatkę do sesji';

  @override
  String get client_session_no_transcript =>
      'Transkrypcja nie jest jeszcze dostępna.';

  @override
  String client_session_title(int number) {
    return 'Sesja $number';
  }

  @override
  String get client_session_transcript_chip => 'Transkrypcja';

  @override
  String get client_sessions_empty => 'Brak udostępnionych sesji';

  @override
  String get client_tab_notes => 'Notatki';

  @override
  String get client_tab_sessions => 'Sesje';

  @override
  String get client_theme_tooltip => 'Zmień motyw (jasny/ciemny)';

  @override
  String client_unread_badge(int count) {
    return '$count nowe';
  }

  @override
  String get common_back => 'Wróć';

  @override
  String get common_cancel => 'Anuluj';

  @override
  String get common_close => 'Zamknij';

  @override
  String get common_continue => 'Kontynuuj';

  @override
  String get common_copied_to_clipboard => 'Skopiowano do schowka';

  @override
  String get common_delete => 'Usuń';

  @override
  String get common_done => 'Gotowe';

  @override
  String get common_error => 'Wystąpił błąd';

  @override
  String get common_got_it => 'Zrozumiałem';

  @override
  String get common_loading => 'Ładowanie…';

  @override
  String get common_not_found => 'Nie znaleziono';

  @override
  String get common_or => 'lub';

  @override
  String get common_retry => 'Spróbuj ponownie';

  @override
  String get common_save => 'Zapisz';

  @override
  String get common_understand => 'Rozumiem';

  @override
  String get connectivity_offline_banner =>
      'Brak połączenia. Niektóre funkcje są ograniczone.';

  @override
  String get deactivated_body =>
      'Twoje konto zostało dezaktywowane przez administratora organizacji. Skontaktuj się z nim, aby przywrócić dostęp.';

  @override
  String get deactivated_logout => 'Wyloguj się';

  @override
  String get deactivated_title => 'Konto nieaktywne';

  @override
  String get delete_account_button => 'Usuń moje konto';

  @override
  String get delete_account_confirm_word => 'usuwam';

  @override
  String get delete_account_consequence_1 =>
      'Cała dokumentacja kliniczna (wszystkich klientów, kartoteki, sesje i raporty AI) zostanie trwale usunięta.';

  @override
  String get delete_account_consequence_2 =>
      'Twoja subskrypcja (jeśli ją posiadasz) nie zostanie automatycznie anulowana. Musisz ją anulować osobno w App Store lub Google Play.';

  @override
  String get delete_account_consequence_3 =>
      'Nie będziesz mógł odzyskać danych po zakończeniu tego procesu. Operacja jest nieodwracalna.';

  @override
  String get delete_account_reason_label =>
      'Dlaczego odchodzisz? (opcjonalnie)';

  @override
  String get delete_account_reason_hint =>
      'Twoja odpowiedź pomoże nam się poprawić.';

  @override
  String get delete_account_failed =>
      'Nie udało się usunąć konta. Spróbuj ponownie.';

  @override
  String get delete_account_relogin_error =>
      'Zaloguj się ponownie, by usunąć konto.';

  @override
  String get delete_account_sheet_button => 'USUWAM KONTO';

  @override
  String get delete_account_sheet_cancel => 'Anuluj';

  @override
  String get delete_account_sheet_hint => 'wpisz tutaj…';

  @override
  String get delete_account_sheet_subtitle => 'Aby potwierdzić, wpisz:';

  @override
  String get delete_account_sheet_title => 'Ostatni krok';

  @override
  String get delete_account_store_sub_title => 'Najpierw anuluj subskrypcję';

  @override
  String get delete_account_store_sub_body =>
      'Masz aktywną subskrypcję kupioną w sklepie. Usunięcie konta jej nie anuluje — zrób to w ustawieniach subskrypcji, inaczej sklep będzie pobierał opłaty dalej.';

  @override
  String get delete_account_store_sub_open => 'Otwórz ustawienia subskrypcji';

  @override
  String get delete_account_store_sub_force => 'Rozumiem, usuń mimo to';

  @override
  String get delete_account_title => 'Usuń konto';

  @override
  String get delete_account_toggle_text =>
      'Rozumiem konsekwencje\ni chcę usunąć konto';

  @override
  String get drawer_about => 'O aplikacji';

  @override
  String get drawer_btn_delete_account => 'Usuń konto';

  @override
  String get drawer_btn_logout => 'Wyloguj się';

  @override
  String get drawer_delete_account => 'Usuń konto';

  @override
  String get drawer_fallback_name => 'Terapeuta';

  @override
  String get drawer_language => 'Język aplikacji';

  @override
  String get drawer_legal_dpa => 'DPA / RODO';

  @override
  String get drawer_legal_header => 'DOKUMENTY PRAWNE';

  @override
  String get drawer_legal_terms => 'Regulamin';

  @override
  String get drawer_logout => 'Wyloguj';

  @override
  String get drawer_modalities => 'Nurty terapii';

  @override
  String get drawer_profile => 'Mój profil';

  @override
  String get drawer_settings_header => 'USTAWIENIA';

  @override
  String get editPatient_erase_confirm_body =>
      'Zgodnie z wymogami RODO usuniemy trwale wszystkie dane pacjenta, łącznie z sesjami i raportami AI. Tej operacji nie będzie można już cofnąć.';

  @override
  String get editPatient_erase_confirm_header =>
      'Całkowite usunięcie kartoteki';

  @override
  String get editPatient_erase_destructive => 'Usuń kartotekę bezpowrotnie';

  @override
  String get editPatient_email_readonly_hint =>
      'E-mail zmienisz, wysyłając nowe zaproszenie do panelu klienta.';

  @override
  String editPatient_error(String error) {
    return 'Błąd: $error';
  }

  @override
  String get editPatient_save_primary => 'Zapisz zmiany';

  @override
  String get editPatient_title => 'Edytuj kartotekę';

  @override
  String get forgot_btn_back_to_login => 'Wróć do logowania';

  @override
  String get forgot_btn_send_again => 'Wyślij ponownie';

  @override
  String get forgot_btn_send_link => 'Wyślij link';

  @override
  String get forgot_check_mailbox_title => 'Sprawdź skrzynkę';

  @override
  String get forgot_desc_part1 =>
      'Podaj adres e-mail powiązany z Twoim kontem. ';

  @override
  String get forgot_desc_part2 => 'Wyślemy Ci link do ustawienia nowego hasła.';

  @override
  String get forgot_email_hint => 'Twój adres e-mail';

  @override
  String get forgot_err_generic => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get forgot_err_invalid_email =>
      'Ten adres e-mail wygląda nieprawidłowo.';

  @override
  String get forgot_err_too_many_requests => 'Za dużo prób. Odczekaj chwilę.';

  @override
  String get forgot_err_user_not_found =>
      'Nie znaleźliśmy konta z tym adresem.';

  @override
  String get forgot_password_link_expiry => 'Link wygasa po 1 godzinie';

  @override
  String get forgot_sent_msg_prefix => 'Wysłaliśmy wiadomość na adres\n';

  @override
  String get forgot_spam_check_part1 =>
      'Nie widzisz wiadomości? Sprawdź folder spam. ';

  @override
  String get forgot_spam_check_part2 => 'Wysyłka może potrwać do 2 minut.';

  @override
  String get forgot_step_click_link => 'Kliknij w link „Zresetuj hasło\"';

  @override
  String get forgot_step_login => 'Ustaw nowe hasło i zaloguj się';

  @override
  String get forgot_step_open_email => 'Otwórz swoją skrzynkę e-mail';

  @override
  String get forgot_title => 'Resetowanie hasła';

  @override
  String hard_delete_body(String word) {
    return 'Skasujemy Twój profil terapeuty, wszystkie sesje, transkrypcje i raporty. Tej akcji nie można cofnąć. Jeśli jesteś pewna/pewien, wpisz słowo $word.';
  }

  @override
  String get hard_delete_btn_confirm => 'Usuń bezpowrotnie';

  @override
  String get hard_delete_error => 'Błąd usuwania';

  @override
  String get hard_delete_title => 'Usunięcie konta jest bezpowrotne';

  @override
  String get home_add_patient_fab => 'Dodaj klienta';

  @override
  String get home_add_patient_offline =>
      'Tworzenie kartoteki wymaga połączenia z internetem';

  @override
  String get home_card_last_prefix_only => 'Ostatnio: ';

  @override
  String get home_card_last_session_prefix => ' • Ostatnio: ';

  @override
  String get home_card_sessions_prefix => 'Sesje: ';

  @override
  String get home_delete_btn_cancel => 'Anuluj';

  @override
  String get home_delete_btn_confirm => 'Usuń klienta';

  @override
  String get home_delete_btn_continue => 'Kontynuuj kasowanie';

  @override
  String get home_delete_confirm_hint => 'wpisz tutaj…';

  @override
  String get home_delete_confirm_instruction => 'Aby potwierdzić, wpisz:';

  @override
  String get home_delete_confirm_word => 'usuwam';

  @override
  String home_delete_error_toast(String error) {
    return 'Błąd usunięcia: $error';
  }

  @override
  String home_delete_title(String name) {
    return 'Usunęcie klienta: $name';
  }

  @override
  String get home_delete_warning_body =>
      'Cała dokumentacja kliniczna — sesje, notatki AI oraz nagrania audio — zostanie trwale i bezpowrotnie usunięta z baz medycznych.\nZgodnie z RODO (prawo do zapomnienia).';

  @override
  String get home_delete_warning_understand => 'Rozumiem, to nieodwracalne';

  @override
  String get home_empty_body => 'Dodaj klienta, aby rozpocząć pierwszą sesję.';

  @override
  String get home_empty_list => 'Dodaj pierwszego klienta, aby rozpocząć.';

  @override
  String get home_empty_title => 'Nie masz jeszcze żadnych klientów';

  @override
  String home_error_loading(String error) {
    return 'Błąd: $error';
  }

  @override
  String home_error_toast(String error) {
    return 'Błąd: $error';
  }

  @override
  String get home_greeting_prefix => 'Witaj, ';

  @override
  String get home_greeting_subtitle => 'Z kim dzisiaj pracujemy?';

  @override
  String get home_manage_card => 'Zarządzaj kartoteką klienta';

  @override
  String get home_manage_edit_card => 'Edytuj kartotekę';

  @override
  String get home_menu_btn_back => 'Wróć';

  @override
  String get home_menu_btn_save => 'Zapisz';

  @override
  String get home_menu_delete_patient => 'Usuń kartotekę';

  @override
  String get home_menu_delete_patient_desc =>
      'Skasuj historię, sesje i notatki';

  @override
  String get home_menu_edit_client => 'Edytuj kartotekę';

  @override
  String get home_menu_edit_data => 'Edytuj dane';

  @override
  String get home_menu_edit_data_desc => 'Zmień pseudonim';

  @override
  String get home_menu_field_email => 'E-mail klienta';

  @override
  String get home_menu_field_last_name => 'Inicjał lub pseudonim';

  @override
  String get home_menu_invite_client_desc =>
      'Wyślij e-mail z dostępem do panelu klienta';

  @override
  String get home_menu_lifecycle_active => 'Aktywna';

  @override
  String get home_menu_lifecycle_completed => 'Zakończona';

  @override
  String get home_menu_lifecycle_paused => 'Wstrzymana';

  @override
  String get home_menu_manage_client => 'Zarządzaj kartoteką klienta';

  @override
  String home_no_search_results(String query) {
    return 'Brak wyników dla „$query”';
  }

  @override
  String home_report_ready_toast(String name) {
    return 'Raport gotowy, $name 🎉';
  }

  @override
  String get home_search_hint => 'Szukaj klienta…';

  @override
  String get home_section_active => 'TWOJE KARTOTEKI';

  @override
  String get home_section_active_filtered => 'TWOJE KARTOTEKI • FILTR';

  @override
  String home_section_completed(int count) {
    return 'ZAKOŃCZONE ($count)';
  }

  @override
  String home_section_paused(int count) {
    return 'WSTRZYMANE ($count)';
  }

  @override
  String get home_section_paused_tooltip =>
      'Wstrzymane kartoteki nie będą wyświetlać się w głównym widoku aktywnych pacjentów.';

  @override
  String get home_status_active => 'Aktywny';

  @override
  String get home_status_analyzing => 'AI analizuje';

  @override
  String get home_status_awaiting_first_session => 'Oczekuje na pierwszą sesję';

  @override
  String get home_status_completed => 'Zakończony';

  @override
  String get home_status_error => 'Błąd analizy';

  @override
  String get home_status_has_new_report => 'Nowy raport';

  @override
  String get home_status_new => 'Nowy';

  @override
  String get home_status_new_client => 'Nowy klient';

  @override
  String get home_status_paused => 'Wstrzymany';

  @override
  String get home_status_recording => 'Nagrywanie';

  @override
  String get home_status_upload_failed => 'Przesyłanie\nprzerwane';

  @override
  String get home_status_uploading => 'Wgrywanie…';

  @override
  String get home_title => 'Twoi klienci';

  @override
  String get invite_client_desc =>
      'Klient otrzyma e-mail z linkiem do bezpiecznego panelu, w którym zobaczy udostępnione sesje i notatki oraz będzie mógł pisać do Ciebie notatki.';

  @override
  String get invite_client_email_label => 'E-mail klienta';

  @override
  String get invite_client_email_missing => 'Podaj poprawny e-mail klienta.';

  @override
  String get invite_client_email_taken =>
      'Ten e-mail jest już powiązany z innym kontem.';

  @override
  String get invite_client_error =>
      'Nie udało się wysłać zaproszenia. Spróbuj ponownie.';

  @override
  String get invite_client_resend => 'Wyślij ponownie';

  @override
  String get invite_client_self_email => 'Nie możesz zaprosić samego siebie.';

  @override
  String get invite_client_send => 'Wyślij zaproszenie';

  @override
  String get invite_client_sent => 'Zaproszenie wysłane';

  @override
  String get invite_client_status_active => 'Panel klienta jest aktywny.';

  @override
  String get invite_client_status_inactive =>
      'Konto klienta jest dezaktywowane.';

  @override
  String invite_client_status_pending(String email, String date) {
    return 'Zaproszenie oczekuje — wysłane na $email, ważne do $date.';
  }

  @override
  String get invite_client_title => 'Zaproś klienta';

  @override
  String get language_en_name => 'English';

  @override
  String get language_en_sub => 'angielski (Wlk. Brytania)';

  @override
  String get language_pl_name => 'Polski';

  @override
  String get language_pl_sub => 'polski';

  @override
  String get language_popup_body =>
      'Obecnie wspieramy w pełni język polski. Przełączyliśmy Twój język docelowy na polski.';

  @override
  String get language_popup_title => 'Język aplikacji';

  @override
  String get live_activity_info_body =>
      'Włącz podgląd na ekranie blokady, aby widzieć czas sesji bez otwierania aplikacji.';

  @override
  String get live_activity_info_dismiss => 'Nie teraz';

  @override
  String get live_activity_info_enable => 'Włącz podgląd';

  @override
  String get live_activity_info_title => 'Miej sesję zawsze na oku';

  @override
  String get live_activity_minimize_toast =>
      'Sesja działa w tle. Aby widzieć jej czas na ekranie blokady, włącz podgląd w Ustawieniach.';

  @override
  String get live_activity_permission_body =>
      'Podgląd sesji na ekranie blokady wymaga włączenia Aktywności na żywo w ustawieniach systemu.';

  @override
  String get live_activity_permission_cancel => 'Anuluj';

  @override
  String get live_activity_permission_open_settings => 'Otwórz ustawienia';

  @override
  String get live_activity_permission_title => 'Wymagana zgoda systemowa';

  @override
  String get live_activity_show_report => 'Pokaż raport';

  @override
  String get live_activity_status_analyzing => 'Analizowanie sesji...';

  @override
  String get live_activity_status_paused => 'Pauza';

  @override
  String get live_activity_status_recording => 'Sesja w toku';

  @override
  String get live_activity_status_report_ready =>
      'Nowy raport czeka w kartotece';

  @override
  String get live_activity_status_uploading => 'Wgrywanie nagrania...';

  @override
  String get login_accept_prefix => 'Akceptuję ';

  @override
  String get login_accept_privacy => 'Politykę Prywatności';

  @override
  String get login_accept_terms_error =>
      'Zaakceptuj Regulamin i Politykę Prywatności, aby kontynuować.';

  @override
  String get login_already_have_account => 'Masz już konto? ';

  @override
  String login_auth_error(String code, String message) {
    return 'Błąd uwierzytelniania [$code]: $message';
  }

  @override
  String get login_btn_sign_in => 'Zaloguj się';

  @override
  String get login_btn_sign_up => 'Zarejestruj się';

  @override
  String get login_forgot_password => 'Nie pamiętam hasła';

  @override
  String get login_name_field => 'Imię i nazwisko';

  @override
  String get login_password_hint => 'Utwórz hasło (min. 8 znaków)';

  @override
  String get login_privacy_policy_title => 'Polityka Prywatności';

  @override
  String get login_register_subtitle => 'Dołącz do społeczności terapeutów';

  @override
  String get login_register_title => 'Utwórz konto';

  @override
  String get login_account_info_title => 'Jak założyć konto?';

  @override
  String get login_account_info_subtitle => 'Rejestracja i konfiguracja';

  @override
  String get login_account_info_body_1 =>
      'Ze względów bezpieczeństwa oraz spójności konfiguracji Twojej praktyki terapeutycznej, rejestracja nowych kont odbywa się wyłącznie na naszej stronie internetowej.';

  @override
  String get login_account_info_body_2 =>
      'Jeśli posiadasz już aktywne konto, po prostu zaloguj się swoimi danymi.';

  @override
  String get login_back_to_sign_in => 'Wróć do logowania';

  @override
  String get auth_toggle_register_action => 'Dowiedz się więcej';

  @override
  String get login_subtitle => 'Zaloguj się do Superwizor AI';

  @override
  String get login_title => 'Witaj ponownie';

  @override
  String get menu_avatar_camera => 'Aparat';

  @override
  String get menu_avatar_desc => 'Wybierz skąd chcesz dodać zdjęcie.';

  @override
  String get menu_avatar_gallery => 'Galeria';

  @override
  String get menu_avatar_title => 'Zdjęcie profilowe';

  @override
  String get menu_avatar_updated => 'Zdjęcie profilowe zaktualizowane';

  @override
  String get menu_btn_send_verification => 'Wyślij weryfikację';

  @override
  String get menu_change_email_desc =>
      'Wyślemy link weryfikacyjny na nowy adres.';

  @override
  String get menu_change_email_title => 'Zmień adres e-mail';

  @override
  String get menu_delete_account_confirm_title =>
      'Trwałe i nieodwracalne usunięcie';

  @override
  String get menu_email_in_use => 'Ten adres jest już używany.';

  @override
  String menu_error_message(String error) {
    return 'Wystąpił błąd: $error';
  }

  @override
  String get menu_invalid_email => 'Podaj prawidłowy adres e-mail.';

  @override
  String get menu_reauth_required =>
      'Zaloguj się ponownie, aby zmienić e-mail.';

  @override
  String menu_save_error(String error) {
    return 'Wystąpił błąd podczas zapisu: $error';
  }

  @override
  String menu_verification_sent(String email) {
    return 'Link weryfikacyjny wysłany na $email';
  }

  @override
  String get minimized_recording_active => 'Trwa nagrywanie sesji';

  @override
  String get minimized_recording_interrupted => 'Wstrzymane (połączenie)';

  @override
  String get minimized_recording_paused => 'Pauza nagrywania';

  @override
  String get modality_abbr_cbt => 'CBT';

  @override
  String get modality_abbr_coach => 'Coaching';

  @override
  String get modality_abbr_eft => 'EFT';

  @override
  String get modality_abbr_gestalt => 'Gestalt';

  @override
  String get modality_abbr_ppt => 'PPT';

  @override
  String get modality_abbr_psycho => 'Psychod.';

  @override
  String get modality_abbr_st => 'ST';

  @override
  String get modality_abbr_sys => 'System.';

  @override
  String get modality_abbr_univ => 'Integr.';

  @override
  String get modality_cbt => 'Poznawczo-Behawioralny (CBT)';

  @override
  String get modality_coaching => 'Coaching (ICF/GROW)';

  @override
  String get modality_eft => 'Skoncentrowana na Emocjach (EFT)';

  @override
  String get modality_gestalt => 'Gestalt';

  @override
  String get modality_integrative => 'Uniwersalny / Integracyjny';

  @override
  String get modality_positive => 'Pozytywny (PPT)';

  @override
  String get modality_psychodynamic => 'Psychodynamiczny';

  @override
  String get modality_schema => 'Terapia Schematów (ST)';

  @override
  String get modality_sheet_subtitle =>
      'To ustawienie wpływa na generowane raporty. Możesz je zmienić w każdej chwili.';

  @override
  String get modality_sheet_title => 'Wybierz swój nurt';

  @override
  String get modality_systemic => 'Systemowa (dla par i rodzin)';

  @override
  String get newSession_encryption_notice_part1 =>
      'Twoje nagrania są chronione szyfrowaniem end-to-end i służą wyłącznie ';

  @override
  String get newSession_encryption_notice_part2 =>
      'do analizy AI. Nikt poza Tobą nie ma dostępu do danych.';

  @override
  String get newSession_error_header => 'Błąd';

  @override
  String newSession_file_too_large(String size) {
    return 'Plik jest zbyt duży ($size MB). ';
  }

  @override
  String newSession_format_not_supported(String ext) {
    return 'Format \"$ext\" nie jest obsługiwany.\n\n';
  }

  @override
  String get newSession_new_session_header => 'NOWA SESJA';

  @override
  String get newSession_pick_file_desc =>
      'Wybierz plik audio z dysku. Po przesłaniu plik zostanie automatycznie przeanalizowany.';

  @override
  String get newSession_preparing_file => 'Przygotowuję plik...';

  @override
  String get newSession_queuing => 'Kolejkuję...';

  @override
  String get newSession_record_or_upload_desc =>
      'Nagraj tę sesję, lub prześlij plik audio z dyktafonu.';

  @override
  String get newSession_recording_active_err =>
      'Trwa nagrywanie sesji. Wróć do niej, aby kontynuować.';

  @override
  String get newSession_recording_in_progress_err =>
      'Trwa nagrywanie innej sesji. Wróć do niej, aby kontynuować.';

  @override
  String get newSession_secure_upload_desc =>
      'Twój plik jest szyfrowany i bezpiecznie przesyłany na nasze serwery w Europie. Nikt poza Tobą nie ma dostępu do tych danych.';

  @override
  String get newSession_secure_upload_title => 'Bezpieczne przesyłanie';

  @override
  String get newSession_supported_formats =>
      'Obsługiwane formaty: FLAC, WAV, MP3, OGG, OPUS, M4A, AAC, WEBM, AMR.';

  @override
  String newSession_upload_error(String error) {
    return 'Błąd podczas przesyłania pliku:\n$error';
  }

  @override
  String get newSession_upload_file_header => 'PRZESYŁANIE PLIKU';

  @override
  String get newSession_uploading_file => 'Przesyłam plik...';

  @override
  String get note_add_label => 'DODAJ NOTATKĘ';

  @override
  String get note_add_subtitle => 'Szybka notatka o kliencie';

  @override
  String get note_body_hint => 'Treść notatki…';

  @override
  String get note_delete_action => 'Usuń';

  @override
  String get note_delete_confirm => 'Usunąć notatkę?';

  @override
  String get note_delete_desc =>
      'Notatka zostanie trwale usunięta z kartoteki klienta. Operacji nie można cofnąć.';

  @override
  String get note_deleted => 'Notatka usunięta';

  @override
  String get note_discard_action => 'Odrzuć';

  @override
  String get note_discard_body =>
      'Masz niezapisane zmiany. Chcesz je odrzucić?';

  @override
  String get note_discard_save => 'Zapisz';

  @override
  String get note_discard_title => 'Odrzucić zmiany?';

  @override
  String get note_edit_label => 'Edytuj notatkę';

  @override
  String get note_empty_text => 'Notatka nie może być pusta.';

  @override
  String get note_from_client => 'Od klienta';

  @override
  String get note_from_client_new => 'NOWA';

  @override
  String get note_save_error => 'Nie udało się zapisać notatki';

  @override
  String get note_saved => 'Notatka zapisana ✓';

  @override
  String note_send_confirm_body(String email) {
    return 'Notatka zostanie wysłana na adres: $email';
  }

  @override
  String get note_send_confirm_title => 'Wysłać notatkę do klienta?';

  @override
  String get note_send_to_client => 'Wyślij do klienta';

  @override
  String get note_sent_toast => 'Notatka wysłana do klienta';

  @override
  String get note_sheet_cancel => 'Anuluj';

  @override
  String get note_sheet_hint => 'Wpisz swoją notatkę…';

  @override
  String get note_sheet_save => 'Zapisz';

  @override
  String get note_sheet_title => 'Nowa notatka';

  @override
  String get note_title_hint => 'Tytuł notatki';

  @override
  String get note_untitled => 'Bez tytułu';

  @override
  String get offline_banner_desc =>
      'Jesteś w trybie offline. Aplikacja działa, ale synchronizacja nastąpi po odzyskaniu połączenia.';

  @override
  String get offline_banner_title => 'Brak połączenia';

  @override
  String get patient_no_sessions => 'Brak sesji';

  @override
  String patient_session_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesji',
      many: '$count sesji',
      few: '$count sesje',
      one: '1 sesja',
      zero: 'Brak sesji',
    );
    return '$_temp0';
  }

  @override
  String get patient_start_session => 'Rozpocznij nagrywanie sesji';

  @override
  String pendingUploads_pill_analyzing(int count) {
    return '$count analiza';
  }

  @override
  String pendingUploads_pill_attention(int count) {
    return '$count wymaga uwagi';
  }

  @override
  String pendingUploads_pill_in_progress(int count) {
    return '$count w toku';
  }

  @override
  String pendingUploads_pill_retrying(int count) {
    return '$count wznawianie';
  }

  @override
  String get pending_uploads_btn_checking => 'Sprawdzam...';

  @override
  String get pending_uploads_btn_resend => 'Prześlij ponownie';

  @override
  String get pending_uploads_btn_send_again => 'Wyślij ponownie';

  @override
  String get pending_uploads_default_patient_name => 'Pacjent';

  @override
  String pending_uploads_detail_attempt(int attempt) {
    return ' • próba $attempt';
  }

  @override
  String get pending_uploads_empty_body => 'Wszystkie sesje zostały wgrane.';

  @override
  String get pending_uploads_empty_title => 'Brak plików w kolejce';

  @override
  String get pending_uploads_err_reason_link_expired =>
      'link do przesyłania wygasł';

  @override
  String get pending_uploads_err_reason_no_internet =>
      'brak połączenia z internetem';

  @override
  String pending_uploads_err_reason_prefix(String reason) {
    return 'Powód błędu: $reason';
  }

  @override
  String get pending_uploads_err_reason_timeout =>
      'serwer nie odpowiedział w terminie';

  @override
  String get pending_uploads_err_reason_unavailable =>
      'serwer chwilowo niedostępny';

  @override
  String pending_uploads_error(String error) {
    return 'Błąd: $error';
  }

  @override
  String get pending_uploads_error_desc =>
      'Przesyłanie zostało przerwane z powodu błędu, ale Twoje nagranie jest bezpiecznie zapisane na tym urządzeniu. Spróbuj przesłać je ponownie.';

  @override
  String get pending_uploads_error_title => 'Błąd przesyłania';

  @override
  String get pending_uploads_no_internet_desc =>
      'Przesyłanie zostało przerwane, ale Twoje nagranie jest bezpiecznie zapisane na tym urządzeniu. Spróbuj przesłać je ponownie, gdy odzyskasz zasięg.';

  @override
  String get pending_uploads_no_internet_title =>
      'Brak połączenia z internetem';

  @override
  String get pending_uploads_phase_completed => 'Wgrane';

  @override
  String get pending_uploads_phase_converted =>
      'Konwersja gotowa — finalizuję...';

  @override
  String get pending_uploads_phase_converting => 'Konwersja pliku audio...';

  @override
  String get pending_uploads_phase_encrypting => 'Szyfrowanie nagrania...';

  @override
  String get pending_uploads_phase_failed => 'Przesyłanie przerwane';

  @override
  String get pending_uploads_phase_offline => 'Offline — wyślemy automatycznie';

  @override
  String get purchase_error_foreign_account =>
      'Ten zakup jest przypisany do innego konta Superwizor AI. Zaloguj się na to konto albo napisz do nas.';

  @override
  String get purchase_error_store_not_configured =>
      'Zakupy w sklepie nie są jeszcze skonfigurowane. Spróbuj ponownie później.';

  @override
  String get purchase_error_sandbox_not_allowed =>
      'To konto nie ma dostępu do zakupów testowych.';

  @override
  String get plan_picker_loading_title => 'Sprawdzamy dostępne plany';

  @override
  String get plan_picker_loading =>
      'Pytamy serwer o Twoją subskrypcję. To zwykle chwila.';

  @override
  String get plan_picker_unavailable_title => 'Zakupy chwilowo niedostępne';

  @override
  String get plan_picker_unavailable_body =>
      'Nie możesz teraz wykupić planu w tej aplikacji. Twoje nagrania i raporty działają bez zmian.';

  @override
  String plan_picker_blocked_until(String date) {
    return 'Obowiązuje do $date.';
  }

  @override
  String get register_title => 'Załóż konto';

  @override
  String get register_subtitle => 'Kilka pól i możesz nagrać pierwszą sesję.';

  @override
  String get register_email_divider => 'albo adresem e-mail';

  @override
  String get register_email_cta => 'Załóż konto e-mailem';

  @override
  String get register_password_hint => 'Hasło (min. 8 znaków)';

  @override
  String get register_have_account => 'Masz już konto? ';

  @override
  String get register_sign_in_action => 'Zaloguj się';

  @override
  String get profile_setup_title => 'Twój profil';

  @override
  String get profile_setup_subtitle =>
      'Te trzy pola wystarczą, żeby zacząć. Resztę uzupełnisz później w ustawieniach.';

  @override
  String get profile_setup_first_name => 'Imię';

  @override
  String get profile_setup_last_name => 'Nazwisko';

  @override
  String get profile_setup_modality_label => 'Nurt terapeutyczny';

  @override
  String get profile_setup_modality_hint => 'Wybierz nurt';

  @override
  String get profile_setup_modality_help =>
      'Nurt decyduje o tym, jak AI układa raporty z sesji. Zmienisz go w każdej chwili.';

  @override
  String get profile_setup_consent_prefix => 'Akceptuję ';

  @override
  String get profile_setup_consent_terms => 'Regulamin';

  @override
  String get profile_setup_consent_conjunction => ' i ';

  @override
  String get profile_setup_consent_privacy => 'Politykę prywatności';

  @override
  String get profile_setup_error_first_name => 'Podaj imię.';

  @override
  String get profile_setup_error_last_name => 'Podaj nazwisko.';

  @override
  String get profile_setup_error_consent =>
      'Zaakceptuj Regulamin i Politykę prywatności, aby kontynuować.';

  @override
  String get profile_setup_submit => 'Zakładam konto';

  @override
  String get profile_setup_failed =>
      'Nie udało się założyć konta. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get subscription_paused_title => 'Subskrypcja wstrzymana';

  @override
  String get subscription_paused_body =>
      'Subskrypcja jest wstrzymana w Google Play. Wznów ją, żeby znów przetwarzać sesje.';

  @override
  String get subscription_resume_in_store => 'Wznów w Google Play';

  @override
  String get subscription_status_label => 'Status';

  @override
  String get subscription_status_active => 'Aktywna';

  @override
  String get subscription_status_trialing => 'Okres próbny';

  @override
  String get subscription_status_past_due => 'Zaległa płatność';

  @override
  String get subscription_status_paused => 'Wstrzymana';

  @override
  String get subscription_status_canceled => 'Zakończona';

  @override
  String subscription_cancel_at_period_end(String date) {
    return 'Subskrypcja nie odnowi się — dostęp masz do $date.';
  }

  @override
  String get upload_error_email_unverified =>
      'Potwierdź adres e-mail, żeby wysłać nagranie do analizy.';

  @override
  String get plan_picker_title => 'Wybierz plan';

  @override
  String get plan_picker_subtitle =>
      'Plan możesz zmienić lub anulować w każdej chwili.';

  @override
  String get plan_picker_cycle_monthly => 'Miesięcznie';

  @override
  String get plan_picker_cycle_annual => 'Rocznie';

  @override
  String plan_picker_sessions(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sesji w okresie rozliczeniowym',
      many: '$n sesji w okresie rozliczeniowym',
      few: '$n sesje w okresie rozliczeniowym',
      one: '1 sesja w okresie rozliczeniowym',
    );
    return '$_temp0';
  }

  @override
  String get plan_picker_cta => 'Wykup plan';

  @override
  String get plan_picker_skip => 'Na razie bez planu';

  @override
  String get plan_picker_restore => 'Przywróć zakupy';

  @override
  String get plan_picker_empty =>
      'Na tym urządzeniu nie ma teraz planów do kupienia.';

  @override
  String get plan_picker_legal_monthly =>
      'Płatność co miesiąc, subskrypcja odnawia się automatycznie do czasu anulowania. Anulujesz w ustawieniach sklepu, najpóźniej 24 godziny przed końcem okresu. Rachunek wystawia sklep.';

  @override
  String get plan_picker_legal_annual =>
      'Płatność co rok, subskrypcja odnawia się automatycznie do czasu anulowania. Anulujesz w ustawieniach sklepu, najpóźniej 24 godziny przed końcem okresu. Rachunek wystawia sklep.';

  @override
  String get plan_picker_legal_terms => 'Regulamin';

  @override
  String get plan_picker_legal_privacy => 'Polityka prywatności';

  @override
  String get plan_picker_current_plan => 'Twój obecny plan';

  @override
  String get purchase_success => 'Plan aktywny. Miłej pracy!';

  @override
  String get purchase_pending =>
      'Sklep czeka na potwierdzenie płatności. Damy znać, gdy plan będzie aktywny.';

  @override
  String get purchase_error_store_unavailable =>
      'Sklep jest niedostępny na tym urządzeniu.';

  @override
  String get purchase_error_product_unavailable =>
      'Ten plan jest chwilowo niedostępny w sklepie.';

  @override
  String get purchase_error_verification =>
      'Zapłaciłeś, ale nie udało się potwierdzić zakupu na serwerze. Nic nie przepadło — dokończymy przy następnym uruchomieniu aplikacji.';

  @override
  String get purchase_error_generic =>
      'Zakup się nie powiódł. Spróbuj ponownie.';

  @override
  String get purchase_restore_none =>
      'Nie znaleźliśmy zakupów do przywrócenia.';

  @override
  String get purchase_restore_success => 'Zakupy przywrócone.';

  @override
  String get purchase_blocked_other_provider =>
      'Masz już aktywną subskrypcję kupioną gdzie indziej.';

  @override
  String purchase_blocked_other_provider_until(String date) {
    return 'Masz już aktywną subskrypcję kupioną gdzie indziej — obowiązuje do $date.';
  }

  @override
  String get purchase_blocked_org_managed =>
      'Planem zarządza Twoja organizacja.';

  @override
  String get purchase_blocked_iap_disabled =>
      'Zakupy w aplikacji są chwilowo wyłączone.';

  @override
  String get purchase_blocked_pending_checkout =>
      'Masz otwartą płatność w innym miejscu. Dokończ ją albo spróbuj ponownie później.';

  @override
  String get purchase_blocked_account_inactive => 'To konto jest nieaktywne.';

  @override
  String get purchase_blocked_generic => 'Zakup nie jest teraz możliwy.';

  @override
  String get subscription_provider_label => 'Dostawca';

  @override
  String get subscription_provider_apple => 'App Store';

  @override
  String get subscription_provider_google => 'Google Play';

  @override
  String get subscription_provider_stripe => 'superwizor.ai';

  @override
  String get subscription_provider_manual => 'Plan przydzielony';

  @override
  String get subscription_manage_button => 'Zarządzaj subskrypcją';

  @override
  String get subscription_manage_stripe_note =>
      'Subskrypcją zarządzasz na swoim koncie na superwizor.ai.';

  @override
  String get subscription_manage_org_note =>
      'Planem zarządza Twoja organizacja.';

  @override
  String get subscription_grace_title => 'Problem z płatnością';

  @override
  String subscription_grace_body(String date) {
    return 'Sklep nie pobrał opłaty. Zaktualizuj metodę płatności do $date, żeby nie stracić dostępu.';
  }

  @override
  String get subscription_past_due_body =>
      'Sklep nie pobrał opłaty za subskrypcję. Nowe sesje nie będą przetwarzane, dopóki płatność się nie powiedzie.';

  @override
  String get subscription_fix_payment => 'Napraw płatność w sklepie';

  @override
  String get subscription_open_store_failed => 'Nie udało się otworzyć sklepu.';

  @override
  String get subscription_choose_plan => 'Wybierz plan';

  @override
  String get upload_offline_waiting =>
      'Brak połączenia — nagranie jest bezpieczne na urządzeniu. Prześlemy je automatycznie, gdy wróci internet';

  @override
  String get pending_uploads_phase_pending => 'W kolejce';

  @override
  String get pending_uploads_phase_resuming => 'Wznawianie przesyłania...';

  @override
  String get pending_uploads_phase_uploaded => 'Przesłano — finalizuję...';

  @override
  String get pending_uploads_phase_uploading => 'Przesyłam na serwer...';

  @override
  String get pending_uploads_quota_card_desc =>
      'Pula sesji została wyczerpana. Sesja jest bezpiecznie zapisana i zostanie przetworzona po odnowieniu planu.';

  @override
  String get pending_uploads_quota_card_title => 'Nagranie czeka na wznowienie';

  @override
  String get pending_uploads_quota_dialog_body =>
      'Twoja pula sesji w tym miesiącu została wyczerpana. Aby przetworzyć to nagranie, odwiedź platformę Superwizor w przeglądarce internetowej, aby zarządzać swoim planem.';

  @override
  String get pending_uploads_quota_dialog_title => 'Brak dostępnych sesji';

  @override
  String get pending_uploads_resending_auto_prefix =>
      'WZNAWIAM AUTOMATYCZNIE: ';

  @override
  String get pending_uploads_subtitle =>
      'Status przesyłania i przetwarzania nagrań.';

  @override
  String get pending_uploads_title => 'Kolejka sesji';

  @override
  String get profile_edit_desc =>
      'Podaj swoje imię, nazwisko i tytuł zawodowy.';

  @override
  String get profile_edit_first_name => 'Imię';

  @override
  String get profile_edit_last_name => 'Nazwisko (opcjonalne)';

  @override
  String get profile_edit_professional_title =>
      'Tytuł zawodowy (np. mgr, Psycholog)';

  @override
  String get profile_edit_title => 'Edytuj profil';

  @override
  String get profile_title_suggestion_1 => 'mgr';

  @override
  String get profile_title_suggestion_2 => 'dr';

  @override
  String get profile_title_suggestion_3 => 'dr hab';

  @override
  String get profile_title_suggestion_4 => 'prof';

  @override
  String get profile_title_suggestion_5 => 'Psycholog';

  @override
  String get profile_title_suggestion_6 => 'Psychoterapeuta';

  @override
  String get profile_title_suggestion_7 => 'Terapeuta';

  @override
  String get profile_title_suggestion_8 => 'Psychiatra';

  @override
  String get profile_title_suggestion_9 => 'Coach';

  @override
  String get quota_blocked_queue_label => 'Pakiet sesji wyczerpany';

  @override
  String recording_autopause_remaining(String time) {
    return 'Auto-pauza za $time';
  }

  @override
  String get recording_btn_back => 'Powrót';

  @override
  String get recording_button_pause => 'Pauza';

  @override
  String get recording_button_resume => 'Wznów';

  @override
  String get recording_button_start => 'Rozpocznij nagrywanie';

  @override
  String get recording_button_stop => 'Zakończ';

  @override
  String get recording_confirm_end_body =>
      'Plik audio jest zabezpieczony. Czy chcesz teraz zamknąć nagranie i przekazać je do bezpiecznej analizy?';

  @override
  String get recording_confirm_end_destructive =>
      'Usuń to nagranie bezpowrotnie';

  @override
  String get recording_confirm_end_header => 'Zakończenie i analiza sesji';

  @override
  String get recording_confirm_end_primary => 'Rozpocznij analizę sesji';

  @override
  String get recording_confirm_end_secondary => 'Wróć do nagrywania';

  @override
  String get recording_consent_grant => 'Tak, wyraził zgodę';

  @override
  String get recording_consent_missing_body =>
      'Nie odnotowano zgody klienta w systemie. Czy klient wyraził zgodę na nagrywanie i przetwarzanie danych?';

  @override
  String get recording_consent_missing_header => 'Brak zgody';

  @override
  String get recording_countdown_preparing => 'Przygotuj się…';

  @override
  String get recording_discard_confirm_action => 'Tak, skasuj bezpowrotnie';

  @override
  String get recording_discard_confirm_body =>
      'Tego nagrania nie będzie się dało odzyskać. Zostanie ono bezpowrotnie usunięte z urządzenia i nie zostanie wysłane do analizy.';

  @override
  String get recording_discard_confirm_cancel => 'Nie, wróć';

  @override
  String get recording_discard_confirm_destructive => 'Wyjdź i usuń nagranie';

  @override
  String get recording_discard_confirm_header =>
      'Czy na pewno chcesz skasować nagranie?';

  @override
  String get recording_discard_confirm_secondary => 'Wróć do nagrywania';

  @override
  String get recording_fgs_notification_body =>
      'Superwizor nagrywa sesję. Nie zamykaj aplikacji.';

  @override
  String get recording_fgs_notification_title => 'Trwa nagrywanie sesji';

  @override
  String get recording_instruction_1 =>
      'Połóż telefon na stole, między rozmówcami (50–100 cm odległości).';

  @override
  String get recording_instruction_2 =>
      'Mikrofon skieruj w stronę rozmowy, niczym go nie zasłaniaj.';

  @override
  String get recording_instruction_3 =>
      'Ciche otoczenie – zamknij okna/drzwi, wyłącz źródła hałasu.';

  @override
  String get recording_instruction_4 =>
      'Do wideokonferencji (np. Google Meet, Zoom) używaj zawsze dodatkowego urządzenia do nagrywania.';

  @override
  String get recording_instruction_5 =>
      'Nagrywanie zatrzyma się automatycznie po ustawionym czasie, a co jakiś czas dostaniesz przypomnienie (z opcjonalnym dźwiękiem) – oba dostosujesz w Ustawieniach → Nagrywanie.';

  @override
  String get recording_instruction_6 =>
      'Na iPhonie włącz na czas sesji tryb skupienia (Nie przeszkadzać) lub tryb samolotowy – przychodzące połączenie, nawet wyciszone i nieodebrane, wstrzymuje nagrywanie do końca dzwonka. W trybie samolotowym nagrywasz normalnie offline, a nagranie prześlemy automatycznie po odzyskaniu połączenia.';

  @override
  String get recording_instructions_subtitle =>
      'Dobre warunki nagrywania to lepsza jakość transkrypcji i trafniejsze wnioski AI.';

  @override
  String get recording_instructions_title =>
      'Kilka wskazówek dla lepszego nagrania';

  @override
  String get recording_interrupted_note =>
      'Wstrzymano na czas połączenia — nagrywanie wznowi się automatycznie';

  @override
  String get recording_interrupted_stuck =>
      'Nie udaje się wznowić automatycznie — możesz zakończyć sesję i wysłać dotychczasowe nagranie';

  @override
  String recording_ios_only_body_part1(String alias) {
    return 'Aby nagrać sesję z $alias, użyj aplikacji ';
  }

  @override
  String get recording_ios_only_body_part2 =>
      'Superwizor na iPhone. Po przesłaniu nagrania ';

  @override
  String get recording_ios_only_body_part3 =>
      'transkrypcja i raport pojawią się tutaj.';

  @override
  String get recording_ios_only_title => 'Nagrywanie dostępne w aplikacji iOS';

  @override
  String get recording_max_duration_body =>
      'Sesja osiągnęła maksymalny dozwolony czas 130 minut i została bezpiecznie zatrzymana. Przekaż ją teraz do analizy lub usuń, jeśli było to nagrywanie testowe.';

  @override
  String get recording_max_duration_destructive =>
      'Usuń to nagranie bezpowrotnie';

  @override
  String get recording_max_duration_header =>
      'Osiągnięto limit czasu nagrywania';

  @override
  String get recording_max_duration_primary => 'Rozpocznij analizę sesji';

  @override
  String get recording_mic_denied_body =>
      'Aby nagrywać sesję, włącz dostęp do mikrofonu w ustawieniach systemu. Przejdź do Ustawienia → Superwizor → Mikrofon.';

  @override
  String get recording_mic_denied_cancel => 'Wróć';

  @override
  String get recording_mic_denied_header => 'Brak dostępu do mikrofonu';

  @override
  String get recording_mic_denied_open_settings => 'Otwórz ustawienia';

  @override
  String get recording_mic_error_header => 'Błąd mikrofonu';

  @override
  String get recording_minimize_action => 'Zminimalizuj (zostaw w tle)';

  @override
  String get recording_minimize_confirm_body =>
      'Sesja jest w toku. Możesz zminimalizować ten ekran, aby np. przejść do notatek (nagrywanie będzie kontynuowane w tle).';

  @override
  String get recording_minimize_confirm_header => 'Wyjście z ekranu nagrywania';

  @override
  String get recording_minimize_discard => 'Zatrzymaj i skasuj nagranie';

  @override
  String get recording_minimize_resume => 'Wróć do nagrywania';

  @override
  String recording_pending_upload_body(String date) {
    return 'Sesja z dnia $date dobiła do limitu 130 minut. Nagranie jest bezpieczne na Twoim urządzeniu i czeka na przekazanie do analizy.';
  }

  @override
  String get recording_pending_upload_destructive =>
      'Usuń to nagranie bezpowrotnie';

  @override
  String get recording_pending_upload_header =>
      'Mamy Twoje niedokończone nagranie';

  @override
  String get recording_pending_upload_primary => 'Przekaż do analizy';

  @override
  String recording_reminder_toast(String duration) {
    return 'Nagrywanie wciąż trwa — $duration';
  }

  @override
  String get recording_resume_failed_body =>
      'Nie udało się wznowić nagrywania. Dotychczasowe nagranie jest bezpieczne, możesz zakończyć sesję i wysłać je do analizy.';

  @override
  String get recording_resume_failed_finish => 'Zakończ i wyślij';

  @override
  String get recording_resume_failed_header => 'Nie udało się wznowić';

  @override
  String get recording_resume_failed_retry => 'Spróbuj ponownie';

  @override
  String get recording_saving => 'Zapisuję nagranie...';

  @override
  String get recording_screen_title => 'Sesja w toku';

  @override
  String get recording_status_initializing => 'Rozpoczynam nagrywanie…';

  @override
  String get recording_status_paused => 'Nagrywanie wstrzymane';

  @override
  String get recording_status_recording => 'Nagrywanie w toku';

  @override
  String recording_too_short_abort_body(String duration) {
    return 'Nagranie trwało $duration. Anulowano wysyłkę.';
  }

  @override
  String get recording_too_short_body =>
      'Sesja nie może być krótsza niż 5 minut, aby sztuczna inteligencja mogła wyciągnąć wiarygodne wnioski. Nagrywanie trwa nadal.';

  @override
  String get recording_too_short_destructive => 'Zakończ bez zapisu';

  @override
  String get recording_too_short_header => 'Nagranie jest zbyt krótkie';

  @override
  String get recording_too_short_primary => 'Kontynuuj nagrywanie';

  @override
  String get recording_upload_error_header => 'Błąd przesyłania';

  @override
  String get recovery_delete_confirm_body =>
      'Tego nagrania nie da się odzyskać.';

  @override
  String get recovery_delete_confirm_destructive => 'Usuń';

  @override
  String get recovery_delete_confirm_header => 'Usunąć bezpowrotnie?';

  @override
  String get recovery_enqueued_snackbar => 'Nagranie dodane do kolejki wysyłki';

  @override
  String recovery_sheet_body(String patientAlias, String date, int minutes) {
    return 'Nagranie sesji z $patientAlias z $date (ok. $minutes min) nie zostało wysłane, ponieważ aplikacja została przerwana w trakcie nagrywania. Co chcesz zrobić?';
  }

  @override
  String get recovery_sheet_delete => 'Usuń nagranie';

  @override
  String get recovery_sheet_header => 'Znaleziono przerwane nagranie';

  @override
  String get recovery_unknown_patient => 'nieznaną kartoteką';

  @override
  String get recovery_pick_patient_header =>
      'Do której kartoteki wysłać nagranie?';

  @override
  String get recovery_pick_patient_none =>
      'Brak kartotek — zaloguj się online i spróbuj ponownie';

  @override
  String get recovery_sheet_later => 'Zdecyduję później';

  @override
  String get recovery_sheet_send => 'Wyślij do analizy';

  @override
  String get report_btn_copy_section => 'Kopiuj sekcję';

  @override
  String get report_btn_copy_summary => 'Kopiuj podsumowanie';

  @override
  String get report_btn_edit_section => 'Edytuj treść';

  @override
  String get report_btn_edit_summary => 'Edytuj podsumowanie';

  @override
  String get report_copy_desc => 'Skopiuj treść do schowka';

  @override
  String get report_detail_copy_content => 'Skopiuj treść';

  @override
  String get report_edit_section_desc => 'Popraw lub uzupełnij raport AI';

  @override
  String get report_edit_section_hint => 'Edytuj treść sekcji...';

  @override
  String get report_edit_section_title => 'Edycja sekcji';

  @override
  String get report_edit_summary_desc => 'Popraw lub uzupełnij podsumowanie AI';

  @override
  String get report_edit_summary_hint => 'Edytuj podsumowanie sesji...';

  @override
  String get report_edit_summary_title => 'Edycja podsumowania';

  @override
  String get report_empty_hitop => 'Brak pomiarów HiTOP w tej sesji.';

  @override
  String get report_empty_interventions =>
      'Nie zidentyfikowano interwencji terapeutycznych.';

  @override
  String get report_empty_recommendations => 'Brak rekomendacji';

  @override
  String get report_empty_themes =>
      'Nie zidentyfikowano głównych wątków w tej sesji.';

  @override
  String get report_intro_title => 'Wstęp';

  @override
  String get report_prefs_diagnostic_language_clinical_labels =>
      'Etykiety kliniczne';

  @override
  String get report_prefs_diagnostic_language_descriptive => 'Opisowy';

  @override
  String get report_prefs_diagnostic_language_dsm_icd => 'DSM / ICD';

  @override
  String get report_prefs_diagnostic_language_label => 'Język diagnostyczny';

  @override
  String get report_prefs_free_text_hint =>
      'np. Skupiaj się na obserwacjach języka ciała klienta…';

  @override
  String get report_prefs_free_text_label => 'Dodatkowe wskazówki';

  @override
  String get report_prefs_experimental_label => 'Tryb eksperymentalny';

  @override
  String get report_prefs_experimental_subtitle =>
      'Każda nowa sesja dostanie DODATKOWY raport zbudowany na ontologii, której eksperci jeszcze nie zatwierdzili. Nie służy do pracy klinicznej — powstaje obok zwykłego raportu, do porównania.';

  @override
  String get report_prefs_experimental_on => 'Włączony';

  @override
  String get report_prefs_experimental_off => 'Wyłączony';

  @override
  String get report_prefs_free_text_subtitle =>
      'Wolny tekst, max. 500 znaków. Te wskazówki AI uwzględni w każdym raporcie.';

  @override
  String get report_prefs_hypothesis_hedging_assertive => 'Asertywny';

  @override
  String get report_prefs_hypothesis_hedging_balanced => 'Wyważony';

  @override
  String get report_prefs_hypothesis_hedging_label =>
      'Stopień asertywności hipotez';

  @override
  String get report_prefs_hypothesis_hedging_tentative => 'Ostrożny';

  @override
  String get report_prefs_intro_subtitle =>
      'Dostosuj, jak AI pisze raporty z Twoich sesji.';

  @override
  String get report_prefs_intro_title => 'Styl raportów';

  @override
  String get report_prefs_length_brief => 'Krótki';

  @override
  String get report_prefs_length_detailed => 'Szczegółowy';

  @override
  String get report_prefs_length_label => 'Długość raportu';

  @override
  String get report_prefs_length_standard => 'Standardowy';

  @override
  String get report_prefs_load_error => 'Nie udało się załadować preferencji.';

  @override
  String get report_prefs_picker_title => 'Wybierz opcję';

  @override
  String get report_prefs_quote_density_few => 'Mało';

  @override
  String get report_prefs_quote_density_label => 'Liczba cytatów z sesji';

  @override
  String get report_prefs_quote_density_many => 'Dużo';

  @override
  String get report_prefs_quote_density_selective => 'Wybiórczo';

  @override
  String get report_prefs_save => 'Zapisz';

  @override
  String get report_prefs_save_error =>
      'Nie udało się zapisać preferencji. Spróbuj ponownie.';

  @override
  String get report_prefs_saved => 'Zapisano preferencje';

  @override
  String get report_prefs_section_case_formulation =>
      'Konceptualizacja przypadku';

  @override
  String get report_prefs_section_clinical_picture => 'Obraz kliniczny';

  @override
  String get report_prefs_section_cultural_context => 'Kontekst kulturowy';

  @override
  String get report_prefs_section_emphasis_label => 'Sekcje do rozwinięcia';

  @override
  String get report_prefs_section_emphasis_subtitle =>
      'Wybierz sekcje, na których AI ma się skupić.';

  @override
  String get report_prefs_section_homework_between_sessions =>
      'Zadania między sesjami';

  @override
  String get report_prefs_section_interventions => 'Interwencje';

  @override
  String get report_prefs_section_safety_and_risk => 'Bezpieczeństwo i ryzyko';

  @override
  String get report_prefs_section_supervisory_recommendations =>
      'Rekomendacje superwizyjne';

  @override
  String get report_prefs_strengths_framing_balanced => 'Wyważony';

  @override
  String get report_prefs_strengths_framing_label =>
      'Akcent na mocnych stronach';

  @override
  String get report_prefs_strengths_framing_problem_focused =>
      'Skupiony na problemach';

  @override
  String get report_prefs_strengths_framing_strengths_first =>
      'Mocne strony na pierwszym planie';

  @override
  String get report_prefs_tone_academic_rigorous => 'Akademicki, rygorystyczny';

  @override
  String get report_prefs_tone_clinical_formal => 'Kliniczny, formalny';

  @override
  String get report_prefs_tone_empathic_warm => 'Empatyczny, ciepły';

  @override
  String get report_prefs_tone_label => 'Ton';

  @override
  String get report_prefs_tone_pragmatic_direct => 'Pragmatyczny, bezpośredni';

  @override
  String get report_prefs_too_long => 'Tekst za długi (max. 500 znaków).';

  @override
  String get report_prefs_value_not_set => 'Domyślne';

  @override
  String get report_rating_chip_inaccurate_interpretation =>
      'Niedokładna interpretacja';

  @override
  String get report_rating_chip_missing_context =>
      'Brakuje kontekstu / złe akcenty';

  @override
  String get report_rating_chip_missing_strengths =>
      'Brakuje mocnych stron klienta';

  @override
  String get report_rating_chip_other => 'Inne';

  @override
  String get report_rating_chip_too_few_quotes => 'Za mało cytatów';

  @override
  String get report_rating_chip_too_long => 'Za długi';

  @override
  String get report_rating_chip_too_many_quotes => 'Za dużo cytatów';

  @override
  String get report_rating_chip_too_short => 'Za krótki';

  @override
  String get report_rating_chip_wrong_tone => 'Zły ton';

  @override
  String get report_rating_modal_subtitle =>
      'Wybierz jedną lub więcej kategorii. Pomoże nam to dostroić kolejne raporty.';

  @override
  String get report_rating_modal_title => 'Co poszło nie tak?';

  @override
  String get report_rating_notes_hint => 'Krótka notatka, max. 4000 znaków…';

  @override
  String get report_rating_notes_label => 'Dodatkowy komentarz (opcjonalnie)';

  @override
  String get report_rating_save_error =>
      'Nie udało się zapisać oceny. Spróbuj ponownie.';

  @override
  String get report_rating_saved_negative =>
      'Dzięki, uwzględnimy to przy kolejnych raportach.';

  @override
  String get report_rating_saved_positive => 'Dzięki za pozytywną ocenę.';

  @override
  String get report_rating_submit => 'Wyślij ocenę';

  @override
  String get report_rating_thumbs_down_tooltip => 'Coś jest nie tak';

  @override
  String get report_rating_thumbs_up_tooltip => 'Dobry raport';

  @override
  String get report_section_alliance => 'Sojusz terapeutyczny';

  @override
  String get report_section_hitop => 'Wymiary HiTOP';

  @override
  String get report_section_interventions => 'Zaobserwowane interwencje';

  @override
  String get report_section_recommendations => 'Rekomendacje na kolejną sesję';

  @override
  String get report_section_risk => 'Ocena ryzyka';

  @override
  String get report_section_summary => 'Podsumowanie sesji';

  @override
  String get report_section_themes => 'Główne wątki sesji';

  @override
  String get report_tab => 'Raport';

  @override
  String get report_ai_disclaimer =>
      'Raport został wygenerowany przez sztuczną inteligencję (AI) i nie stanowi porady medycznej ani diagnozy. Wymaga weryfikacji przez wykwalifikowanego specjalistę.';

  @override
  String get report_toast_reports_copied => 'Raporty skopiowane do schowka';

  @override
  String get report_toast_section_copied => 'Sekcja skopiowana do schowka';

  @override
  String get report_toast_section_updated => 'Sekcja zaktualizowana';

  @override
  String get report_toast_summary_copied => 'Podsumowanie skopiowane';

  @override
  String get report_toast_summary_updated => 'Podsumowanie zaktualizowane';

  @override
  String get report_tooltip_copy_reports => 'Skopiuj raporty';

  @override
  String get risk_level_high => 'Wysokie ryzyko';

  @override
  String get risk_level_low => 'Niskie ryzyko';

  @override
  String get risk_level_moderate => 'Umiarkowane ryzyko';

  @override
  String get risk_level_none => 'Brak sygnałów ryzyka';

  @override
  String get sessionDetails_ai_reports_soon => 'Raporty AI — wkrótce';

  @override
  String get sessionDetails_ai_reports_soon_desc =>
      'Analiza sesji i automatyczne raporty będą dostępne\nw kolejnej aktualizacji.';

  @override
  String get sessionDetails_copy_transcript => 'Skopiuj transkrypcję';

  @override
  String get sessionDetails_stat_modality => 'MODALNOŚĆ';

  @override
  String get sessionDetails_stat_sentiment => 'SENTYMENT';

  @override
  String get sessionDetails_stat_sentiment_neutral => 'Neutralny';

  @override
  String get sessionDetails_stat_sentiment_unknown => 'Nieznany';

  @override
  String get sessionDetails_stat_status => 'STATUS';

  @override
  String get sessionDetails_stat_status_new => 'Nowa';

  @override
  String get sessionDetails_stat_words => 'SŁOWA';

  @override
  String get sessionDetails_tab_analyses => 'Analizy';

  @override
  String get sessionDetails_tab_transcriptions => 'Transkrypcje';

  @override
  String get sessionDetails_toast_reports_copied =>
      'Wszystkie raporty skopiowane do schowka';

  @override
  String get sessionDetails_toast_transcript_copied =>
      'Transkrypcja skopiowana do schowka';

  @override
  String get sessionDetails_transcript_soon => 'Transkrypcja — wkrótce';

  @override
  String get sessionDetails_transcript_soon_desc =>
      'Automatyczna transkrypcja z rozpoznawaniem mówców\nbędzie dostępna w kolejnej aktualizacji.';

  @override
  String get sessionStatus_bg_processing_notice =>
      'Możesz bezpiecznie opuścić ten ekran,\nsesja przetworzy się w tle.';

  @override
  String get sessionStatus_keep_app_open =>
      'Zostaw aplikację otwartą do momentu przesłania danych na bezpieczny serwer';

  @override
  String get sessionStatus_analysis_on_server =>
      'Możesz zamknąć aplikację. Analiza trwa na naszych serwerach.';

  @override
  String sessionStatus_stalled_hint(int minutes) {
    return 'Przesyłanie czeka już $minutes min. Zostaw ten ekran otwarty, aby je dokończyć.';
  }

  @override
  String get sessionStatus_btn_delete_session => 'Usuń sesję';

  @override
  String get sessionStatus_report_failed_contact =>
      'Jeśli sytuacja się powtarza, daj nam znać.';

  @override
  String get sessionStatus_report_failed_perm =>
      'Nie udało się wygenerować raportu dla tej sesji.\n\n';

  @override
  String get sessionStatus_report_failed_retry =>
      'Spróbuj ponowić analizę za jakiś czas.';

  @override
  String get sessionStatus_report_failed_temp =>
      'Proces tworzenia raportu napotkał trudność.\n\n';

  @override
  String get sessionStatus_status_queued => 'W kolejce do przesłania';

  @override
  String get sessionStatus_status_uploading => 'Przesyłanie na serwer';

  @override
  String get sessionStatus_upload_stopped_net_err =>
      'Wystąpił problem z połączeniem sieciowym.\n\n';

  @override
  String get sessionStatus_upload_stopped_resume =>
      'System wznowi przesyłanie, gdy odzyskasz zasięg.';

  @override
  String get sessionStatus_upload_stopped_safe =>
      'Nagranie jest bezpieczne na Twoim urządzeniu. ';

  @override
  String get sessionStatus_upload_stopped_title => 'Przesyłanie zatrzymane';

  @override
  String get sessionStatus_uploading_desc =>
      'Superwizor przesyła nagranie sesji na serwer.';

  @override
  String get session_delete_error =>
      'Nie udało się usunąć sesji. Spróbuj ponownie.';

  @override
  String get session_failed_body =>
      'Coś poszło nie tak po stronie analizy. Spróbujemy ponownie automatycznie. Jeśli problem się utrzymuje, skontaktuj się z pomocą techniczną.';

  @override
  String get session_failed_header => 'Nie udało się przygotować raportu';

  @override
  String get session_failed_primary => 'Skontaktuj się z pomocą';

  @override
  String get session_failed_subscription_body =>
      'Nie mogliśmy przygotować raportu, ponieważ Twoja subskrypcja jest nieaktywna. Odnów subskrypcję, aby wznowić analizę nagranych sesji.';

  @override
  String get session_failed_subscription_title => 'Subskrypcja nieaktywna';

  @override
  String get session_load_error_body =>
      'Coś nie zadziałało po naszej stronie. Spróbuj ponownie za chwilę.';

  @override
  String get session_load_error_header => 'Nie udało się pobrać sesji';

  @override
  String get session_loading =>
      'Opracowujemy dla Ciebie raporty i transkrypcje. Możesz tutaj wrócić za chwilę.';

  @override
  String get session_name_fallback => 'Rozmowa';

  @override
  String get session_rename_error =>
      'Nie udało się zapisać tytułu na serwerze. Spróbuj ponownie.';

  @override
  String get session_status_back_to_records => 'Zamknij ekran';

  @override
  String get session_status_subtitle =>
      'Opracowujemy dla Ciebie raporty i transkrypcje. Może to potrwać 15 minut. Możesz tutaj wrócić za chwilę.';

  @override
  String get session_status_success => 'Gotowe!';

  @override
  String get session_status_title => 'Bezpieczna analiza w toku';

  @override
  String get settings_avatar => 'Zdjęcie profilowe';

  @override
  String get settings_choose_language => 'Wybierz język';

  @override
  String get settings_contact => 'Napisz do nas';

  @override
  String get settings_delete_account => 'Usuń konto bezpowrotnie';

  @override
  String get settings_delete_confirm_body =>
      'Ta operacja jest NIEODWRACALNA.\nUstracisz całą dokumentację kliniczną i dane klientów.';

  @override
  String get settings_delete_confirm_cancel => 'Anuluj, zachowaj konto';

  @override
  String get settings_delete_confirm_proceed => 'Rozumiem, przejdź dalej';

  @override
  String get settings_delete_confirm_title =>
      'Czy na pewno chcesz\nusunąć konto?';

  @override
  String get settings_dpa => 'DPA / RODO';

  @override
  String get settings_email => 'Email';

  @override
  String get settings_haptics => 'Wibracje';

  @override
  String get settings_haptics_off => 'Wibracje wyłączone';

  @override
  String get settings_haptics_on => 'Wibracje włączone';

  @override
  String get settings_language => 'Język aplikacji';

  @override
  String get settings_language_app => 'Język aplikacji';

  @override
  String get settings_live_activities => 'Aktywność na ekranie blokady';

  @override
  String get settings_live_activities_off =>
      'Status sesji widoczny tylko w aplikacji.';

  @override
  String get settings_live_activities_on =>
      'Czas i status sesji widoczne bez odblokowywania telefonu.';

  @override
  String settings_logged_in_as(String email) {
    return 'Zalogowano jako: $email';
  }

  @override
  String get settings_logout => 'Wyloguj się';

  @override
  String get settings_logout_confirm_body =>
      'Będziesz musiał zalogować się ponownie, aby uzyskać dostęp do swoich klientów.';

  @override
  String get settings_logout_confirm_cancel => 'Zostań';

  @override
  String get settings_logout_confirm_logout => 'Wyloguj się';

  @override
  String get settings_logout_confirm_title => 'Czy chcesz się wylogować?';

  @override
  String get settings_modality => 'Domyślny nurt terapii';

  @override
  String get settings_name => 'Nazwa';

  @override
  String get settings_privacy => 'Polityka Prywatności';

  @override
  String get settings_professional_title => 'Tytuł zawodowy';

  @override
  String get settings_recording_autopause => 'Automatyczna pauza';

  @override
  String settings_recording_autopause_value(int minutes) {
    return '$minutes min';
  }

  @override
  String get settings_recording_reminder => 'Przypomnienie o nagrywaniu';

  @override
  String get settings_recording_reminder_off => 'Wyłączone';

  @override
  String get settings_recording_reminder_sound => 'Dźwięk przypomnienia';

  @override
  String get settings_recording_reminder_sound_hint =>
      'Gdy przypomnienie jest włączone, odtworzy się też dźwięk (nagrywany również w sesji).';

  @override
  String get settings_recording_reminder_sound_warning =>
      'Dźwięk zostanie nagrany w sesji';

  @override
  String get settings_recording_section => 'Nagrywanie';

  @override
  String get settings_section_account => 'TWOJE KONTO';

  @override
  String get settings_section_account_management => 'ZARZĄDZANIE KONTEM';

  @override
  String get settings_section_legal => 'INFORMACJE PRAWNE';

  @override
  String get settings_section_preferences => 'PREFERENCJE';

  @override
  String get settings_section_report_preferences => 'PREFERENCJE RAPORTÓW';

  @override
  String get settings_section_support => 'WSPARCIE';

  @override
  String get settings_sounds => 'Dźwięki';

  @override
  String get settings_sounds_off => 'Dźwięki wyłączone';

  @override
  String get settings_sounds_on => 'Dźwięki włączone';

  @override
  String get settings_subtitle => 'DOSTOSUJ SWOJE DOŚWIADCZENIE';

  @override
  String get settings_terms => 'Regulamin';

  @override
  String get settings_title => 'Ustawienia';

  @override
  String get settings_waitlist => 'Lista oczekujących';

  @override
  String get setup_continue => 'Kontynuuj';

  @override
  String get setup_language_label => 'Język sesji';

  @override
  String get setup_modality_label => 'Główny nurt terapii';

  @override
  String get setup_subtitle =>
      'Powiedz nam jak pracujesz, dostosujemy do tego analizę.';

  @override
  String get setup_title => 'Konfiguracja Twojego profilu';

  @override
  String share_note_shared_at(String date) {
    return 'Udostępniono $date';
  }

  @override
  String get share_session_label => 'Udostępnij klientowi';

  @override
  String get share_shared_badge => 'Udostępniono';

  @override
  String get share_toggle_error => 'Nie udało się zmienić udostępniania.';

  @override
  String get share_toggled_off => 'Cofnięto udostępnienie';

  @override
  String get share_toggled_on => 'Udostępniono w panelu klienta.';

  @override
  String get share_with_client => 'Udostępnij w panelu klienta';

  @override
  String get share_with_client_desc =>
      'Klient zobaczy tę pozycję w swoim panelu';

  @override
  String get sort_filter_alphabetical => 'Alfabetycznie';

  @override
  String get sort_filter_alphabetical_desc => 'Nazwy kartotek od A do Z';

  @override
  String get sort_filter_clear_filters => 'Wyczyść filtry';

  @override
  String get sort_filter_header_sorting => 'SORTOWANIE';

  @override
  String get sort_filter_last_activity => 'Ostatnia aktywność';

  @override
  String get sort_filter_last_activity_desc =>
      'Klienci, z którymi ostatnio pracowałeś';

  @override
  String get sort_filter_long_unseen => 'Dawno niewidziani';

  @override
  String get sort_filter_longest_processes => 'Najdłuższe procesy';

  @override
  String get sort_filter_longest_processes_desc =>
      'Klienci z największą liczbą sesji';

  @override
  String get sort_filter_modality => 'MODALNOŚĆ';

  @override
  String get sort_filter_new_reports => 'Nowe raporty i analizy';

  @override
  String get sort_filter_no_sessions_longest_desc =>
      'Klienci z najdłuższą przerwą';

  @override
  String get sort_filter_ready_reports_desc =>
      'Gotowe raporty AI lub trwające analizy';

  @override
  String get sort_filter_show_only => 'POKAŻ TYLKO';

  @override
  String get stepper_step1_queued => 'Audio czeka w kolejce do uploadu.';

  @override
  String get stepper_step1_quota_blocked =>
      'Pakiet sesji wyczerpany. Odnów plan, aby wznowić.';

  @override
  String get stepper_step1_uploaded => 'Audio bezpieczne na naszych serwerach.';

  @override
  String get stepper_step1_uploading => 'Ładujemy audio na serwer.';

  @override
  String get stepper_step2_transcribing => 'Tworzymy transkrypcję';

  @override
  String get stepper_step3_analyzing =>
      'Sztuczna Inteligencja przygotowuje wnioski.';

  @override
  String get stepper_step4_finalizing =>
      'Składamy informacje w czytelny raport.';

  @override
  String get stepper_step5_done => 'Gotowe! Wysyłamy wnioski do Ciebie.';

  @override
  String get subscription_cycle_annual => 'roczny';

  @override
  String get subscription_cycle_monthly => 'miesięczny';

  @override
  String get subscription_cycle_semi_annual => 'półroczny';

  @override
  String get subscription_no_data_body =>
      'Nie udało się pobrać informacji o Twoim planie. Sprawdź połączenie internetowe i spróbuj ponownie.';

  @override
  String get subscription_no_data_title => 'Brak danych o subskrypcji';

  @override
  String subscription_period_ends(String date) {
    return 'Okres kończy się $date';
  }

  @override
  String get subscription_plan_section_header => 'Twój plan';

  @override
  String get subscription_refresh_cta => 'Odśwież';

  @override
  String get subscription_screen_title => 'Subskrypcja';

  @override
  String subscription_sessions_left(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sesji do końca okresu',
      many: '$n sesji do końca okresu',
      few: '$n sesje do końca okresu',
      one: '1 sesja do końca okresu',
      zero: 'Brak sesji do końca okresu',
    );
    return '$_temp0';
  }

  @override
  String subscription_sessions_per_period(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sesji w okresie',
      many: '$n sesji w okresie',
      few: '$n sesje w okresie',
      one: '1 sesja w okresie',
    );
    return '$_temp0';
  }

  @override
  String subscription_sessions_used(int used, int limit) {
    return 'Wykorzystano: $used z $limit';
  }

  @override
  String get subscription_tier_clinic => 'Klinika';

  @override
  String get subscription_tier_pro => 'Rozkwit';

  @override
  String get subscription_tier_solo => 'Równowaga';

  @override
  String get subscription_tier_trial => 'Wersja próbna';

  @override
  String get suggestion_banner_applied_toast =>
      'Zmieniono, kolejne raporty uwzględnią to ustawienie.';

  @override
  String get suggestion_banner_apply => 'Zmień';

  @override
  String get suggestion_banner_apply_error =>
      'Nie udało się zmienić ustawienia.';

  @override
  String suggestion_banner_body(
    String reason,
    int count,
    String dimension,
    String toValue,
  ) {
    return 'Ostatnie raporty oznaczyłeś jako „$reason\" ($count×). Czy zmienić $dimension na „$toValue\"?';
  }

  @override
  String suggestion_banner_body_section_emphasis(String reason, int count) {
    return 'Ostatnie raporty oznaczyłeś jako „$reason\" ($count×). Otwórz ustawienia, aby dostosować akcenty sekcji.';
  }

  @override
  String get suggestion_banner_dismiss => 'Nie teraz';

  @override
  String get suggestion_banner_header => 'Sugestia od AI';

  @override
  String get suggestion_banner_open_settings => 'Otwórz ustawienia';

  @override
  String get transcript_actions_copy => 'Kopiuj cytat';

  @override
  String get transcript_actions_copy_with_timestamp => 'Kopiuj cytat z czasem';

  @override
  String get transcript_actions_export => 'Eksportuj transkrypt do PDF';

  @override
  String get transcript_actions_play_from_here => 'Odtwórz od tego miejsca';

  @override
  String get transcript_default_speaker_label => 'Głos';

  @override
  String get transcript_export_phi_body =>
      'Dokument zawiera transkrypcję sesji terapeutycznej. Nie udostępniaj go niezaszyfrowaną pocztą ani komunikatorami bez warstwy E2E.';

  @override
  String get transcript_export_phi_header => 'Eksportujesz dane wrażliwe';

  @override
  String get transcript_export_phi_primary => 'Rozumiem, eksportuj';

  @override
  String get transcript_export_phi_secondary => 'Anuluj';

  @override
  String get transcript_filter_all => 'Wszyscy';

  @override
  String get transcript_low_confidence_tooltip =>
      'Niska pewność transkrypcji w tym fragmencie. Możesz odsłuchać aby zweryfikować.';

  @override
  String get transcript_pdf_footer =>
      'Wygenerowane przez Superwizor AI · Dokument zawiera dane wrażliwe klienta.';

  @override
  String transcript_pdf_meta_date(String date) {
    return 'Data sesji: $date';
  }

  @override
  String transcript_pdf_meta_duration(String duration) {
    return 'Czas trwania: $duration';
  }

  @override
  String transcript_pdf_meta_patient(String name) {
    return 'Klient: $name';
  }

  @override
  String get transcript_pdf_title => 'Transkrypcja sesji';

  @override
  String get transcript_remove_fillers => 'Ukryj przerywniki (yyy, eee)';

  @override
  String get transcript_search_hint => 'Szukaj w transkrypcji…';

  @override
  String get transcript_search_helper_hint =>
      'Dotknij kafelka, aby przejść do niego w pełnej transkrypcji';

  @override
  String get transcript_segment_unknown_speaker => '—';

  @override
  String get transcript_tab => 'Transkrypcja';

  @override
  String get unshare_with_client => 'Cofnij udostępnienie';

  @override
  String get upload_cancel_processing => 'Usuń';

  @override
  String get upload_resend => 'Wyślij ponownie';

  @override
  String get invite_client_confirm_title => 'Potwierdź adres e-mail';

  @override
  String get invite_client_confirm_body =>
      'Zaproszenie da dostęp do danych klinicznych tej kartoteki. Upewnij się, że adres jest poprawny:';

  @override
  String get invite_client_confirm_send => 'Wyślij zaproszenie';

  @override
  String invite_client_typo_hint(String suggestion) {
    return 'Czy na pewno? Być może chodziło o domenę: $suggestion';
  }

  @override
  String get invite_client_code_title => 'Kod dla pacjenta';

  @override
  String get invite_client_code_hint =>
      'Przekaż ten kod pacjentowi osobiście lub telefonicznie. Nie wysyłaj go e-mailem — pacjent wpisze go przy aktywacji konta.';

  @override
  String get invite_client_code_copied => 'Kod skopiowany';

  @override
  String get invite_client_revoke => 'Cofnij zaproszenie';

  @override
  String get invite_client_revoke_confirm_title => 'Cofnąć zaproszenie?';

  @override
  String get invite_client_revoke_confirm_body =>
      'Link w wysłanym e-mailu natychmiast przestanie działać. Będzie można wysłać nowe zaproszenie.';

  @override
  String get ai_chat_title => 'Superwizor AI';

  @override
  String get ai_chat_fab_label => 'Zapytaj AI';

  @override
  String get ai_chat_fab_subtitle => 'Czat z kontekstem sesji';

  @override
  String get ai_chat_input_hint => 'Zadaj pytanie o klienta...';

  @override
  String get ai_chat_loading_context => 'Przygotowuję kontekst rozmowy...';

  @override
  String get ai_chat_save_dialog_title => 'Zapisać rozmowę?';

  @override
  String get ai_chat_save_dialog_body =>
      'Czy chcesz zapisać podsumowanie tej rozmowy jako notatkę kliniczną?';

  @override
  String get ai_chat_save_yes => 'Zapisz jako notatkę';

  @override
  String get ai_chat_save_no => 'Nie zapisuj';

  @override
  String get ai_chat_save_cancel => 'Anuluj';

  @override
  String get ai_chat_saving => 'Generuję podsumowanie...';

  @override
  String get ai_chat_saved_toast => 'Notatka z rozmowy AI zapisana';

  @override
  String get ai_chat_error_init =>
      'Nie udało się zainicjalizować czatu AI. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get ai_chat_system_intro =>
      'Mam kontekst dotychczasowych sesji z tym klientem. Mogę przypomnieć szczegóły, pokazać wzorce lub pomóc przygotować się do kolejnego spotkania.';

  @override
  String get ai_chat_note_title => 'Notatka z rozmowy AI';

  @override
  String sessionDetails_experimentalSkipped_limit(String limit) {
    return 'Raport eksperymentalny pominięty: dobowy limit ($limit) został wyczerpany. Wróci przy kolejnej sesji jutro.';
  }

  @override
  String get sessionDetails_experimentalSkipped_orgDisabled =>
      'Raport eksperymentalny pominięty: tryb jest wyłączony dla Twojej organizacji. Przełącznik w ustawieniach zostaje włączony, ale nie działa, dopóki administrator go nie przywróci.';

  @override
  String get sessionDetails_experimentalSkipped_other =>
      'Raport eksperymentalny nie powstał dla tej sesji. Raport poniżej jest raportem produkcyjnym.';

  @override
  String get report_tab_production => 'Raport';

  @override
  String get report_tab_experimental => 'Eksperymentalny';

  @override
  String get pending_uploads_err_reason_file_missing =>
      'plik nagrania nie istnieje na urządzeniu';

  @override
  String get pending_uploads_file_missing_title => 'Nagranie niedostępne';

  @override
  String get pending_uploads_file_missing_desc =>
      'Plik audio tej sesji nie istnieje już na tym urządzeniu, więc przesyłanie nie może zostać wznowione. Jeśli nagranie było długie i cenne, skontaktuj się z nami — sprawdzimy, czy część danych dotarła na serwer.';

  @override
  String get report_ready_snackbar => 'Raport z sesji jest gotowy.';

  @override
  String get report_ready_snackbar_open => 'Otwórz';

  @override
  String get verify_email_title => 'Sprawdź skrzynkę';

  @override
  String verify_email_body(String email) {
    return 'Wysłaliśmy link potwierdzający na $email.';
  }

  @override
  String get verify_email_why =>
      'Kliknij link w wiadomości, a aplikacja odblokuje się sama. Jeśli adres jest błędny, wyloguj się i załóż konto ponownie.';

  @override
  String get verify_email_resend => 'Wyślij ponownie';

  @override
  String get verify_email_resent => 'Wysłaliśmy nową wiadomość.';

  @override
  String get verify_email_resend_failed =>
      'Nie udało się wysłać wiadomości. Spróbuj za chwilę.';

  @override
  String get verify_email_check_now => 'Sprawdziłem, potwierdzone';

  @override
  String get verify_email_still_unverified =>
      'Adres nadal nie jest potwierdzony.';

  @override
  String get verify_email_confirmed => 'Adres e-mail potwierdzony.';

  @override
  String get verify_email_banner_title => 'Potwierdź adres e-mail';

  @override
  String get verify_email_banner_body =>
      'Nagrania czekają lokalnie, dopóki nie potwierdzisz adresu. Nagrywanie działa normalnie.';

  @override
  String get verify_email_banner_action => 'Potwierdź';
}
