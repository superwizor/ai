import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('pl')];

  /// App display name
  ///
  /// In pl, this message translates to:
  /// **'Superwizor AI'**
  String get appTitle;

  /// No description provided for @common_understand.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem.'**
  String get common_understand;

  /// No description provided for @common_back.
  ///
  /// In pl, this message translates to:
  /// **'Wróć.'**
  String get common_back;

  /// No description provided for @common_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj.'**
  String get common_cancel;

  /// No description provided for @common_continue.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj.'**
  String get common_continue;

  /// No description provided for @common_save.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz.'**
  String get common_save;

  /// No description provided for @common_retry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie.'**
  String get common_retry;

  /// No description provided for @common_loading.
  ///
  /// In pl, this message translates to:
  /// **'Ładowanie…'**
  String get common_loading;

  /// No description provided for @connectivity_offline_banner.
  ///
  /// In pl, this message translates to:
  /// **'Brak połączenia. Niektóre funkcje są ograniczone.'**
  String get connectivity_offline_banner;

  /// No description provided for @auth_login_title.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się.'**
  String get auth_login_title;

  /// No description provided for @auth_email_label.
  ///
  /// In pl, this message translates to:
  /// **'Adres e-mail'**
  String get auth_email_label;

  /// No description provided for @auth_password_label.
  ///
  /// In pl, this message translates to:
  /// **'Hasło'**
  String get auth_password_label;

  /// No description provided for @auth_login_primary.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się.'**
  String get auth_login_primary;

  /// No description provided for @auth_register_primary.
  ///
  /// In pl, this message translates to:
  /// **'Załóż konto.'**
  String get auth_register_primary;

  /// No description provided for @auth_toggle_to_register.
  ///
  /// In pl, this message translates to:
  /// **'Nie masz konta? Załóż.'**
  String get auth_toggle_to_register;

  /// No description provided for @auth_toggle_to_login.
  ///
  /// In pl, this message translates to:
  /// **'Masz już konto? Zaloguj się.'**
  String get auth_toggle_to_login;

  /// No description provided for @auth_forgot_password.
  ///
  /// In pl, this message translates to:
  /// **'Nie pamiętam hasła.'**
  String get auth_forgot_password;

  /// No description provided for @auth_password_reset_sent_title.
  ///
  /// In pl, this message translates to:
  /// **'Link do zmiany hasła wysłany.'**
  String get auth_password_reset_sent_title;

  /// No description provided for @auth_password_reset_sent_body.
  ///
  /// In pl, this message translates to:
  /// **'Wysłaliśmy link do zmiany hasła na Twój e-mail.'**
  String get auth_password_reset_sent_body;

  /// No description provided for @auth_error_invalid_credential.
  ///
  /// In pl, this message translates to:
  /// **'Niepoprawny adres e-mail lub hasło.'**
  String get auth_error_invalid_credential;

  /// No description provided for @auth_error_email_already_in_use.
  ///
  /// In pl, this message translates to:
  /// **'Konto z tym adresem e-mail już istnieje. Zaloguj się.'**
  String get auth_error_email_already_in_use;

  /// No description provided for @auth_error_weak_password.
  ///
  /// In pl, this message translates to:
  /// **'Hasło jest zbyt krótkie. Użyj minimum 6 znaków.'**
  String get auth_error_weak_password;

  /// No description provided for @auth_error_invalid_email.
  ///
  /// In pl, this message translates to:
  /// **'Niepoprawny format adresu e-mail.'**
  String get auth_error_invalid_email;

  /// No description provided for @auth_error_network.
  ///
  /// In pl, this message translates to:
  /// **'Brak połączenia z internetem. Spróbuj ponownie.'**
  String get auth_error_network;

  /// No description provided for @auth_error_too_many_requests.
  ///
  /// In pl, this message translates to:
  /// **'Zbyt wiele prób logowania. Poczekaj chwilę i spróbuj ponownie.'**
  String get auth_error_too_many_requests;

  /// No description provided for @auth_error_user_disabled.
  ///
  /// In pl, this message translates to:
  /// **'To konto zostało wyłączone. Skontaktuj się z pomocą.'**
  String get auth_error_user_disabled;

  /// No description provided for @auth_error_generic.
  ///
  /// In pl, this message translates to:
  /// **'Wystąpił błąd logowania. Spróbuj ponownie.'**
  String get auth_error_generic;

  /// No description provided for @setup_title.
  ///
  /// In pl, this message translates to:
  /// **'Konfiguracja Twojego profilu.'**
  String get setup_title;

  /// No description provided for @setup_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Powiedz nam jak pracujesz, dostosujemy do tego analizę.'**
  String get setup_subtitle;

  /// No description provided for @setup_modality_label.
  ///
  /// In pl, this message translates to:
  /// **'Główny nurt terapii'**
  String get setup_modality_label;

  /// No description provided for @setup_language_label.
  ///
  /// In pl, this message translates to:
  /// **'Język sesji'**
  String get setup_language_label;

  /// No description provided for @setup_continue.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj.'**
  String get setup_continue;

  /// No description provided for @language_popup_title.
  ///
  /// In pl, this message translates to:
  /// **'Język aplikacji.'**
  String get language_popup_title;

  /// No description provided for @language_popup_body.
  ///
  /// In pl, this message translates to:
  /// **'Obecnie wspieramy w pełni język polski. Przełączyliśmy Twój język docelowy na polski.'**
  String get language_popup_body;

  /// No description provided for @modality_integrative.
  ///
  /// In pl, this message translates to:
  /// **'Uniwersalny / Integracyjny'**
  String get modality_integrative;

  /// No description provided for @modality_cbt.
  ///
  /// In pl, this message translates to:
  /// **'Poznawczo-Behawioralny (CBT)'**
  String get modality_cbt;

  /// No description provided for @modality_psychodynamic.
  ///
  /// In pl, this message translates to:
  /// **'Psychodynamiczny'**
  String get modality_psychodynamic;

  /// No description provided for @modality_positive.
  ///
  /// In pl, this message translates to:
  /// **'Pozytywny (PPT)'**
  String get modality_positive;

  /// No description provided for @modality_schema.
  ///
  /// In pl, this message translates to:
  /// **'Terapia Schematów (ST)'**
  String get modality_schema;

  /// No description provided for @modality_systemic.
  ///
  /// In pl, this message translates to:
  /// **'Systemowa (dla par i rodzin)'**
  String get modality_systemic;

  /// No description provided for @modality_eft.
  ///
  /// In pl, this message translates to:
  /// **'Skoncentrowana na Emocjach (EFT)'**
  String get modality_eft;

  /// No description provided for @modality_coaching.
  ///
  /// In pl, this message translates to:
  /// **'Coaching (ICF/GROW)'**
  String get modality_coaching;

  /// No description provided for @addPatient_title.
  ///
  /// In pl, this message translates to:
  /// **'Nowy pacjent.'**
  String get addPatient_title;

  /// No description provided for @addPatient_alias_label.
  ///
  /// In pl, this message translates to:
  /// **'Imię lub pseudonim pacjenta'**
  String get addPatient_alias_label;

  /// No description provided for @addPatient_modality_label.
  ///
  /// In pl, this message translates to:
  /// **'Nurt sesji (dziedziczony z profilu)'**
  String get addPatient_modality_label;

  /// No description provided for @addPatient_language_label.
  ///
  /// In pl, this message translates to:
  /// **'Język sesji'**
  String get addPatient_language_label;

  /// No description provided for @addPatient_consent_label.
  ///
  /// In pl, this message translates to:
  /// **'Oświadczam, że pacjent wyraził zgodę na nagrywanie i przetwarzanie danych zgodnie z Polityką Prywatności i DPA Superwizor AI.'**
  String get addPatient_consent_label;

  /// No description provided for @addPatient_consent_link_label.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz dokument DPA.'**
  String get addPatient_consent_link_label;

  /// No description provided for @addPatient_save_primary.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz pacjenta.'**
  String get addPatient_save_primary;

  /// No description provided for @addPatient_no_consent_header.
  ///
  /// In pl, this message translates to:
  /// **'Brak zgody na nagrywanie.'**
  String get addPatient_no_consent_header;

  /// No description provided for @addPatient_no_consent_body.
  ///
  /// In pl, this message translates to:
  /// **'Nie możemy rozpocząć sesji bez wyraźnej zgody pacjenta. Wymagają tego przepisy o ochronie danych.'**
  String get addPatient_no_consent_body;

  /// No description provided for @addPatient_no_consent_primary.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem.'**
  String get addPatient_no_consent_primary;

  /// No description provided for @home_title.
  ///
  /// In pl, this message translates to:
  /// **'Twoi pacjenci.'**
  String get home_title;

  /// No description provided for @home_empty_title.
  ///
  /// In pl, this message translates to:
  /// **'Nie masz jeszcze żadnych pacjentów.'**
  String get home_empty_title;

  /// No description provided for @home_empty_body.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj pacjenta, aby rozpocząć pierwszą sesję.'**
  String get home_empty_body;

  /// No description provided for @home_add_patient_fab.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj pacjenta'**
  String get home_add_patient_fab;

  /// No description provided for @patient_no_sessions.
  ///
  /// In pl, this message translates to:
  /// **'Brak sesji.'**
  String get patient_no_sessions;

  /// No description provided for @patient_start_session.
  ///
  /// In pl, this message translates to:
  /// **'Rozpocznij nagrywanie sesji.'**
  String get patient_start_session;

  /// No description provided for @patient_session_count.
  ///
  /// In pl, this message translates to:
  /// **'{count, plural, =0{Brak sesji} =1{1 sesja} few{{count} sesje} many{{count} sesji} other{{count} sesji}}'**
  String patient_session_count(int count);

  /// No description provided for @recording_screen_title.
  ///
  /// In pl, this message translates to:
  /// **'Sesja w toku.'**
  String get recording_screen_title;

  /// No description provided for @recording_instructions_title.
  ///
  /// In pl, this message translates to:
  /// **'Jak najlepiej nagrywać?'**
  String get recording_instructions_title;

  /// No description provided for @recording_instruction_1.
  ///
  /// In pl, this message translates to:
  /// **'Nie blokuj ekranu podczas nagrywania.'**
  String get recording_instruction_1;

  /// No description provided for @recording_instruction_2.
  ///
  /// In pl, this message translates to:
  /// **'Połóż telefon na stole, między rozmówcami (50–100 cm odległości).'**
  String get recording_instruction_2;

  /// No description provided for @recording_instruction_3.
  ///
  /// In pl, this message translates to:
  /// **'Mikrofon skieruj w stronę rozmowy, niczym go nie zasłaniaj.'**
  String get recording_instruction_3;

  /// No description provided for @recording_instruction_4.
  ///
  /// In pl, this message translates to:
  /// **'Ciche otoczenie – zamknij okna/drzwi, wyłącz źródła hałasu.'**
  String get recording_instruction_4;

  /// No description provided for @recording_instruction_5.
  ///
  /// In pl, this message translates to:
  /// **'Do wideokonferencji (np. Google Meet, Zoom) używaj zawsze dodatkowego urządzenia do nagrywania.'**
  String get recording_instruction_5;

  /// No description provided for @recording_status_recording.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywanie w toku.'**
  String get recording_status_recording;

  /// No description provided for @recording_status_paused.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywanie wstrzymane.'**
  String get recording_status_paused;

  /// No description provided for @recording_mic_denied_header.
  ///
  /// In pl, this message translates to:
  /// **'Brak dostępu do mikrofonu.'**
  String get recording_mic_denied_header;

  /// No description provided for @recording_mic_denied_body.
  ///
  /// In pl, this message translates to:
  /// **'Aby nagrywać sesję, włącz dostęp do mikrofonu w ustawieniach systemu. Przejdź do Ustawienia → Superwizor → Mikrofon.'**
  String get recording_mic_denied_body;

  /// No description provided for @recording_mic_denied_open_settings.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz ustawienia.'**
  String get recording_mic_denied_open_settings;

  /// No description provided for @recording_mic_denied_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Wróć.'**
  String get recording_mic_denied_cancel;

  /// No description provided for @recording_discard_confirm_header.
  ///
  /// In pl, this message translates to:
  /// **'Wyjść z nagrywania?'**
  String get recording_discard_confirm_header;

  /// No description provided for @recording_discard_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Trwa nagrywanie sesji. Jeśli wyjdziesz, sesja zostanie usunięta bezpowrotnie.'**
  String get recording_discard_confirm_body;

  /// No description provided for @recording_discard_confirm_destructive.
  ///
  /// In pl, this message translates to:
  /// **'Wyjdź i usuń nagranie.'**
  String get recording_discard_confirm_destructive;

  /// No description provided for @recording_discard_confirm_secondary.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do nagrywania.'**
  String get recording_discard_confirm_secondary;

  /// No description provided for @recording_button_start.
  ///
  /// In pl, this message translates to:
  /// **'Rozpocznij nagrywanie.'**
  String get recording_button_start;

  /// No description provided for @recording_button_pause.
  ///
  /// In pl, this message translates to:
  /// **'Pauza.'**
  String get recording_button_pause;

  /// No description provided for @recording_button_resume.
  ///
  /// In pl, this message translates to:
  /// **'Wznów.'**
  String get recording_button_resume;

  /// No description provided for @recording_button_stop.
  ///
  /// In pl, this message translates to:
  /// **'Zakończ.'**
  String get recording_button_stop;

  /// No description provided for @recording_too_short_header.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie jest zbyt krótkie.'**
  String get recording_too_short_header;

  /// No description provided for @recording_too_short_body.
  ///
  /// In pl, this message translates to:
  /// **'Sesja nie może być krótsza niż 5 minut, aby sztuczna inteligencja mogła wyciągnąć wiarygodne wnioski. Nagrywanie trwa nadal.'**
  String get recording_too_short_body;

  /// No description provided for @recording_too_short_primary.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj nagrywanie.'**
  String get recording_too_short_primary;

  /// No description provided for @recording_too_short_destructive.
  ///
  /// In pl, this message translates to:
  /// **'Zakończ bez zapisu.'**
  String get recording_too_short_destructive;

  /// No description provided for @recording_confirm_end_header.
  ///
  /// In pl, this message translates to:
  /// **'Zakończenie i analiza sesji.'**
  String get recording_confirm_end_header;

  /// No description provided for @recording_confirm_end_body.
  ///
  /// In pl, this message translates to:
  /// **'Plik audio jest zabezpieczony. Czy chcesz teraz zamknąć nagranie i przekazać je do bezpiecznej analizy?'**
  String get recording_confirm_end_body;

  /// No description provided for @recording_confirm_end_primary.
  ///
  /// In pl, this message translates to:
  /// **'Rozpocznij analizę sesji.'**
  String get recording_confirm_end_primary;

  /// No description provided for @recording_confirm_end_secondary.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do nagrywania.'**
  String get recording_confirm_end_secondary;

  /// No description provided for @recording_confirm_end_destructive.
  ///
  /// In pl, this message translates to:
  /// **'Usuń to nagranie bezpowrotnie.'**
  String get recording_confirm_end_destructive;

  /// No description provided for @recording_max_duration_header.
  ///
  /// In pl, this message translates to:
  /// **'Osiągnięto limit czasu nagrywania.'**
  String get recording_max_duration_header;

  /// No description provided for @recording_max_duration_body.
  ///
  /// In pl, this message translates to:
  /// **'Sesja osiągnęła maksymalny dozwolony czas 130 minut i została bezpiecznie zatrzymana. Przekaż ją teraz do analizy lub usuń, jeśli było to nagrywanie testowe.'**
  String get recording_max_duration_body;

  /// No description provided for @recording_max_duration_primary.
  ///
  /// In pl, this message translates to:
  /// **'Rozpocznij analizę sesji.'**
  String get recording_max_duration_primary;

  /// No description provided for @recording_max_duration_destructive.
  ///
  /// In pl, this message translates to:
  /// **'Usuń to nagranie bezpowrotnie.'**
  String get recording_max_duration_destructive;

  /// No description provided for @recording_pending_upload_header.
  ///
  /// In pl, this message translates to:
  /// **'Mamy Twoje niedokończone nagranie.'**
  String get recording_pending_upload_header;

  /// No description provided for @recording_pending_upload_body.
  ///
  /// In pl, this message translates to:
  /// **'Sesja z dnia {date} dobiła do limitu 130 minut. Nagranie jest bezpieczne na Twoim urządzeniu i czeka na przekazanie do analizy.'**
  String recording_pending_upload_body(String date);

  /// No description provided for @recording_pending_upload_primary.
  ///
  /// In pl, this message translates to:
  /// **'Przekaż do analizy.'**
  String get recording_pending_upload_primary;

  /// No description provided for @recording_pending_upload_destructive.
  ///
  /// In pl, this message translates to:
  /// **'Usuń to nagranie bezpowrotnie.'**
  String get recording_pending_upload_destructive;

  /// No description provided for @stepper_step1_uploaded.
  ///
  /// In pl, this message translates to:
  /// **'Audio bezpieczne na naszych serwerach.'**
  String get stepper_step1_uploaded;

  /// No description provided for @stepper_step2_transcribing.
  ///
  /// In pl, this message translates to:
  /// **'Tworzymy transkrypcję.'**
  String get stepper_step2_transcribing;

  /// No description provided for @stepper_step3_analyzing.
  ///
  /// In pl, this message translates to:
  /// **'Sztuczna Inteligencja przygotowuje wnioski kliniczne.'**
  String get stepper_step3_analyzing;

  /// No description provided for @stepper_step4_done.
  ///
  /// In pl, this message translates to:
  /// **'Proces zakończony. Przygotowaliśmy Twój raport.'**
  String get stepper_step4_done;

  /// No description provided for @session_failed_header.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się przygotować raportu.'**
  String get session_failed_header;

  /// No description provided for @session_failed_body.
  ///
  /// In pl, this message translates to:
  /// **'Coś poszło nie tak po stronie analizy. Spróbujemy ponownie automatycznie. Jeśli problem się utrzymuje, skontaktuj się z pomocą techniczną.'**
  String get session_failed_body;

  /// No description provided for @session_failed_primary.
  ///
  /// In pl, this message translates to:
  /// **'Skontaktuj się z pomocą.'**
  String get session_failed_primary;

  /// No description provided for @session_loading.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcja przygotowuje się. Możesz wrócić tutaj za chwilę.'**
  String get session_loading;

  /// No description provided for @session_load_error_header.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać sesji.'**
  String get session_load_error_header;

  /// No description provided for @session_load_error_body.
  ///
  /// In pl, this message translates to:
  /// **'Coś nie zadziałało po naszej stronie. Spróbuj ponownie za chwilę.'**
  String get session_load_error_body;

  /// No description provided for @transcript_tab.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcja'**
  String get transcript_tab;

  /// No description provided for @report_tab.
  ///
  /// In pl, this message translates to:
  /// **'Raport'**
  String get report_tab;

  /// No description provided for @transcript_filter_all.
  ///
  /// In pl, this message translates to:
  /// **'Wszyscy'**
  String get transcript_filter_all;

  /// No description provided for @transcript_search_hint.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj w transkrypcji…'**
  String get transcript_search_hint;

  /// No description provided for @transcript_low_confidence_tooltip.
  ///
  /// In pl, this message translates to:
  /// **'Niska pewność transkrypcji w tym fragmencie. Możesz odsłuchać aby zweryfikować.'**
  String get transcript_low_confidence_tooltip;

  /// No description provided for @transcript_segment_unknown_speaker.
  ///
  /// In pl, this message translates to:
  /// **'—'**
  String get transcript_segment_unknown_speaker;

  /// No description provided for @transcript_actions_copy.
  ///
  /// In pl, this message translates to:
  /// **'Kopiuj cytat.'**
  String get transcript_actions_copy;

  /// No description provided for @transcript_actions_copy_with_timestamp.
  ///
  /// In pl, this message translates to:
  /// **'Kopiuj cytat z czasem.'**
  String get transcript_actions_copy_with_timestamp;

  /// No description provided for @transcript_actions_play_from_here.
  ///
  /// In pl, this message translates to:
  /// **'Odtwórz od tego miejsca.'**
  String get transcript_actions_play_from_here;

  /// No description provided for @transcript_actions_export.
  ///
  /// In pl, this message translates to:
  /// **'Eksportuj transkrypt do PDF.'**
  String get transcript_actions_export;

  /// No description provided for @transcript_export_phi_header.
  ///
  /// In pl, this message translates to:
  /// **'Eksportujesz dane wrażliwe.'**
  String get transcript_export_phi_header;

  /// No description provided for @transcript_export_phi_body.
  ///
  /// In pl, this message translates to:
  /// **'Dokument zawiera transkrypcję sesji terapeutycznej. Nie udostępniaj go niezaszyfrowaną pocztą ani komunikatorami bez warstwy E2E.'**
  String get transcript_export_phi_body;

  /// No description provided for @transcript_export_phi_primary.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem, eksportuj.'**
  String get transcript_export_phi_primary;

  /// No description provided for @transcript_export_phi_secondary.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj.'**
  String get transcript_export_phi_secondary;

  /// No description provided for @transcript_pdf_title.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcja sesji'**
  String get transcript_pdf_title;

  /// No description provided for @transcript_pdf_meta_patient.
  ///
  /// In pl, this message translates to:
  /// **'Pacjent: {name}'**
  String transcript_pdf_meta_patient(String name);

  /// No description provided for @transcript_pdf_meta_date.
  ///
  /// In pl, this message translates to:
  /// **'Data sesji: {date}'**
  String transcript_pdf_meta_date(String date);

  /// No description provided for @transcript_pdf_meta_duration.
  ///
  /// In pl, this message translates to:
  /// **'Czas trwania: {duration}'**
  String transcript_pdf_meta_duration(String duration);

  /// No description provided for @transcript_pdf_footer.
  ///
  /// In pl, this message translates to:
  /// **'Wygenerowane przez Superwizor AI · Dokument zawiera dane wrażliwe pacjenta.'**
  String get transcript_pdf_footer;

  /// No description provided for @report_section_summary.
  ///
  /// In pl, this message translates to:
  /// **'Podsumowanie sesji'**
  String get report_section_summary;

  /// No description provided for @report_section_themes.
  ///
  /// In pl, this message translates to:
  /// **'Główne wątki sesji'**
  String get report_section_themes;

  /// No description provided for @report_section_alliance.
  ///
  /// In pl, this message translates to:
  /// **'Sojusz terapeutyczny'**
  String get report_section_alliance;

  /// No description provided for @report_section_interventions.
  ///
  /// In pl, this message translates to:
  /// **'Zaobserwowane interwencje'**
  String get report_section_interventions;

  /// No description provided for @report_section_hitop.
  ///
  /// In pl, this message translates to:
  /// **'Wymiary HiTOP'**
  String get report_section_hitop;

  /// No description provided for @report_section_risk.
  ///
  /// In pl, this message translates to:
  /// **'Ocena ryzyka'**
  String get report_section_risk;

  /// No description provided for @report_section_recommendations.
  ///
  /// In pl, this message translates to:
  /// **'Rekomendacje na kolejną sesję'**
  String get report_section_recommendations;

  /// No description provided for @report_empty_themes.
  ///
  /// In pl, this message translates to:
  /// **'Nie zidentyfikowano głównych wątków w tej sesji.'**
  String get report_empty_themes;

  /// No description provided for @report_empty_interventions.
  ///
  /// In pl, this message translates to:
  /// **'Nie zidentyfikowano interwencji terapeutycznych.'**
  String get report_empty_interventions;

  /// No description provided for @report_empty_recommendations.
  ///
  /// In pl, this message translates to:
  /// **'Brak rekomendacji.'**
  String get report_empty_recommendations;

  /// No description provided for @report_empty_hitop.
  ///
  /// In pl, this message translates to:
  /// **'Brak pomiarów HiTOP w tej sesji.'**
  String get report_empty_hitop;

  /// No description provided for @risk_level_high.
  ///
  /// In pl, this message translates to:
  /// **'Wysokie ryzyko'**
  String get risk_level_high;

  /// No description provided for @risk_level_moderate.
  ///
  /// In pl, this message translates to:
  /// **'Umiarkowane ryzyko'**
  String get risk_level_moderate;

  /// No description provided for @risk_level_low.
  ///
  /// In pl, this message translates to:
  /// **'Niskie ryzyko'**
  String get risk_level_low;

  /// No description provided for @risk_level_none.
  ///
  /// In pl, this message translates to:
  /// **'Brak sygnałów ryzyka'**
  String get risk_level_none;

  /// No description provided for @drawer_profile.
  ///
  /// In pl, this message translates to:
  /// **'Mój profil'**
  String get drawer_profile;

  /// No description provided for @drawer_language.
  ///
  /// In pl, this message translates to:
  /// **'Język aplikacji'**
  String get drawer_language;

  /// No description provided for @drawer_modalities.
  ///
  /// In pl, this message translates to:
  /// **'Nurty terapii'**
  String get drawer_modalities;

  /// No description provided for @drawer_legal_terms.
  ///
  /// In pl, this message translates to:
  /// **'Regulamin'**
  String get drawer_legal_terms;

  /// No description provided for @drawer_legal_dpa.
  ///
  /// In pl, this message translates to:
  /// **'DPA / RODO'**
  String get drawer_legal_dpa;

  /// No description provided for @drawer_about.
  ///
  /// In pl, this message translates to:
  /// **'O aplikacji'**
  String get drawer_about;

  /// No description provided for @drawer_logout.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj.'**
  String get drawer_logout;

  /// No description provided for @drawer_delete_account.
  ///
  /// In pl, this message translates to:
  /// **'Usuń konto.'**
  String get drawer_delete_account;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
