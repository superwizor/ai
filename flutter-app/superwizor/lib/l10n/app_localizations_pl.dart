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
  String get addPatient_title => 'Nowy pacjent.';

  @override
  String get addPatient_first_name_label => 'Imię pacjenta (wymagane)';

  @override
  String get addPatient_last_name_label => 'Nazwisko (opcjonalne)';

  @override
  String get addPatient_modality_label => 'Nurt sesji (dziedziczony z profilu)';

  @override
  String get addPatient_language_label => 'Język sesji';

  @override
  String get addPatient_consent_label =>
      'Oświadczam, że pacjent wyraził zgodę na nagrywanie i przetwarzanie danych zgodnie z Polityką Prywatności i DPA Superwizor AI.';

  @override
  String get addPatient_consent_link_label => 'Zobacz dokument DPA.';

  @override
  String get addPatient_save_primary => 'Zapisz pacjenta.';

  @override
  String get addPatient_no_consent_header => 'Brak zgody na nagrywanie.';

  @override
  String get addPatient_no_consent_body =>
      'Nie możemy rozpocząć sesji bez wyraźnej zgody pacjenta. Wymagają tego przepisy o ochronie danych.';

  @override
  String get addPatient_no_consent_primary => 'Rozumiem.';

  @override
  String get editPatient_title => 'Edycja danych pacjenta.';

  @override
  String get editPatient_save_primary => 'Zapisz zmiany.';

  @override
  String get editPatient_erase_destructive => 'Usuń pacjenta bezpowrotnie';

  @override
  String get editPatient_erase_confirm_header =>
      'Całkowite usunięcie kartoteki';

  @override
  String get editPatient_erase_confirm_body =>
      'To działanie trwale usunie pacjenta oraz WSZYSTKIE jego sesje i transkrypcje (wymóg RODO). Nie można tego cofnąć.';

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
  String get recording_instructions_title => 'Jak najlepiej nagrywać?';

  @override
  String get recording_instruction_1 => 'Nie blokuj ekranu podczas nagrywania.';

  @override
  String get recording_instruction_2 =>
      'Połóż telefon na stole, między rozmówcami (50–100 cm odległości).';

  @override
  String get recording_instruction_3 =>
      'Mikrofon skieruj w stronę rozmowy, niczym go nie zasłaniaj.';

  @override
  String get recording_instruction_4 =>
      'Ciche otoczenie – zamknij okna/drzwi, wyłącz źródła hałasu.';

  @override
  String get recording_instruction_5 =>
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
}
