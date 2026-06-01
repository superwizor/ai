// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Superwizor AI';

  @override
  String get common_understand => 'Rozumiem.';

  @override
  String get common_back => 'Wróć.';

  @override
  String get common_cancel => 'Anuluj.';

  @override
  String get common_continue => 'Kontynuuj.';

  @override
  String get common_save => 'Zapisz.';

  @override
  String get common_retry => 'Spróbuj ponownie.';

  @override
  String get common_loading => 'Ładowanie…';

  @override
  String get common_error => 'Wystąpił błąd.';

  @override
  String get connectivity_offline_banner =>
      'Brak połączenia. Niektóre funkcje są ograniczone.';

  @override
  String get auth_login_title => 'Zaloguj się.';

  @override
  String get auth_email_label => 'Adres e-mail';

  @override
  String get auth_password_label => 'Hasło';

  @override
  String get auth_login_primary => 'Zaloguj się.';

  @override
  String get auth_register_primary => 'Załóż konto.';

  @override
  String get auth_toggle_to_register => 'Nie masz konta? Załóż.';

  @override
  String get auth_toggle_to_login => 'Masz już konto? Zaloguj się.';

  @override
  String get auth_forgot_password => 'Nie pamiętam hasła.';

  @override
  String get auth_password_reset_sent_title => 'Link do zmiany hasła wysłany.';

  @override
  String get auth_password_reset_sent_body =>
      'Wysłaliśmy link do zmiany hasła na Twój e-mail.';

  @override
  String get auth_shared_machine_warning_title =>
      'Korzystasz ze współdzielonego komputera?';

  @override
  String get auth_shared_machine_warning_body =>
      'Po zakończeniu pracy wyloguj się, aby Twoje dane sesji nie zostały dostępne dla kolejnego użytkownika tego komputera.';

  @override
  String get auth_error_invalid_credential =>
      'Niepoprawny adres e-mail lub hasło.';

  @override
  String get auth_error_email_already_in_use =>
      'Konto z tym adresem e-mail już istnieje. Zaloguj się.';

  @override
  String get auth_error_weak_password =>
      'Hasło jest zbyt krótkie. Użyj minimum 6 znaków.';

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
  String get auth_error_generic => 'Wystąpił błąd logowania. Spróbuj ponownie.';

  @override
  String get auth_sign_in_with_google => 'Kontynuuj z Google';

  @override
  String get auth_sign_in_with_apple => 'Zaloguj się z Apple';

  @override
  String get auth_or_use_email => 'Albo użyj adresu e-mail';

  @override
  String get auth_social_error =>
      'Logowanie przez konto zewnętrzne nie powiodło się. Spróbuj ponownie.';

  @override
  String get auth_social_cancelled => 'Logowanie anulowane.';

  @override
  String get setup_title => 'Konfiguracja Twojego profilu.';

  @override
  String get setup_subtitle =>
      'Powiedz nam jak pracujesz, dostosujemy do tego analizę.';

  @override
  String get setup_modality_label => 'Główny nurt terapii';

  @override
  String get setup_language_label => 'Język sesji';

  @override
  String get setup_continue => 'Kontynuuj.';

  @override
  String get language_popup_title => 'Język aplikacji.';

  @override
  String get language_popup_body =>
      'Obecnie wspieramy w pełni język polski. Przełączyliśmy Twój język docelowy na polski.';

  @override
  String get modality_integrative => 'Uniwersalny / Integracyjny';

  @override
  String get modality_cbt => 'Poznawczo-Behawioralny (CBT)';

  @override
  String get modality_psychodynamic => 'Psychodynamiczny';

  @override
  String get modality_gestalt => 'Gestalt';

  @override
  String get modality_positive => 'Pozytywny (PPT)';

  @override
  String get modality_schema => 'Terapia Schematów (ST)';

  @override
  String get modality_systemic => 'Systemowa (dla par i rodzin)';

  @override
  String get modality_eft => 'Skoncentrowana na Emocjach (EFT)';

  @override
  String get modality_coaching => 'Coaching (ICF/GROW)';

  @override
  String get modality_sheet_title => 'Wybierz swój nurt';

  @override
  String get modality_sheet_subtitle =>
      'To ustawienie wpływa na generowane raporty. Możesz je zmienić w każdej chwili.';

  @override
  String get addPatient_title => 'Nowa kartoteka';

  @override
  String get addPatient_subtitle =>
      'Uzupełnij dane klienta, aby utworzyć kartotekę.';

  @override
  String get addPatient_first_name_label => 'Imię (wymagane)';

  @override
  String get addPatient_last_name_label => 'Inicjał lub pseudonim';

  @override
  String get addPatient_email_label => 'E-mail klienta';

  @override
  String get addPatient_email_hint => 'Opcjonalnie — do przyszłych powiadomień';

  @override
  String get addPatient_modality_label => 'Nurt terapeutyczny';

  @override
  String get addPatient_language_label => 'Język raportu';

  @override
  String get addPatient_consent_label =>
      'Klient wyraził zgodę na nagrywanie i przetwarzanie danych zgodnie z Polityką Prywatności i DPA Superwizor AI.';

  @override
  String get addPatient_consent_link_label => 'Zobacz DPA.';

  @override
  String get addPatient_save_primary => 'Utwórz kartotekę';

  @override
  String get addPatient_no_consent_header => 'Brak zgody na nagrywanie.';

  @override
  String get addPatient_no_consent_body =>
      'Nie możemy rozpocząć sesji bez wyraźnej zgody pacjenta. Wymagają tego przepisy o ochronie danych.';

  @override
  String get addPatient_no_consent_primary => 'Rozumiem.';

  @override
  String get addPatient_duplicate_header => 'Taki klient już istnieje.';

  @override
  String get addPatient_duplicate_body =>
      'Masz już kartotekę z tą kombinacją imienia i pseudonimu. Dodaj inicjał lub przydomek, aby uniknąć pomyłek.';

  @override
  String get addPatient_duplicate_primary => 'Poprawię nazwę.';

  @override
  String get editPatient_title => 'Edytuj kartotekę';

  @override
  String get editPatient_save_primary => 'Zapisz zmiany';

  @override
  String get editPatient_erase_destructive => 'Usuń kartotekę bezpowrotnie';

  @override
  String get editPatient_erase_confirm_header =>
      'Całkowite usunięcie kartoteki';

  @override
  String get editPatient_erase_confirm_body =>
      'To działanie trwale usunie kartotekę klienta oraz WSZYSTKIE sesje i transkrypcje (wymóg RODO). Nie można tego cofnąć.';

  @override
  String get addSession_title => 'Nowa sesja.';

  @override
  String get addSession_subtitle => 'Wybierz nurt dla tej sesji:';

  @override
  String get home_title => 'Twoi pacjenci.';

  @override
  String get home_empty_title => 'Nie masz jeszcze żadnych pacjentów.';

  @override
  String get home_empty_body => 'Dodaj pacjenta, aby rozpocząć pierwszą sesję.';

  @override
  String get home_add_patient_fab => 'Dodaj pacjenta';

  @override
  String get patient_no_sessions => 'Brak sesji.';

  @override
  String get patient_start_session => 'Rozpocznij nagrywanie sesji.';

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
  String get recording_screen_title => 'Sesja w toku.';

  @override
  String get recording_instructions_title =>
      'Kilka wskazówek dla lepszego nagrania';

  @override
  String get recording_instructions_subtitle =>
      'Dobre warunki nagrywania to lepsza jakość transkrypcji i trafniejsze wnioski AI.';

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
  String get recording_status_recording => 'Nagrywanie w toku.';

  @override
  String get recording_status_paused => 'Nagrywanie wstrzymane.';

  @override
  String get recording_mic_denied_header => 'Brak dostępu do mikrofonu.';

  @override
  String get recording_mic_denied_body =>
      'Aby nagrywać sesję, włącz dostęp do mikrofonu w ustawieniach systemu. Przejdź do Ustawienia → Superwizor → Mikrofon.';

  @override
  String get recording_mic_denied_open_settings => 'Otwórz ustawienia.';

  @override
  String get recording_mic_denied_cancel => 'Wróć.';

  @override
  String get recording_discard_confirm_header => 'Wyjść z nagrywania?';

  @override
  String get recording_discard_confirm_body =>
      'Trwa nagrywanie sesji. Jeśli wyjdziesz, sesja zostanie usunięta bezpowrotnie.';

  @override
  String get recording_discard_confirm_destructive => 'Wyjdź i usuń nagranie.';

  @override
  String get recording_discard_confirm_secondary => 'Wróć do nagrywania.';

  @override
  String get recording_button_start => 'Rozpocznij nagrywanie.';

  @override
  String get recording_button_pause => 'Pauza.';

  @override
  String get recording_button_resume => 'Wznów.';

  @override
  String get recording_button_stop => 'Zakończ.';

  @override
  String get recording_too_short_header => 'Nagranie jest zbyt krótkie.';

  @override
  String get recording_too_short_body =>
      'Sesja nie może być krótsza niż 5 minut, aby sztuczna inteligencja mogła wyciągnąć wiarygodne wnioski. Nagrywanie trwa nadal.';

  @override
  String get recording_too_short_primary => 'Kontynuuj nagrywanie.';

  @override
  String get recording_too_short_destructive => 'Zakończ bez zapisu.';

  @override
  String get recording_confirm_end_header => 'Zakończenie i analiza sesji.';

  @override
  String get recording_confirm_end_body =>
      'Plik audio jest zabezpieczony. Czy chcesz teraz zamknąć nagranie i przekazać je do bezpiecznej analizy?';

  @override
  String get recording_confirm_end_primary => 'Rozpocznij analizę sesji.';

  @override
  String get recording_confirm_end_secondary => 'Wróć do nagrywania.';

  @override
  String get recording_confirm_end_destructive =>
      'Usuń to nagranie bezpowrotnie.';

  @override
  String get recording_max_duration_header =>
      'Osiągnięto limit czasu nagrywania.';

  @override
  String get recording_max_duration_body =>
      'Sesja osiągnęła maksymalny dozwolony czas 130 minut i została bezpiecznie zatrzymana. Przekaż ją teraz do analizy lub usuń, jeśli było to nagrywanie testowe.';

  @override
  String get recording_max_duration_primary => 'Rozpocznij analizę sesji.';

  @override
  String get recording_max_duration_destructive =>
      'Usuń to nagranie bezpowrotnie.';

  @override
  String get recording_pending_upload_header =>
      'Mamy Twoje niedokończone nagranie.';

  @override
  String recording_pending_upload_body(String date) {
    return 'Sesja z dnia $date dobiła do limitu 130 minut. Nagranie jest bezpieczne na Twoim urządzeniu i czeka na przekazanie do analizy.';
  }

  @override
  String get recording_pending_upload_primary => 'Przekaż do analizy.';

  @override
  String get recording_pending_upload_destructive =>
      'Usuń to nagranie bezpowrotnie.';

  @override
  String get stepper_step1_uploaded => 'Audio bezpieczne na naszych serwerach.';

  @override
  String get stepper_step1_queued => 'Audio czeka w kolejce do uploadu.';

  @override
  String get stepper_step2_transcribing => 'Tworzymy transkrypcję.';

  @override
  String get stepper_step3_analyzing =>
      'Sztuczna Inteligencja przygotowuje wnioski.';

  @override
  String get stepper_step4_finalizing =>
      'Składamy informacje w czytelny raport.';

  @override
  String get stepper_step5_done => 'Gotowe! Wysyłamy wnioski do Ciebie.';

  @override
  String get session_failed_header => 'Nie udało się przygotować raportu.';

  @override
  String get session_failed_body =>
      'Coś poszło nie tak po stronie analizy. Spróbujemy ponownie automatycznie. Jeśli problem się utrzymuje, skontaktuj się z pomocą techniczną.';

  @override
  String get session_failed_primary => 'Skontaktuj się z pomocą.';

  @override
  String get session_status_title => 'Bezpieczna analiza w toku.';

  @override
  String get session_status_subtitle =>
      'Opracowujemy dla Ciebie raporty i transkrypcje. Może to potrwać 15 minut. Możesz tutaj wrócić za chwilę.';

  @override
  String get session_status_success => 'Gotowe!';

  @override
  String get session_status_back_to_records => 'Wróć do kartotek';

  @override
  String get session_loading =>
      'Opracowujemy dla Ciebie raporty i transkrypcje. Możesz tutaj wrócić za chwilę.';

  @override
  String get session_load_error_header => 'Nie udało się pobrać sesji.';

  @override
  String get session_load_error_body =>
      'Coś nie zadziałało po naszej stronie. Spróbuj ponownie za chwilę.';

  @override
  String get transcript_tab => 'Transkrypcja';

  @override
  String get report_tab => 'Raport';

  @override
  String get transcript_filter_all => 'Wszyscy';

  @override
  String get transcript_search_hint => 'Szukaj w transkrypcji…';

  @override
  String get transcript_low_confidence_tooltip =>
      'Niska pewność transkrypcji w tym fragmencie. Możesz odsłuchać aby zweryfikować.';

  @override
  String get transcript_segment_unknown_speaker => '—';

  @override
  String get transcript_actions_copy => 'Kopiuj cytat.';

  @override
  String get transcript_actions_copy_with_timestamp => 'Kopiuj cytat z czasem.';

  @override
  String get transcript_actions_play_from_here => 'Odtwórz od tego miejsca.';

  @override
  String get transcript_actions_export => 'Eksportuj transkrypt do PDF.';

  @override
  String get transcript_export_phi_header => 'Eksportujesz dane wrażliwe.';

  @override
  String get transcript_export_phi_body =>
      'Dokument zawiera transkrypcję sesji terapeutycznej. Nie udostępniaj go niezaszyfrowaną pocztą ani komunikatorami bez warstwy E2E.';

  @override
  String get transcript_export_phi_primary => 'Rozumiem, eksportuj.';

  @override
  String get transcript_export_phi_secondary => 'Anuluj.';

  @override
  String get transcript_pdf_title => 'Transkrypcja sesji';

  @override
  String transcript_pdf_meta_patient(String name) {
    return 'Pacjent: $name';
  }

  @override
  String transcript_pdf_meta_date(String date) {
    return 'Data sesji: $date';
  }

  @override
  String transcript_pdf_meta_duration(String duration) {
    return 'Czas trwania: $duration';
  }

  @override
  String get transcript_pdf_footer =>
      'Wygenerowane przez Superwizor AI · Dokument zawiera dane wrażliwe pacjenta.';

  @override
  String get report_section_summary => 'Podsumowanie sesji';

  @override
  String get report_section_themes => 'Główne wątki sesji';

  @override
  String get report_section_alliance => 'Sojusz terapeutyczny';

  @override
  String get report_section_interventions => 'Zaobserwowane interwencje';

  @override
  String get report_section_hitop => 'Wymiary HiTOP';

  @override
  String get report_section_risk => 'Ocena ryzyka';

  @override
  String get report_section_recommendations => 'Rekomendacje na kolejną sesję';

  @override
  String get report_empty_themes =>
      'Nie zidentyfikowano głównych wątków w tej sesji.';

  @override
  String get report_empty_interventions =>
      'Nie zidentyfikowano interwencji terapeutycznych.';

  @override
  String get report_empty_recommendations => 'Brak rekomendacji.';

  @override
  String get report_empty_hitop => 'Brak pomiarów HiTOP w tej sesji.';

  @override
  String get risk_level_high => 'Wysokie ryzyko';

  @override
  String get risk_level_moderate => 'Umiarkowane ryzyko';

  @override
  String get risk_level_low => 'Niskie ryzyko';

  @override
  String get risk_level_none => 'Brak sygnałów ryzyka';

  @override
  String get drawer_profile => 'Mój profil';

  @override
  String get drawer_language => 'Język aplikacji';

  @override
  String get drawer_modalities => 'Nurty terapii';

  @override
  String get drawer_legal_terms => 'Regulamin';

  @override
  String get drawer_legal_dpa => 'DPA / RODO';

  @override
  String get drawer_about => 'O aplikacji';

  @override
  String get drawer_logout => 'Wyloguj.';

  @override
  String get drawer_delete_account => 'Usuń konto.';

  @override
  String get settings_title => 'Ustawienia';

  @override
  String get settings_subtitle => 'DOSTOSUJ SWOJE DOŚWIADCZENIE';

  @override
  String get settings_section_account => 'TWOJE KONTO';

  @override
  String settings_logged_in_as(String email) {
    return 'Zalogowano jako: $email';
  }

  @override
  String get settings_name => 'Nazwa';

  @override
  String get settings_email => 'Email';

  @override
  String get settings_avatar => 'Zdjęcie profilowe';

  @override
  String get settings_modality => 'Domyślny nurt terapii';

  @override
  String get settings_section_preferences => 'PREFERENCJE';

  @override
  String get settings_sounds => 'Dźwięki';

  @override
  String get settings_sounds_on => 'Dźwięki włączone';

  @override
  String get settings_sounds_off => 'Dźwięki wyłączone';

  @override
  String get settings_haptics => 'Wibracje';

  @override
  String get settings_haptics_on => 'Wibracje włączone';

  @override
  String get settings_haptics_off => 'Wibracje wyłączone';

  @override
  String get settings_language => 'Język aplikacji';

  @override
  String get settings_section_support => 'WSPARCIE';

  @override
  String get settings_contact => 'Napisz do nas';

  @override
  String get settings_waitlist => 'Lista oczekujących';

  @override
  String get settings_section_legal => 'INFORMACJE PRAWNE';

  @override
  String get settings_terms => 'Regulamin';

  @override
  String get settings_privacy => 'Polityka Prywatności';

  @override
  String get settings_dpa => 'DPA / RODO';

  @override
  String get settings_licenses => 'Licencje oprogramowania';

  @override
  String get settings_section_account_management => 'ZARZĄDZANIE KONTEM';

  @override
  String get settings_logout => 'Wyloguj się';

  @override
  String get settings_delete_account => 'Usuń konto bezpowrotnie';

  @override
  String get settings_logout_confirm_title => 'Czy chcesz się wylogować?';

  @override
  String get settings_logout_confirm_body =>
      'Będziesz musiał zalogować się ponownie, aby uzyskać dostęp do swoich pacjentów.';

  @override
  String get settings_logout_confirm_cancel => 'Zostań';

  @override
  String get settings_logout_confirm_logout => 'Wyloguj się';

  @override
  String get modality_abbr_univ => 'Integr.';

  @override
  String get modality_abbr_cbt => 'CBT';

  @override
  String get modality_abbr_psycho => 'Psychod.';

  @override
  String get modality_abbr_gestalt => 'Gestalt';

  @override
  String get modality_abbr_ppt => 'PPT';

  @override
  String get modality_abbr_st => 'ST';

  @override
  String get modality_abbr_sys => 'System.';

  @override
  String get modality_abbr_eft => 'EFT';

  @override
  String get modality_abbr_coach => 'Coaching';

  @override
  String get settings_language_app => 'Język aplikacji';

  @override
  String get settings_delete_confirm_title =>
      'Czy na pewno chcesz\nusunąć konto?';

  @override
  String get settings_delete_confirm_body =>
      'Ta operacja jest NIEODWRACALNA.\nUstracisz całą dokumentację kliniczną i dane pacjentów.';

  @override
  String get settings_delete_confirm_proceed => 'Rozumiem — przejdź dalej.';

  @override
  String get settings_delete_confirm_cancel => 'Anuluj — zachowaj konto.';

  @override
  String get settings_choose_language => 'Wybierz język';

  @override
  String get delete_account_title => 'Usuń konto';

  @override
  String get delete_account_consequence_1 =>
      'Cała dokumentacja kliniczna — wszystkich pacjentów, kartoteki, sesje i raporty AI — zostanie trwale usunięta.';

  @override
  String get delete_account_consequence_2 =>
      'Twoja subskrypcja (jeśli ją posiadasz) nie zostanie automatycznie anulowana. Musisz ją anulować osobno w App Store lub Google Play.';

  @override
  String get delete_account_consequence_3 =>
      'Nie będziesz mógł odzyskać danych po zakończeniu tego procesu. Operacja jest nieodwracalna.';

  @override
  String get delete_account_toggle_text =>
      'Rozumiem konsekwencje\ni chcę usunąć konto';

  @override
  String get delete_account_button => 'Usuń moje konto';

  @override
  String get delete_account_sheet_title => 'Ostatni krok.';

  @override
  String get delete_account_sheet_subtitle => 'Aby potwierdzić, wpisz:';

  @override
  String get delete_account_sheet_hint => 'wpisz tutaj…';

  @override
  String get delete_account_sheet_button => 'USUWAM KONTO';

  @override
  String get delete_account_sheet_cancel => 'Anuluj.';

  @override
  String get delete_account_relogin_error =>
      'Zaloguj się ponownie, by usunąć konto.';

  @override
  String get delete_account_confirm_word => 'usuwam';

  @override
  String get settings_licenses_desc =>
      'Ta aplikacja została zbudowana dzięki pracy tysięcy programistów z całego świata. Poniżej znajdziesz informacje o oprogramowaniu open-source, z którego korzystamy, by dostarczyć Ci najwyższą jakość działania.';

  @override
  String get report_rating_thumbs_up_tooltip => 'Dobry raport';

  @override
  String get report_rating_thumbs_down_tooltip => 'Coś jest nie tak';

  @override
  String get report_rating_saved_positive => 'Dzięki za pozytywną ocenę.';

  @override
  String get report_rating_saved_negative =>
      'Dzięki — uwzględnimy to przy kolejnych raportach.';

  @override
  String get report_rating_save_error =>
      'Nie udało się zapisać oceny. Spróbuj ponownie.';

  @override
  String get report_rating_modal_title => 'Co poszło nie tak?';

  @override
  String get report_rating_modal_subtitle =>
      'Wybierz jedną lub więcej kategorii. Pomoże nam to dostroić kolejne raporty.';

  @override
  String get report_rating_notes_label => 'Dodatkowy komentarz (opcjonalnie)';

  @override
  String get report_rating_notes_hint => 'Krótka notatka, max. 200 znaków…';

  @override
  String get report_rating_submit => 'Wyślij ocenę';

  @override
  String get report_rating_chip_too_long => 'Za długi';

  @override
  String get report_rating_chip_too_short => 'Za krótki';

  @override
  String get report_rating_chip_wrong_tone => 'Zły ton';

  @override
  String get report_rating_chip_too_many_quotes => 'Za dużo cytatów';

  @override
  String get report_rating_chip_too_few_quotes => 'Za mało cytatów';

  @override
  String get report_rating_chip_inaccurate_interpretation =>
      'Niedokładna interpretacja';

  @override
  String get report_rating_chip_missing_strengths =>
      'Brakuje mocnych stron pacjenta';

  @override
  String get report_rating_chip_missing_context =>
      'Brakuje kontekstu / złe akcenty';

  @override
  String get report_rating_chip_other => 'Inne';

  @override
  String get settings_section_report_preferences => 'PREFERENCJE RAPORTÓW';

  @override
  String get report_prefs_intro_title => 'Styl raportów';

  @override
  String get report_prefs_intro_subtitle =>
      'Dostosuj, jak AI pisze raporty z Twoich sesji.';

  @override
  String get report_prefs_load_error => 'Nie udało się załadować preferencji.';

  @override
  String get report_prefs_save_error =>
      'Nie udało się zapisać preferencji. Spróbuj ponownie.';

  @override
  String get report_prefs_saved => 'Zapisano preferencje.';

  @override
  String get report_prefs_length_label => 'Długość raportu';

  @override
  String get report_prefs_length_brief => 'Krótki';

  @override
  String get report_prefs_length_standard => 'Standardowy';

  @override
  String get report_prefs_length_detailed => 'Szczegółowy';

  @override
  String get report_prefs_tone_label => 'Ton';

  @override
  String get report_prefs_tone_clinical_formal => 'Kliniczny, formalny';

  @override
  String get report_prefs_tone_empathic_warm => 'Empatyczny, ciepły';

  @override
  String get report_prefs_tone_pragmatic_direct => 'Pragmatyczny, bezpośredni';

  @override
  String get report_prefs_tone_academic_rigorous => 'Akademicki, rygorystyczny';

  @override
  String get report_prefs_quote_density_label => 'Liczba cytatów z sesji';

  @override
  String get report_prefs_quote_density_few => 'Mało';

  @override
  String get report_prefs_quote_density_selective => 'Wybiórczo';

  @override
  String get report_prefs_quote_density_many => 'Dużo';

  @override
  String get report_prefs_diagnostic_language_label => 'Język diagnostyczny';

  @override
  String get report_prefs_diagnostic_language_descriptive => 'Opisowy';

  @override
  String get report_prefs_diagnostic_language_clinical_labels =>
      'Etykiety kliniczne';

  @override
  String get report_prefs_diagnostic_language_dsm_icd => 'DSM / ICD';

  @override
  String get report_prefs_hypothesis_hedging_label =>
      'Stopień asertywności hipotez';

  @override
  String get report_prefs_hypothesis_hedging_tentative => 'Ostrożny';

  @override
  String get report_prefs_hypothesis_hedging_balanced => 'Wyważony';

  @override
  String get report_prefs_hypothesis_hedging_assertive => 'Asertywny';

  @override
  String get report_prefs_section_emphasis_label => 'Sekcje do rozwinięcia';

  @override
  String get report_prefs_section_emphasis_subtitle =>
      'Wybierz sekcje, na których AI ma się skupić.';

  @override
  String get report_prefs_section_clinical_picture => 'Obraz kliniczny';

  @override
  String get report_prefs_section_interventions => 'Interwencje';

  @override
  String get report_prefs_section_case_formulation =>
      'Konceptualizacja przypadku';

  @override
  String get report_prefs_section_supervisory_recommendations =>
      'Rekomendacje superwizyjne';

  @override
  String get report_prefs_section_homework_between_sessions =>
      'Zadania między sesjami';

  @override
  String get report_prefs_section_cultural_context => 'Kontekst kulturowy';

  @override
  String get report_prefs_section_safety_and_risk => 'Bezpieczeństwo i ryzyko';

  @override
  String get report_prefs_strengths_framing_label =>
      'Akcent na mocnych stronach';

  @override
  String get report_prefs_strengths_framing_problem_focused =>
      'Skupiony na problemach';

  @override
  String get report_prefs_strengths_framing_balanced => 'Wyważony';

  @override
  String get report_prefs_strengths_framing_strengths_first =>
      'Mocne strony na pierwszym planie';

  @override
  String get report_prefs_free_text_label => 'Dodatkowe wskazówki';

  @override
  String get report_prefs_free_text_subtitle =>
      'Wolny tekst, max. 500 znaków. Te wskazówki AI uwzględni w każdym raporcie.';

  @override
  String get report_prefs_free_text_hint =>
      'np. Skupiaj się na obserwacjach języka ciała pacjenta…';

  @override
  String get report_prefs_value_not_set => 'Domyślne';

  @override
  String get report_prefs_picker_title => 'Wybierz opcję';

  @override
  String get report_prefs_save => 'Zapisz';

  @override
  String get report_prefs_too_long => 'Tekst za długi (max. 500 znaków).';

  @override
  String get suggestion_banner_header => 'Sugestia od AI';

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
  String get suggestion_banner_apply => 'Zmień';

  @override
  String get suggestion_banner_open_settings => 'Otwórz ustawienia';

  @override
  String get suggestion_banner_dismiss => 'Nie teraz';

  @override
  String get suggestion_banner_applied_toast =>
      'Zmieniono — kolejne raporty uwzględnią to ustawienie.';

  @override
  String get suggestion_banner_apply_error =>
      'Nie udało się zmienić ustawienia.';

  @override
  String billing_quota_warning_short(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Zostało Ci $n tokenów.',
      many: 'Zostało Ci $n tokenów.',
      few: 'Zostały Ci $n tokeny.',
      one: 'Został Ci 1 token.',
    );
    return '$_temp0';
  }

  @override
  String get billing_quota_critical_short => 'Został Ci ostatni token.';

  @override
  String get billing_quota_exhausted_short => 'Pula tokenów wyczerpana.';

  @override
  String get billing_quota_exhausted_subtitle =>
      'Nowe sesje zapiszą się lokalnie do dnia odnowienia.';

  @override
  String billing_period_end_label(String date) {
    return 'Pula odnawia się $date.';
  }

  @override
  String get billing_expand_plan_cta => 'Rozszerz plan';

  @override
  String get billing_dismiss_cta => 'Rozumiem, kontynuuj';

  @override
  String get billing_exhausted_dialog_title => 'Pula tokenów wyczerpana';

  @override
  String get billing_exhausted_dialog_body =>
      'Możesz nadal nagrywać sesję — audio zostanie bezpiecznie zaszyfrowane i zapisane lokalnie na Twoim urządzeniu. Po rozszerzeniu planu lub odnowieniu puli możesz wznowić przetwarzanie sesji z poziomu Kartoteki.';

  @override
  String get billing_exhausted_dialog_record_locally => 'Nagrywaj lokalnie';

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
  String get billing_pending_session_subtitle =>
      'Audio zapisane lokalnie · Czeka na tokeny';

  @override
  String billing_pending_session_card_meta(
    String date,
    String time,
    int duration,
  ) {
    return 'Sesja z $date, $time ($duration min)';
  }

  @override
  String get billing_resume_processing => 'Wznów przetwarzanie';

  @override
  String get billing_delete_local_audio => 'Usuń';

  @override
  String billing_tokens_available_required(int available, int required) {
    return 'Tokeny dostępne: $available / Wymagane: $required';
  }

  @override
  String get billing_delete_confirm_title => 'Usunąć nagranie sesji?';

  @override
  String get billing_delete_confirm_body =>
      'Audio zostanie trwale usunięte z tego urządzenia. Tej operacji nie można cofnąć.';

  @override
  String get billing_delete_confirm_action => 'Usuń trwale';

  @override
  String get billing_reservation_expired_title =>
      'Przetwarzanie nie powiodło się';

  @override
  String get billing_reservation_expired_body =>
      'Rezerwacja tokena wygasła po 4 godzinach. Audio jest nadal zapisane lokalnie.';

  @override
  String get billing_retry_cta => 'Spróbuj ponownie';

  @override
  String get billing_past_due_title => 'Problem z płatnością';

  @override
  String get billing_past_due_body =>
      'Nie udało się pobrać opłaty za subskrypcję. Do czasu rozwiązania problemu nie będziemy przetwarzać nowych sesji.';

  @override
  String get subscription_screen_title => 'Subskrypcja';

  @override
  String get subscription_plan_section_header => 'Twój plan';

  @override
  String get subscription_tier_solo => 'Solo';

  @override
  String get subscription_tier_pro => 'Pro';

  @override
  String get subscription_tier_clinic => 'Klinika';

  @override
  String get subscription_tier_trial => 'Wersja próbna';

  @override
  String get subscription_cycle_monthly => 'miesięczny';

  @override
  String get subscription_cycle_semi_annual => 'półroczny';

  @override
  String get subscription_cycle_annual => 'roczny';

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
  String subscription_sessions_used(int used, int limit) {
    return 'Wykorzystano: $used z $limit';
  }

  @override
  String subscription_period_ends(String date) {
    return 'Okres kończy się $date';
  }

  @override
  String get subscription_no_data_title => 'Brak danych o subskrypcji';

  @override
  String get subscription_no_data_body =>
      'Nie udało się pobrać informacji o Twoim planie. Sprawdź połączenie internetowe i spróbuj ponownie.';

  @override
  String get subscription_refresh_cta => 'Odśwież';

  @override
  String get stepper_step1_quota_blocked =>
      'Pula tokenów wyczerpana. Odnów plan, aby wznowić.';

  @override
  String get quota_blocked_queue_label => 'Pula tokenów wyczerpana';

  @override
  String get upload_resend => 'Wyślij ponownie';

  @override
  String get upload_cancel_processing => 'Usuń';

  @override
  String get cancel_session_confirm_title => 'Anulować przetwarzanie?';

  @override
  String get cancel_session_confirm_body =>
      'Sesja zostanie anulowana, a nagranie usunięte z kolejki. Tej operacji nie można cofnąć.';

  @override
  String get cancel_session_confirm_action => 'Tak, usuń';

  @override
  String get cancel_session_keep => 'Nie, zostaw';

  @override
  String get cancel_session_success => 'Sesja anulowana';

  @override
  String get note_add_label => 'DODAJ NOTATKĘ';

  @override
  String get note_add_subtitle => 'Szybka notatka o kliencie';

  @override
  String get note_sheet_title => 'Nowa notatka';

  @override
  String get note_sheet_hint => 'Wpisz swoją notatkę…';

  @override
  String get note_sheet_save => 'Zapisz';

  @override
  String get note_sheet_cancel => 'Anuluj';

  @override
  String get note_delete_confirm => 'Usunąć notatkę?';

  @override
  String get note_delete_action => 'Usuń';

  @override
  String get note_empty_text => 'Notatka nie może być pusta.';

  @override
  String get note_title_hint => 'Tytuł notatki';

  @override
  String get note_body_hint => 'Treść notatki…';

  @override
  String get note_discard_title => 'Odrzucić zmiany?';

  @override
  String get note_discard_body =>
      'Masz niezapisane zmiany. Chcesz je odrzucić?';

  @override
  String get note_discard_action => 'Odrzuć';

  @override
  String get note_discard_save => 'Zapisz';

  @override
  String get note_edit_label => 'Edytuj notatkę';

  @override
  String get note_untitled => 'Bez tytułu';

  @override
  String get note_saved => 'Notatka zapisana ✓';

  @override
  String get note_deleted => 'Notatka usunięta';

  @override
  String get action_plan_send_button => 'Wyślij plan działania do pacjenta';

  @override
  String get action_plan_save_only => 'Zapisz';

  @override
  String get action_plan_save_and_send => 'Zapisz i wyślij';

  @override
  String get action_plan_no_email_title => 'Brak adresu e-mail';

  @override
  String get action_plan_no_email_body =>
      'Nie można wysłać planu — pacjent nie ma zdefiniowanego adresu e-mail. Uzupełnij e-mail w kartotece.';

  @override
  String get action_plan_send_confirm_title => 'Wyślij plan działania?';

  @override
  String action_plan_send_confirm_body(String email) {
    return 'Plan zostanie wysłany na adres: $email';
  }

  @override
  String get action_plan_send_sim_caption =>
      '(symulacja — wysyłka e-mail zostanie podłączona do backendu)';

  @override
  String get action_plan_send_cancel => 'Anuluj';

  @override
  String get action_plan_send_confirm_action => 'Wyślij';

  @override
  String get action_plan_sent_toast =>
      'Plan działania zapisany i wysłany (symulacja)';

  @override
  String get action_plan_default_title => 'Plan działania';

  @override
  String get action_plan_fill_email_hint =>
      'Wypełnij adres e-mail klienta i ponów wysyłkę.';
}
