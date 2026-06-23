import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

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

  /// No description provided for @common_error.
  ///
  /// In pl, this message translates to:
  /// **'Wystąpił błąd.'**
  String get common_error;

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

  /// No description provided for @auth_shared_machine_warning_title.
  ///
  /// In pl, this message translates to:
  /// **'Korzystasz ze współdzielonego komputera?'**
  String get auth_shared_machine_warning_title;

  /// No description provided for @auth_shared_machine_warning_body.
  ///
  /// In pl, this message translates to:
  /// **'Po zakończeniu pracy wyloguj się, aby Twoje dane sesji nie zostały dostępne dla kolejnego użytkownika tego komputera.'**
  String get auth_shared_machine_warning_body;

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

  /// No description provided for @auth_sign_in_with_google.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj z Google'**
  String get auth_sign_in_with_google;

  /// No description provided for @auth_sign_in_with_apple.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się z Apple'**
  String get auth_sign_in_with_apple;

  /// No description provided for @auth_or_use_email.
  ///
  /// In pl, this message translates to:
  /// **'Albo użyj adresu e-mail'**
  String get auth_or_use_email;

  /// No description provided for @auth_social_error.
  ///
  /// In pl, this message translates to:
  /// **'Logowanie przez konto zewnętrzne nie powiodło się. Spróbuj ponownie.'**
  String get auth_social_error;

  /// No description provided for @auth_social_cancelled.
  ///
  /// In pl, this message translates to:
  /// **'Logowanie anulowane.'**
  String get auth_social_cancelled;

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

  /// No description provided for @modality_gestalt.
  ///
  /// In pl, this message translates to:
  /// **'Gestalt'**
  String get modality_gestalt;

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

  /// No description provided for @modality_sheet_title.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz swój nurt'**
  String get modality_sheet_title;

  /// No description provided for @modality_sheet_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'To ustawienie wpływa na generowane raporty. Możesz je zmienić w każdej chwili.'**
  String get modality_sheet_subtitle;

  /// No description provided for @addPatient_title.
  ///
  /// In pl, this message translates to:
  /// **'Nowa kartoteka'**
  String get addPatient_title;

  /// No description provided for @addPatient_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Uzupełnij dane klienta, aby utworzyć kartotekę.'**
  String get addPatient_subtitle;

  /// No description provided for @addPatient_first_name_label.
  ///
  /// In pl, this message translates to:
  /// **'Imię (wymagane)'**
  String get addPatient_first_name_label;

  /// No description provided for @addPatient_last_name_label.
  ///
  /// In pl, this message translates to:
  /// **'Inicjał lub pseudonim'**
  String get addPatient_last_name_label;

  /// No description provided for @addPatient_email_label.
  ///
  /// In pl, this message translates to:
  /// **'E-mail klienta'**
  String get addPatient_email_label;

  /// No description provided for @addPatient_email_hint.
  ///
  /// In pl, this message translates to:
  /// **'Opcjonalnie (do planu działania)'**
  String get addPatient_email_hint;

  /// No description provided for @addPatient_modality_label.
  ///
  /// In pl, this message translates to:
  /// **'Nurt terapeutyczny'**
  String get addPatient_modality_label;

  /// No description provided for @addPatient_language_label.
  ///
  /// In pl, this message translates to:
  /// **'Język raportu'**
  String get addPatient_language_label;

  /// No description provided for @addPatient_consent_label.
  ///
  /// In pl, this message translates to:
  /// **'Klient wyraził zgodę na nagrywanie i przetwarzanie danych zgodnie z Polityką Prywatności i DPA Superwizor AI.'**
  String get addPatient_consent_label;

  /// No description provided for @addPatient_consent_link_label.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz DPA.'**
  String get addPatient_consent_link_label;

  /// No description provided for @addPatient_save_primary.
  ///
  /// In pl, this message translates to:
  /// **'Utwórz kartotekę'**
  String get addPatient_save_primary;

  /// No description provided for @addPatient_no_consent_header.
  ///
  /// In pl, this message translates to:
  /// **'Brak zgody na nagrywanie.'**
  String get addPatient_no_consent_header;

  /// No description provided for @addPatient_no_consent_body.
  ///
  /// In pl, this message translates to:
  /// **'Nie możemy rozpocząć sesji bez wyraźnej zgody klienta. Wymagają tego przepisy o ochronie danych.'**
  String get addPatient_no_consent_body;

  /// No description provided for @addPatient_no_consent_primary.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem.'**
  String get addPatient_no_consent_primary;

  /// No description provided for @addPatient_duplicate_header.
  ///
  /// In pl, this message translates to:
  /// **'Taki klient już istnieje.'**
  String get addPatient_duplicate_header;

  /// No description provided for @addPatient_duplicate_body.
  ///
  /// In pl, this message translates to:
  /// **'Masz już kartotekę z tą kombinacją imienia i pseudonimu. Dodaj inicjał lub przydomek, aby uniknąć pomyłek.'**
  String get addPatient_duplicate_body;

  /// No description provided for @addPatient_duplicate_primary.
  ///
  /// In pl, this message translates to:
  /// **'Poprawię nazwę.'**
  String get addPatient_duplicate_primary;

  /// No description provided for @addPatient_step1_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Uzupełnij podstawowe dane klienta.'**
  String get addPatient_step1_subtitle;

  /// No description provided for @addPatient_step1_next.
  ///
  /// In pl, this message translates to:
  /// **'Dalej'**
  String get addPatient_step1_next;

  /// No description provided for @addPatient_step2_title.
  ///
  /// In pl, this message translates to:
  /// **'Dopasuj do Twojej pracy'**
  String get addPatient_step2_title;

  /// No description provided for @addPatient_step2_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Ustawienia, które trafią do AI.'**
  String get addPatient_step2_subtitle;

  /// No description provided for @addPatient_alias_label.
  ///
  /// In pl, this message translates to:
  /// **'Etykieta robocza'**
  String get addPatient_alias_label;

  /// No description provided for @addPatient_alias_hint.
  ///
  /// In pl, this message translates to:
  /// **'Twój prywatny skrót. Widoczny tylko dla Ciebie.'**
  String get addPatient_alias_hint;

  /// No description provided for @addPatient_discard_title.
  ///
  /// In pl, this message translates to:
  /// **'Porzucić zmiany?'**
  String get addPatient_discard_title;

  /// No description provided for @addPatient_discard_body.
  ///
  /// In pl, this message translates to:
  /// **'Nic nie zostanie zapisane.'**
  String get addPatient_discard_body;

  /// No description provided for @addPatient_discard_action.
  ///
  /// In pl, this message translates to:
  /// **'Porzuć'**
  String get addPatient_discard_action;

  /// No description provided for @addPatient_discard_stay.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj edycję'**
  String get addPatient_discard_stay;

  /// No description provided for @editPatient_title.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj kartotekę'**
  String get editPatient_title;

  /// No description provided for @editPatient_save_primary.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz zmiany'**
  String get editPatient_save_primary;

  /// No description provided for @editPatient_erase_destructive.
  ///
  /// In pl, this message translates to:
  /// **'Usuń kartotekę bezpowrotnie'**
  String get editPatient_erase_destructive;

  /// No description provided for @editPatient_erase_confirm_header.
  ///
  /// In pl, this message translates to:
  /// **'Całkowite usunięcie kartoteki'**
  String get editPatient_erase_confirm_header;

  /// No description provided for @editPatient_erase_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'To działanie trwale usunie kartotekę klienta oraz WSZYSTKIE sesje i transkrypcje (wymóg RODO). Nie można tego cofnąć.'**
  String get editPatient_erase_confirm_body;

  /// No description provided for @addSession_title.
  ///
  /// In pl, this message translates to:
  /// **'Nowa sesja.'**
  String get addSession_title;

  /// No description provided for @addSession_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz nurt dla tej sesji:'**
  String get addSession_subtitle;

  /// No description provided for @home_title.
  ///
  /// In pl, this message translates to:
  /// **'Twoi klienci.'**
  String get home_title;

  /// No description provided for @home_empty_title.
  ///
  /// In pl, this message translates to:
  /// **'Nie masz jeszcze żadnych klientów.'**
  String get home_empty_title;

  /// No description provided for @home_empty_body.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj klienta, aby rozpocząć pierwszą sesję.'**
  String get home_empty_body;

  /// No description provided for @home_add_patient_fab.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj klienta'**
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
  /// **'Kilka wskazówek dla lepszego nagrania'**
  String get recording_instructions_title;

  /// No description provided for @recording_instructions_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Dobre warunki nagrywania to lepsza jakość transkrypcji i trafniejsze wnioski AI.'**
  String get recording_instructions_subtitle;

  /// No description provided for @recording_instruction_1.
  ///
  /// In pl, this message translates to:
  /// **'Połóż telefon na stole, między rozmówcami (50–100 cm odległości).'**
  String get recording_instruction_1;

  /// No description provided for @recording_instruction_2.
  ///
  /// In pl, this message translates to:
  /// **'Mikrofon skieruj w stronę rozmowy, niczym go nie zasłaniaj.'**
  String get recording_instruction_2;

  /// No description provided for @recording_instruction_3.
  ///
  /// In pl, this message translates to:
  /// **'Ciche otoczenie – zamknij okna/drzwi, wyłącz źródła hałasu.'**
  String get recording_instruction_3;

  /// No description provided for @recording_instruction_4.
  ///
  /// In pl, this message translates to:
  /// **'Do wideokonferencji (np. Google Meet, Zoom) używaj zawsze dodatkowego urządzenia do nagrywania.'**
  String get recording_instruction_4;

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
  /// **'Czy na pewno chcesz skasować nagranie?'**
  String get recording_discard_confirm_header;

  /// No description provided for @recording_discard_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Tego nagrania nie będzie się dało odzyskać. Zostanie ono bezpowrotnie usunięte z urządzenia i nie zostanie wysłane do analizy.'**
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

  /// No description provided for @recording_fgs_notification_title.
  ///
  /// In pl, this message translates to:
  /// **'Trwa nagrywanie sesji'**
  String get recording_fgs_notification_title;

  /// No description provided for @recording_fgs_notification_body.
  ///
  /// In pl, this message translates to:
  /// **'Superwizor nagrywa sesję. Nie zamykaj aplikacji.'**
  String get recording_fgs_notification_body;

  /// No description provided for @recording_interrupted_banner_title.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywanie wstrzymane'**
  String get recording_interrupted_banner_title;

  /// No description provided for @recording_interrupted_banner_body.
  ///
  /// In pl, this message translates to:
  /// **'Połączenie lub inna aplikacja przerwała nagrywanie. Dotychczasowe nagranie jest bezpieczne.'**
  String get recording_interrupted_banner_body;

  /// No description provided for @recording_interrupted_resume.
  ///
  /// In pl, this message translates to:
  /// **'Wznów nagrywanie'**
  String get recording_interrupted_resume;

  /// No description provided for @recording_resume_failed_header.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wznowić'**
  String get recording_resume_failed_header;

  /// No description provided for @recording_resume_failed_body.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wznowić nagrywania. Dotychczasowe nagranie jest bezpieczne, możesz zakończyć sesję i wysłać je do analizy.'**
  String get recording_resume_failed_body;

  /// No description provided for @recording_resume_failed_retry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get recording_resume_failed_retry;

  /// No description provided for @recording_resume_failed_finish.
  ///
  /// In pl, this message translates to:
  /// **'Zakończ i wyślij'**
  String get recording_resume_failed_finish;

  /// No description provided for @recovery_sheet_header.
  ///
  /// In pl, this message translates to:
  /// **'Znaleziono przerwane nagranie'**
  String get recovery_sheet_header;

  /// No description provided for @recovery_sheet_body.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie sesji z {patientAlias} z {date} (ok. {minutes} min) nie zostało wysłane, ponieważ aplikacja została przerwana w trakcie nagrywania. Co chcesz zrobić?'**
  String recovery_sheet_body(String patientAlias, String date, int minutes);

  /// No description provided for @recovery_sheet_send.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij do analizy'**
  String get recovery_sheet_send;

  /// No description provided for @recovery_sheet_later.
  ///
  /// In pl, this message translates to:
  /// **'Zdecyduję później'**
  String get recovery_sheet_later;

  /// No description provided for @recovery_sheet_delete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń nagranie'**
  String get recovery_sheet_delete;

  /// No description provided for @recovery_delete_confirm_header.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć bezpowrotnie?'**
  String get recovery_delete_confirm_header;

  /// No description provided for @recovery_delete_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Tego nagrania nie da się odzyskać.'**
  String get recovery_delete_confirm_body;

  /// No description provided for @recovery_delete_confirm_destructive.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get recovery_delete_confirm_destructive;

  /// No description provided for @recovery_enqueued_snackbar.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie dodane do kolejki wysyłki'**
  String get recovery_enqueued_snackbar;

  /// No description provided for @stepper_step1_uploaded.
  ///
  /// In pl, this message translates to:
  /// **'Audio bezpieczne na naszych serwerach.'**
  String get stepper_step1_uploaded;

  /// No description provided for @stepper_step1_queued.
  ///
  /// In pl, this message translates to:
  /// **'Audio czeka w kolejce do uploadu.'**
  String get stepper_step1_queued;

  /// No description provided for @stepper_step2_transcribing.
  ///
  /// In pl, this message translates to:
  /// **'Tworzymy transkrypcję.'**
  String get stepper_step2_transcribing;

  /// No description provided for @stepper_step3_analyzing.
  ///
  /// In pl, this message translates to:
  /// **'Sztuczna Inteligencja przygotowuje wnioski.'**
  String get stepper_step3_analyzing;

  /// No description provided for @stepper_step4_finalizing.
  ///
  /// In pl, this message translates to:
  /// **'Składamy informacje w czytelny raport.'**
  String get stepper_step4_finalizing;

  /// No description provided for @stepper_step5_done.
  ///
  /// In pl, this message translates to:
  /// **'Gotowe! Wysyłamy wnioski do Ciebie.'**
  String get stepper_step5_done;

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

  /// No description provided for @session_status_title.
  ///
  /// In pl, this message translates to:
  /// **'Bezpieczna analiza w toku.'**
  String get session_status_title;

  /// No description provided for @session_status_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Opracowujemy dla Ciebie raporty i transkrypcje. Może to potrwać 15 minut. Możesz tutaj wrócić za chwilę.'**
  String get session_status_subtitle;

  /// No description provided for @session_status_success.
  ///
  /// In pl, this message translates to:
  /// **'Gotowe!'**
  String get session_status_success;

  /// No description provided for @session_status_back_to_records.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do kartotek'**
  String get session_status_back_to_records;

  /// No description provided for @session_loading.
  ///
  /// In pl, this message translates to:
  /// **'Opracowujemy dla Ciebie raporty i transkrypcje. Możesz tutaj wrócić za chwilę.'**
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
  /// **'Klient: {name}'**
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
  /// **'Wygenerowane przez Superwizor AI · Dokument zawiera dane wrażliwe klienta.'**
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

  /// No description provided for @settings_title.
  ///
  /// In pl, this message translates to:
  /// **'Ustawienia'**
  String get settings_title;

  /// No description provided for @settings_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'DOSTOSUJ SWOJE DOŚWIADCZENIE'**
  String get settings_subtitle;

  /// No description provided for @settings_section_account.
  ///
  /// In pl, this message translates to:
  /// **'TWOJE KONTO'**
  String get settings_section_account;

  /// No description provided for @settings_logged_in_as.
  ///
  /// In pl, this message translates to:
  /// **'Zalogowano jako: {email}'**
  String settings_logged_in_as(String email);

  /// No description provided for @settings_name.
  ///
  /// In pl, this message translates to:
  /// **'Nazwa'**
  String get settings_name;

  /// No description provided for @settings_professional_title.
  ///
  /// In pl, this message translates to:
  /// **'Tytuł zawodowy'**
  String get settings_professional_title;

  /// No description provided for @settings_email.
  ///
  /// In pl, this message translates to:
  /// **'Email'**
  String get settings_email;

  /// No description provided for @settings_avatar.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcie profilowe'**
  String get settings_avatar;

  /// No description provided for @settings_modality.
  ///
  /// In pl, this message translates to:
  /// **'Domyślny nurt terapii'**
  String get settings_modality;

  /// No description provided for @settings_section_preferences.
  ///
  /// In pl, this message translates to:
  /// **'PREFERENCJE'**
  String get settings_section_preferences;

  /// No description provided for @settings_sounds.
  ///
  /// In pl, this message translates to:
  /// **'Dźwięki'**
  String get settings_sounds;

  /// No description provided for @settings_sounds_on.
  ///
  /// In pl, this message translates to:
  /// **'Dźwięki włączone'**
  String get settings_sounds_on;

  /// No description provided for @settings_sounds_off.
  ///
  /// In pl, this message translates to:
  /// **'Dźwięki wyłączone'**
  String get settings_sounds_off;

  /// No description provided for @settings_haptics.
  ///
  /// In pl, this message translates to:
  /// **'Wibracje'**
  String get settings_haptics;

  /// No description provided for @settings_haptics_on.
  ///
  /// In pl, this message translates to:
  /// **'Wibracje włączone'**
  String get settings_haptics_on;

  /// No description provided for @settings_haptics_off.
  ///
  /// In pl, this message translates to:
  /// **'Wibracje wyłączone'**
  String get settings_haptics_off;

  /// No description provided for @settings_language.
  ///
  /// In pl, this message translates to:
  /// **'Język aplikacji'**
  String get settings_language;

  /// No description provided for @settings_section_support.
  ///
  /// In pl, this message translates to:
  /// **'WSPARCIE'**
  String get settings_section_support;

  /// No description provided for @settings_contact.
  ///
  /// In pl, this message translates to:
  /// **'Napisz do nas'**
  String get settings_contact;

  /// No description provided for @settings_waitlist.
  ///
  /// In pl, this message translates to:
  /// **'Lista oczekujących'**
  String get settings_waitlist;

  /// No description provided for @settings_section_legal.
  ///
  /// In pl, this message translates to:
  /// **'INFORMACJE PRAWNE'**
  String get settings_section_legal;

  /// No description provided for @settings_terms.
  ///
  /// In pl, this message translates to:
  /// **'Regulamin'**
  String get settings_terms;

  /// No description provided for @settings_privacy.
  ///
  /// In pl, this message translates to:
  /// **'Polityka Prywatności'**
  String get settings_privacy;

  /// No description provided for @settings_dpa.
  ///
  /// In pl, this message translates to:
  /// **'DPA / RODO'**
  String get settings_dpa;

  /// No description provided for @settings_licenses.
  ///
  /// In pl, this message translates to:
  /// **'Licencje oprogramowania'**
  String get settings_licenses;

  /// No description provided for @settings_section_account_management.
  ///
  /// In pl, this message translates to:
  /// **'ZARZĄDZANIE KONTEM'**
  String get settings_section_account_management;

  /// No description provided for @settings_logout.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj się'**
  String get settings_logout;

  /// No description provided for @settings_delete_account.
  ///
  /// In pl, this message translates to:
  /// **'Usuń konto bezpowrotnie'**
  String get settings_delete_account;

  /// No description provided for @settings_logout_confirm_title.
  ///
  /// In pl, this message translates to:
  /// **'Czy chcesz się wylogować?'**
  String get settings_logout_confirm_title;

  /// No description provided for @settings_logout_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Będziesz musiał zalogować się ponownie, aby uzyskać dostęp do swoich klientów.'**
  String get settings_logout_confirm_body;

  /// No description provided for @settings_logout_confirm_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Zostań'**
  String get settings_logout_confirm_cancel;

  /// No description provided for @settings_logout_confirm_logout.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj się'**
  String get settings_logout_confirm_logout;

  /// No description provided for @modality_abbr_univ.
  ///
  /// In pl, this message translates to:
  /// **'Integr.'**
  String get modality_abbr_univ;

  /// No description provided for @modality_abbr_cbt.
  ///
  /// In pl, this message translates to:
  /// **'CBT'**
  String get modality_abbr_cbt;

  /// No description provided for @modality_abbr_psycho.
  ///
  /// In pl, this message translates to:
  /// **'Psychod.'**
  String get modality_abbr_psycho;

  /// No description provided for @modality_abbr_gestalt.
  ///
  /// In pl, this message translates to:
  /// **'Gestalt'**
  String get modality_abbr_gestalt;

  /// No description provided for @modality_abbr_ppt.
  ///
  /// In pl, this message translates to:
  /// **'PPT'**
  String get modality_abbr_ppt;

  /// No description provided for @modality_abbr_st.
  ///
  /// In pl, this message translates to:
  /// **'ST'**
  String get modality_abbr_st;

  /// No description provided for @modality_abbr_sys.
  ///
  /// In pl, this message translates to:
  /// **'System.'**
  String get modality_abbr_sys;

  /// No description provided for @modality_abbr_eft.
  ///
  /// In pl, this message translates to:
  /// **'EFT'**
  String get modality_abbr_eft;

  /// No description provided for @modality_abbr_coach.
  ///
  /// In pl, this message translates to:
  /// **'Coaching'**
  String get modality_abbr_coach;

  /// No description provided for @settings_language_app.
  ///
  /// In pl, this message translates to:
  /// **'Język aplikacji'**
  String get settings_language_app;

  /// No description provided for @settings_delete_confirm_title.
  ///
  /// In pl, this message translates to:
  /// **'Czy na pewno chcesz\nusunąć konto?'**
  String get settings_delete_confirm_title;

  /// No description provided for @settings_delete_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Ta operacja jest NIEODWRACALNA.\nUstracisz całą dokumentację kliniczną i dane klientów.'**
  String get settings_delete_confirm_body;

  /// No description provided for @settings_delete_confirm_proceed.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem, przejdź dalej.'**
  String get settings_delete_confirm_proceed;

  /// No description provided for @settings_delete_confirm_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj, zachowaj konto.'**
  String get settings_delete_confirm_cancel;

  /// No description provided for @settings_choose_language.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz język'**
  String get settings_choose_language;

  /// No description provided for @delete_account_title.
  ///
  /// In pl, this message translates to:
  /// **'Usuń konto'**
  String get delete_account_title;

  /// No description provided for @delete_account_consequence_1.
  ///
  /// In pl, this message translates to:
  /// **'Cała dokumentacja kliniczna (wszystkich klientów, kartoteki, sesje i raporty AI) zostanie trwale usunięta.'**
  String get delete_account_consequence_1;

  /// No description provided for @delete_account_consequence_2.
  ///
  /// In pl, this message translates to:
  /// **'Twoja subskrypcja (jeśli ją posiadasz) nie zostanie automatycznie anulowana. Musisz ją anulować osobno w App Store lub Google Play.'**
  String get delete_account_consequence_2;

  /// No description provided for @delete_account_consequence_3.
  ///
  /// In pl, this message translates to:
  /// **'Nie będziesz mógł odzyskać danych po zakończeniu tego procesu. Operacja jest nieodwracalna.'**
  String get delete_account_consequence_3;

  /// No description provided for @delete_account_toggle_text.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem konsekwencje\ni chcę usunąć konto'**
  String get delete_account_toggle_text;

  /// No description provided for @delete_account_button.
  ///
  /// In pl, this message translates to:
  /// **'Usuń moje konto'**
  String get delete_account_button;

  /// No description provided for @delete_account_sheet_title.
  ///
  /// In pl, this message translates to:
  /// **'Ostatni krok.'**
  String get delete_account_sheet_title;

  /// No description provided for @delete_account_sheet_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Aby potwierdzić, wpisz:'**
  String get delete_account_sheet_subtitle;

  /// No description provided for @delete_account_sheet_hint.
  ///
  /// In pl, this message translates to:
  /// **'wpisz tutaj…'**
  String get delete_account_sheet_hint;

  /// No description provided for @delete_account_sheet_button.
  ///
  /// In pl, this message translates to:
  /// **'USUWAM KONTO'**
  String get delete_account_sheet_button;

  /// No description provided for @delete_account_sheet_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj.'**
  String get delete_account_sheet_cancel;

  /// No description provided for @delete_account_relogin_error.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się ponownie, by usunąć konto.'**
  String get delete_account_relogin_error;

  /// No description provided for @delete_account_confirm_word.
  ///
  /// In pl, this message translates to:
  /// **'usuwam'**
  String get delete_account_confirm_word;

  /// No description provided for @settings_licenses_desc.
  ///
  /// In pl, this message translates to:
  /// **'Ta aplikacja została zbudowana dzięki pracy tysięcy programistów z całego świata. Poniżej znajdziesz informacje o oprogramowaniu open-source, z którego korzystamy, by dostarczyć Ci najwyższą jakość działania.'**
  String get settings_licenses_desc;

  /// No description provided for @report_rating_thumbs_up_tooltip.
  ///
  /// In pl, this message translates to:
  /// **'Dobry raport'**
  String get report_rating_thumbs_up_tooltip;

  /// No description provided for @report_rating_thumbs_down_tooltip.
  ///
  /// In pl, this message translates to:
  /// **'Coś jest nie tak'**
  String get report_rating_thumbs_down_tooltip;

  /// No description provided for @report_rating_saved_positive.
  ///
  /// In pl, this message translates to:
  /// **'Dzięki za pozytywną ocenę.'**
  String get report_rating_saved_positive;

  /// No description provided for @report_rating_saved_negative.
  ///
  /// In pl, this message translates to:
  /// **'Dzięki, uwzględnimy to przy kolejnych raportach.'**
  String get report_rating_saved_negative;

  /// No description provided for @report_rating_save_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać oceny. Spróbuj ponownie.'**
  String get report_rating_save_error;

  /// No description provided for @report_rating_modal_title.
  ///
  /// In pl, this message translates to:
  /// **'Co poszło nie tak?'**
  String get report_rating_modal_title;

  /// No description provided for @report_rating_modal_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz jedną lub więcej kategorii. Pomoże nam to dostroić kolejne raporty.'**
  String get report_rating_modal_subtitle;

  /// No description provided for @report_rating_notes_label.
  ///
  /// In pl, this message translates to:
  /// **'Dodatkowy komentarz (opcjonalnie)'**
  String get report_rating_notes_label;

  /// No description provided for @report_rating_notes_hint.
  ///
  /// In pl, this message translates to:
  /// **'Krótka notatka, max. 200 znaków…'**
  String get report_rating_notes_hint;

  /// No description provided for @report_rating_submit.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij ocenę'**
  String get report_rating_submit;

  /// No description provided for @report_rating_chip_too_long.
  ///
  /// In pl, this message translates to:
  /// **'Za długi'**
  String get report_rating_chip_too_long;

  /// No description provided for @report_rating_chip_too_short.
  ///
  /// In pl, this message translates to:
  /// **'Za krótki'**
  String get report_rating_chip_too_short;

  /// No description provided for @report_rating_chip_wrong_tone.
  ///
  /// In pl, this message translates to:
  /// **'Zły ton'**
  String get report_rating_chip_wrong_tone;

  /// No description provided for @report_rating_chip_too_many_quotes.
  ///
  /// In pl, this message translates to:
  /// **'Za dużo cytatów'**
  String get report_rating_chip_too_many_quotes;

  /// No description provided for @report_rating_chip_too_few_quotes.
  ///
  /// In pl, this message translates to:
  /// **'Za mało cytatów'**
  String get report_rating_chip_too_few_quotes;

  /// No description provided for @report_rating_chip_inaccurate_interpretation.
  ///
  /// In pl, this message translates to:
  /// **'Niedokładna interpretacja'**
  String get report_rating_chip_inaccurate_interpretation;

  /// No description provided for @report_rating_chip_missing_strengths.
  ///
  /// In pl, this message translates to:
  /// **'Brakuje mocnych stron klienta'**
  String get report_rating_chip_missing_strengths;

  /// No description provided for @report_rating_chip_missing_context.
  ///
  /// In pl, this message translates to:
  /// **'Brakuje kontekstu / złe akcenty'**
  String get report_rating_chip_missing_context;

  /// No description provided for @report_rating_chip_other.
  ///
  /// In pl, this message translates to:
  /// **'Inne'**
  String get report_rating_chip_other;

  /// No description provided for @settings_section_report_preferences.
  ///
  /// In pl, this message translates to:
  /// **'PREFERENCJE RAPORTÓW'**
  String get settings_section_report_preferences;

  /// No description provided for @report_prefs_intro_title.
  ///
  /// In pl, this message translates to:
  /// **'Styl raportów'**
  String get report_prefs_intro_title;

  /// No description provided for @report_prefs_intro_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Dostosuj, jak AI pisze raporty z Twoich sesji.'**
  String get report_prefs_intro_subtitle;

  /// No description provided for @report_prefs_load_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się załadować preferencji.'**
  String get report_prefs_load_error;

  /// No description provided for @report_prefs_save_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać preferencji. Spróbuj ponownie.'**
  String get report_prefs_save_error;

  /// No description provided for @report_prefs_saved.
  ///
  /// In pl, this message translates to:
  /// **'Zapisano preferencje.'**
  String get report_prefs_saved;

  /// No description provided for @report_prefs_length_label.
  ///
  /// In pl, this message translates to:
  /// **'Długość raportu'**
  String get report_prefs_length_label;

  /// No description provided for @report_prefs_length_brief.
  ///
  /// In pl, this message translates to:
  /// **'Krótki'**
  String get report_prefs_length_brief;

  /// No description provided for @report_prefs_length_standard.
  ///
  /// In pl, this message translates to:
  /// **'Standardowy'**
  String get report_prefs_length_standard;

  /// No description provided for @report_prefs_length_detailed.
  ///
  /// In pl, this message translates to:
  /// **'Szczegółowy'**
  String get report_prefs_length_detailed;

  /// No description provided for @report_prefs_tone_label.
  ///
  /// In pl, this message translates to:
  /// **'Ton'**
  String get report_prefs_tone_label;

  /// No description provided for @report_prefs_tone_clinical_formal.
  ///
  /// In pl, this message translates to:
  /// **'Kliniczny, formalny'**
  String get report_prefs_tone_clinical_formal;

  /// No description provided for @report_prefs_tone_empathic_warm.
  ///
  /// In pl, this message translates to:
  /// **'Empatyczny, ciepły'**
  String get report_prefs_tone_empathic_warm;

  /// No description provided for @report_prefs_tone_pragmatic_direct.
  ///
  /// In pl, this message translates to:
  /// **'Pragmatyczny, bezpośredni'**
  String get report_prefs_tone_pragmatic_direct;

  /// No description provided for @report_prefs_tone_academic_rigorous.
  ///
  /// In pl, this message translates to:
  /// **'Akademicki, rygorystyczny'**
  String get report_prefs_tone_academic_rigorous;

  /// No description provided for @report_prefs_quote_density_label.
  ///
  /// In pl, this message translates to:
  /// **'Liczba cytatów z sesji'**
  String get report_prefs_quote_density_label;

  /// No description provided for @report_prefs_quote_density_few.
  ///
  /// In pl, this message translates to:
  /// **'Mało'**
  String get report_prefs_quote_density_few;

  /// No description provided for @report_prefs_quote_density_selective.
  ///
  /// In pl, this message translates to:
  /// **'Wybiórczo'**
  String get report_prefs_quote_density_selective;

  /// No description provided for @report_prefs_quote_density_many.
  ///
  /// In pl, this message translates to:
  /// **'Dużo'**
  String get report_prefs_quote_density_many;

  /// No description provided for @report_prefs_diagnostic_language_label.
  ///
  /// In pl, this message translates to:
  /// **'Język diagnostyczny'**
  String get report_prefs_diagnostic_language_label;

  /// No description provided for @report_prefs_diagnostic_language_descriptive.
  ///
  /// In pl, this message translates to:
  /// **'Opisowy'**
  String get report_prefs_diagnostic_language_descriptive;

  /// No description provided for @report_prefs_diagnostic_language_clinical_labels.
  ///
  /// In pl, this message translates to:
  /// **'Etykiety kliniczne'**
  String get report_prefs_diagnostic_language_clinical_labels;

  /// No description provided for @report_prefs_diagnostic_language_dsm_icd.
  ///
  /// In pl, this message translates to:
  /// **'DSM / ICD'**
  String get report_prefs_diagnostic_language_dsm_icd;

  /// No description provided for @report_prefs_hypothesis_hedging_label.
  ///
  /// In pl, this message translates to:
  /// **'Stopień asertywności hipotez'**
  String get report_prefs_hypothesis_hedging_label;

  /// No description provided for @report_prefs_hypothesis_hedging_tentative.
  ///
  /// In pl, this message translates to:
  /// **'Ostrożny'**
  String get report_prefs_hypothesis_hedging_tentative;

  /// No description provided for @report_prefs_hypothesis_hedging_balanced.
  ///
  /// In pl, this message translates to:
  /// **'Wyważony'**
  String get report_prefs_hypothesis_hedging_balanced;

  /// No description provided for @report_prefs_hypothesis_hedging_assertive.
  ///
  /// In pl, this message translates to:
  /// **'Asertywny'**
  String get report_prefs_hypothesis_hedging_assertive;

  /// No description provided for @report_prefs_section_emphasis_label.
  ///
  /// In pl, this message translates to:
  /// **'Sekcje do rozwinięcia'**
  String get report_prefs_section_emphasis_label;

  /// No description provided for @report_prefs_section_emphasis_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz sekcje, na których AI ma się skupić.'**
  String get report_prefs_section_emphasis_subtitle;

  /// No description provided for @report_prefs_section_clinical_picture.
  ///
  /// In pl, this message translates to:
  /// **'Obraz kliniczny'**
  String get report_prefs_section_clinical_picture;

  /// No description provided for @report_prefs_section_interventions.
  ///
  /// In pl, this message translates to:
  /// **'Interwencje'**
  String get report_prefs_section_interventions;

  /// No description provided for @report_prefs_section_case_formulation.
  ///
  /// In pl, this message translates to:
  /// **'Konceptualizacja przypadku'**
  String get report_prefs_section_case_formulation;

  /// No description provided for @report_prefs_section_supervisory_recommendations.
  ///
  /// In pl, this message translates to:
  /// **'Rekomendacje superwizyjne'**
  String get report_prefs_section_supervisory_recommendations;

  /// No description provided for @report_prefs_section_homework_between_sessions.
  ///
  /// In pl, this message translates to:
  /// **'Zadania między sesjami'**
  String get report_prefs_section_homework_between_sessions;

  /// No description provided for @report_prefs_section_cultural_context.
  ///
  /// In pl, this message translates to:
  /// **'Kontekst kulturowy'**
  String get report_prefs_section_cultural_context;

  /// No description provided for @report_prefs_section_safety_and_risk.
  ///
  /// In pl, this message translates to:
  /// **'Bezpieczeństwo i ryzyko'**
  String get report_prefs_section_safety_and_risk;

  /// No description provided for @report_prefs_strengths_framing_label.
  ///
  /// In pl, this message translates to:
  /// **'Akcent na mocnych stronach'**
  String get report_prefs_strengths_framing_label;

  /// No description provided for @report_prefs_strengths_framing_problem_focused.
  ///
  /// In pl, this message translates to:
  /// **'Skupiony na problemach'**
  String get report_prefs_strengths_framing_problem_focused;

  /// No description provided for @report_prefs_strengths_framing_balanced.
  ///
  /// In pl, this message translates to:
  /// **'Wyważony'**
  String get report_prefs_strengths_framing_balanced;

  /// No description provided for @report_prefs_strengths_framing_strengths_first.
  ///
  /// In pl, this message translates to:
  /// **'Mocne strony na pierwszym planie'**
  String get report_prefs_strengths_framing_strengths_first;

  /// No description provided for @report_prefs_free_text_label.
  ///
  /// In pl, this message translates to:
  /// **'Dodatkowe wskazówki'**
  String get report_prefs_free_text_label;

  /// No description provided for @report_prefs_free_text_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Wolny tekst, max. 500 znaków. Te wskazówki AI uwzględni w każdym raporcie.'**
  String get report_prefs_free_text_subtitle;

  /// No description provided for @report_prefs_free_text_hint.
  ///
  /// In pl, this message translates to:
  /// **'np. Skupiaj się na obserwacjach języka ciała klienta…'**
  String get report_prefs_free_text_hint;

  /// No description provided for @report_prefs_value_not_set.
  ///
  /// In pl, this message translates to:
  /// **'Domyślne'**
  String get report_prefs_value_not_set;

  /// No description provided for @report_prefs_picker_title.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz opcję'**
  String get report_prefs_picker_title;

  /// No description provided for @report_prefs_save.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get report_prefs_save;

  /// No description provided for @report_prefs_too_long.
  ///
  /// In pl, this message translates to:
  /// **'Tekst za długi (max. 500 znaków).'**
  String get report_prefs_too_long;

  /// No description provided for @suggestion_banner_header.
  ///
  /// In pl, this message translates to:
  /// **'Sugestia od AI'**
  String get suggestion_banner_header;

  /// No description provided for @suggestion_banner_body.
  ///
  /// In pl, this message translates to:
  /// **'Ostatnie raporty oznaczyłeś jako „{reason}\" ({count}×). Czy zmienić {dimension} na „{toValue}\"?'**
  String suggestion_banner_body(
    String reason,
    int count,
    String dimension,
    String toValue,
  );

  /// No description provided for @suggestion_banner_body_section_emphasis.
  ///
  /// In pl, this message translates to:
  /// **'Ostatnie raporty oznaczyłeś jako „{reason}\" ({count}×). Otwórz ustawienia, aby dostosować akcenty sekcji.'**
  String suggestion_banner_body_section_emphasis(String reason, int count);

  /// No description provided for @suggestion_banner_apply.
  ///
  /// In pl, this message translates to:
  /// **'Zmień'**
  String get suggestion_banner_apply;

  /// No description provided for @suggestion_banner_open_settings.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz ustawienia'**
  String get suggestion_banner_open_settings;

  /// No description provided for @suggestion_banner_dismiss.
  ///
  /// In pl, this message translates to:
  /// **'Nie teraz'**
  String get suggestion_banner_dismiss;

  /// No description provided for @suggestion_banner_applied_toast.
  ///
  /// In pl, this message translates to:
  /// **'Zmieniono, kolejne raporty uwzględnią to ustawienie.'**
  String get suggestion_banner_applied_toast;

  /// No description provided for @suggestion_banner_apply_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zmienić ustawienia.'**
  String get suggestion_banner_apply_error;

  /// Krótka warning banner, pozostałe tokeny w bieżącym okresie
  ///
  /// In pl, this message translates to:
  /// **'{n, plural, =1{Został Ci 1 token.} few{Zostały Ci {n} tokeny.} many{Zostało Ci {n} tokenów.} other{Zostało Ci {n} tokenów.}}'**
  String billing_quota_warning_short(int n);

  /// No description provided for @billing_quota_critical_short.
  ///
  /// In pl, this message translates to:
  /// **'Został Ci ostatni token.'**
  String get billing_quota_critical_short;

  /// No description provided for @billing_quota_exhausted_short.
  ///
  /// In pl, this message translates to:
  /// **'Pula tokenów wyczerpana.'**
  String get billing_quota_exhausted_short;

  /// No description provided for @billing_quota_exhausted_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Nowe sesje zapiszą się lokalnie do dnia odnowienia.'**
  String get billing_quota_exhausted_subtitle;

  /// No description provided for @billing_period_end_label.
  ///
  /// In pl, this message translates to:
  /// **'Pula odnawia się {date}.'**
  String billing_period_end_label(String date);

  /// No description provided for @billing_expand_plan_cta.
  ///
  /// In pl, this message translates to:
  /// **'Rozszerz plan'**
  String get billing_expand_plan_cta;

  /// No description provided for @billing_dismiss_cta.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem, kontynuuj'**
  String get billing_dismiss_cta;

  /// No description provided for @billing_exhausted_dialog_title.
  ///
  /// In pl, this message translates to:
  /// **'Pula tokenów wyczerpana'**
  String get billing_exhausted_dialog_title;

  /// No description provided for @billing_exhausted_dialog_body.
  ///
  /// In pl, this message translates to:
  /// **'Wykorzystałeś dostępne sesje. Możesz nadal nagrywać, audio zostanie bezpiecznie zaszyfrowane i zapisane lokalnie. Sprawdź swoją skrzynkę e-mail, aby dowiedzieć się więcej.'**
  String get billing_exhausted_dialog_body;

  /// No description provided for @billing_exhausted_dialog_record_locally.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywaj lokalnie'**
  String get billing_exhausted_dialog_record_locally;

  /// No description provided for @billing_pending_sessions_title.
  ///
  /// In pl, this message translates to:
  /// **'{n, plural, =1{Sesja oczekująca na przetworzenie} few{Sesje oczekujące na przetworzenie ({n})} many{Sesji oczekujących na przetworzenie ({n})} other{Sesji oczekujących na przetworzenie ({n})}}'**
  String billing_pending_sessions_title(int n);

  /// No description provided for @billing_pending_session_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Audio zapisane lokalnie · Czeka na tokeny'**
  String get billing_pending_session_subtitle;

  /// No description provided for @billing_pending_session_card_meta.
  ///
  /// In pl, this message translates to:
  /// **'Sesja z {date}, {time} ({duration} min)'**
  String billing_pending_session_card_meta(
    String date,
    String time,
    int duration,
  );

  /// No description provided for @billing_resume_processing.
  ///
  /// In pl, this message translates to:
  /// **'Wznów przetwarzanie'**
  String get billing_resume_processing;

  /// No description provided for @billing_delete_local_audio.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get billing_delete_local_audio;

  /// No description provided for @billing_tokens_available_required.
  ///
  /// In pl, this message translates to:
  /// **'Tokeny dostępne: {available} / Wymagane: {required}'**
  String billing_tokens_available_required(int available, int required);

  /// No description provided for @billing_delete_confirm_title.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć nagranie sesji?'**
  String get billing_delete_confirm_title;

  /// No description provided for @billing_delete_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Audio zostanie trwale usunięte z tego urządzenia. Tej operacji nie można cofnąć.'**
  String get billing_delete_confirm_body;

  /// No description provided for @billing_delete_confirm_action.
  ///
  /// In pl, this message translates to:
  /// **'Usuń trwale'**
  String get billing_delete_confirm_action;

  /// No description provided for @billing_reservation_expired_title.
  ///
  /// In pl, this message translates to:
  /// **'Przetwarzanie nie powiodło się'**
  String get billing_reservation_expired_title;

  /// No description provided for @billing_reservation_expired_body.
  ///
  /// In pl, this message translates to:
  /// **'Rezerwacja tokena wygasła po 4 godzinach. Audio jest nadal zapisane lokalnie.'**
  String get billing_reservation_expired_body;

  /// No description provided for @billing_retry_cta.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get billing_retry_cta;

  /// No description provided for @billing_past_due_title.
  ///
  /// In pl, this message translates to:
  /// **'Problem z płatnością'**
  String get billing_past_due_title;

  /// No description provided for @billing_past_due_body.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać opłaty za subskrypcję. Do czasu rozwiązania problemu nie będziemy przetwarzać nowych sesji.'**
  String get billing_past_due_body;

  /// No description provided for @subscription_screen_title.
  ///
  /// In pl, this message translates to:
  /// **'Subskrypcja'**
  String get subscription_screen_title;

  /// No description provided for @subscription_plan_section_header.
  ///
  /// In pl, this message translates to:
  /// **'Twój plan'**
  String get subscription_plan_section_header;

  /// No description provided for @subscription_tier_solo.
  ///
  /// In pl, this message translates to:
  /// **'Poznanie'**
  String get subscription_tier_solo;

  /// No description provided for @subscription_tier_pro.
  ///
  /// In pl, this message translates to:
  /// **'Równowaga'**
  String get subscription_tier_pro;

  /// No description provided for @subscription_tier_clinic.
  ///
  /// In pl, this message translates to:
  /// **'Rozkwit'**
  String get subscription_tier_clinic;

  /// No description provided for @subscription_tier_trial.
  ///
  /// In pl, this message translates to:
  /// **'Wersja próbna'**
  String get subscription_tier_trial;

  /// No description provided for @subscription_cycle_monthly.
  ///
  /// In pl, this message translates to:
  /// **'miesięczny'**
  String get subscription_cycle_monthly;

  /// No description provided for @subscription_cycle_semi_annual.
  ///
  /// In pl, this message translates to:
  /// **'półroczny'**
  String get subscription_cycle_semi_annual;

  /// No description provided for @subscription_cycle_annual.
  ///
  /// In pl, this message translates to:
  /// **'roczny'**
  String get subscription_cycle_annual;

  /// No description provided for @subscription_sessions_per_period.
  ///
  /// In pl, this message translates to:
  /// **'{n, plural, =1{1 sesja w okresie} few{{n} sesje w okresie} many{{n} sesji w okresie} other{{n} sesji w okresie}}'**
  String subscription_sessions_per_period(int n);

  /// No description provided for @subscription_sessions_left.
  ///
  /// In pl, this message translates to:
  /// **'{n, plural, =0{Brak sesji do końca okresu} =1{1 sesja do końca okresu} few{{n} sesje do końca okresu} many{{n} sesji do końca okresu} other{{n} sesji do końca okresu}}'**
  String subscription_sessions_left(int n);

  /// No description provided for @subscription_sessions_used.
  ///
  /// In pl, this message translates to:
  /// **'Wykorzystano: {used} z {limit}'**
  String subscription_sessions_used(int used, int limit);

  /// No description provided for @subscription_period_ends.
  ///
  /// In pl, this message translates to:
  /// **'Okres kończy się {date}'**
  String subscription_period_ends(String date);

  /// No description provided for @subscription_no_data_title.
  ///
  /// In pl, this message translates to:
  /// **'Brak danych o subskrypcji'**
  String get subscription_no_data_title;

  /// No description provided for @subscription_no_data_body.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się pobrać informacji o Twoim planie. Sprawdź połączenie internetowe i spróbuj ponownie.'**
  String get subscription_no_data_body;

  /// No description provided for @subscription_refresh_cta.
  ///
  /// In pl, this message translates to:
  /// **'Odśwież'**
  String get subscription_refresh_cta;

  /// No description provided for @stepper_step1_quota_blocked.
  ///
  /// In pl, this message translates to:
  /// **'Pula tokenów wyczerpana. Odnów plan, aby wznowić.'**
  String get stepper_step1_quota_blocked;

  /// No description provided for @quota_blocked_queue_label.
  ///
  /// In pl, this message translates to:
  /// **'Pula tokenów wyczerpana'**
  String get quota_blocked_queue_label;

  /// No description provided for @upload_resend.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij ponownie'**
  String get upload_resend;

  /// No description provided for @upload_cancel_processing.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get upload_cancel_processing;

  /// No description provided for @cancel_session_confirm_title.
  ///
  /// In pl, this message translates to:
  /// **'Anulować przetwarzanie?'**
  String get cancel_session_confirm_title;

  /// No description provided for @cancel_session_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Sesja zostanie anulowana, a nagranie usunięte z kolejki. Tej operacji nie można cofnąć.'**
  String get cancel_session_confirm_body;

  /// No description provided for @cancel_session_confirm_action.
  ///
  /// In pl, this message translates to:
  /// **'Tak, usuń'**
  String get cancel_session_confirm_action;

  /// No description provided for @cancel_session_keep.
  ///
  /// In pl, this message translates to:
  /// **'Nie, zostaw'**
  String get cancel_session_keep;

  /// No description provided for @cancel_session_success.
  ///
  /// In pl, this message translates to:
  /// **'Sesja anulowana'**
  String get cancel_session_success;

  /// No description provided for @note_add_label.
  ///
  /// In pl, this message translates to:
  /// **'DODAJ NOTATKĘ'**
  String get note_add_label;

  /// No description provided for @note_add_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Szybka notatka o kliencie'**
  String get note_add_subtitle;

  /// No description provided for @note_sheet_title.
  ///
  /// In pl, this message translates to:
  /// **'Nowa notatka'**
  String get note_sheet_title;

  /// No description provided for @note_sheet_hint.
  ///
  /// In pl, this message translates to:
  /// **'Wpisz swoją notatkę…'**
  String get note_sheet_hint;

  /// No description provided for @note_sheet_save.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get note_sheet_save;

  /// No description provided for @note_sheet_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get note_sheet_cancel;

  /// No description provided for @note_delete_confirm.
  ///
  /// In pl, this message translates to:
  /// **'Usunąć notatkę?'**
  String get note_delete_confirm;

  /// No description provided for @note_delete_action.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get note_delete_action;

  /// No description provided for @note_empty_text.
  ///
  /// In pl, this message translates to:
  /// **'Notatka nie może być pusta.'**
  String get note_empty_text;

  /// No description provided for @note_title_hint.
  ///
  /// In pl, this message translates to:
  /// **'Tytuł notatki'**
  String get note_title_hint;

  /// No description provided for @note_body_hint.
  ///
  /// In pl, this message translates to:
  /// **'Treść notatki…'**
  String get note_body_hint;

  /// No description provided for @note_discard_title.
  ///
  /// In pl, this message translates to:
  /// **'Odrzucić zmiany?'**
  String get note_discard_title;

  /// No description provided for @note_discard_body.
  ///
  /// In pl, this message translates to:
  /// **'Masz niezapisane zmiany. Chcesz je odrzucić?'**
  String get note_discard_body;

  /// No description provided for @note_discard_action.
  ///
  /// In pl, this message translates to:
  /// **'Odrzuć'**
  String get note_discard_action;

  /// No description provided for @note_discard_save.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get note_discard_save;

  /// No description provided for @note_edit_label.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj notatkę'**
  String get note_edit_label;

  /// No description provided for @note_untitled.
  ///
  /// In pl, this message translates to:
  /// **'Bez tytułu'**
  String get note_untitled;

  /// No description provided for @note_saved.
  ///
  /// In pl, this message translates to:
  /// **'Notatka zapisana ✓'**
  String get note_saved;

  /// No description provided for @note_deleted.
  ///
  /// In pl, this message translates to:
  /// **'Notatka usunięta'**
  String get note_deleted;

  /// No description provided for @action_plan_send_button.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij plan działania do klienta'**
  String get action_plan_send_button;

  /// No description provided for @action_plan_save_only.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get action_plan_save_only;

  /// No description provided for @action_plan_save_and_send.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz i wyślij'**
  String get action_plan_save_and_send;

  /// No description provided for @action_plan_no_email_title.
  ///
  /// In pl, this message translates to:
  /// **'Brak adresu e-mail'**
  String get action_plan_no_email_title;

  /// No description provided for @action_plan_no_email_body.
  ///
  /// In pl, this message translates to:
  /// **'Nie można wysłać planu, ponieważ klient nie ma zdefiniowanego adresu e-mail. Uzupełnij e-mail w kartotece.'**
  String get action_plan_no_email_body;

  /// No description provided for @action_plan_send_confirm_title.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij plan działania?'**
  String get action_plan_send_confirm_title;

  /// No description provided for @action_plan_send_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Plan zostanie wysłany na adres: {email}'**
  String action_plan_send_confirm_body(String email);

  /// No description provided for @action_plan_send_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get action_plan_send_cancel;

  /// No description provided for @action_plan_send_confirm_action.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij'**
  String get action_plan_send_confirm_action;

  /// No description provided for @action_plan_sent_toast.
  ///
  /// In pl, this message translates to:
  /// **'Plan działania wysłany do klienta'**
  String get action_plan_sent_toast;

  /// No description provided for @action_plan_saved_not_sent.
  ///
  /// In pl, this message translates to:
  /// **'Notatka zapisana, ale nie udało się wysłać e-maila. Spróbuj wysłać ponownie później.'**
  String get action_plan_saved_not_sent;

  /// No description provided for @session_delete_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się usunąć sesji. Spróbuj ponownie.'**
  String get session_delete_error;

  /// No description provided for @session_rename_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać tytułu na serwerze. Spróbuj ponownie.'**
  String get session_rename_error;

  /// No description provided for @action_plan_default_title.
  ///
  /// In pl, this message translates to:
  /// **'Plan działania'**
  String get action_plan_default_title;

  /// No description provided for @action_plan_fill_email_hint.
  ///
  /// In pl, this message translates to:
  /// **'Wypełnij adres e-mail klienta i ponów wysyłkę.'**
  String get action_plan_fill_email_hint;

  /// No description provided for @note_save_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zapisać notatki'**
  String get note_save_error;

  /// No description provided for @note_send_to_client.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij do klienta'**
  String get note_send_to_client;

  /// No description provided for @note_send_confirm_title.
  ///
  /// In pl, this message translates to:
  /// **'Wysłać notatkę do klienta?'**
  String get note_send_confirm_title;

  /// No description provided for @note_send_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Notatka zostanie wysłana na adres: {email}'**
  String note_send_confirm_body(String email);

  /// No description provided for @note_sent_toast.
  ///
  /// In pl, this message translates to:
  /// **'Notatka wysłana do klienta'**
  String get note_sent_toast;

  /// No description provided for @recording_consent_missing_header.
  ///
  /// In pl, this message translates to:
  /// **'Brak zgody'**
  String get recording_consent_missing_header;

  /// No description provided for @recording_consent_missing_body.
  ///
  /// In pl, this message translates to:
  /// **'Nie odnotowano zgody klienta w systemie. Czy klient wyraził zgodę na nagrywanie i przetwarzanie danych?'**
  String get recording_consent_missing_body;

  /// No description provided for @recording_consent_grant.
  ///
  /// In pl, this message translates to:
  /// **'Tak, wyraził zgodę'**
  String get recording_consent_grant;

  /// No description provided for @recording_mic_error_header.
  ///
  /// In pl, this message translates to:
  /// **'Błąd mikrofonu'**
  String get recording_mic_error_header;

  /// No description provided for @recording_upload_error_header.
  ///
  /// In pl, this message translates to:
  /// **'Błąd przesyłania'**
  String get recording_upload_error_header;

  /// No description provided for @recording_too_short_abort_body.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie trwało {duration}. Anulowano wysyłkę.'**
  String recording_too_short_abort_body(String duration);

  /// No description provided for @recording_saving.
  ///
  /// In pl, this message translates to:
  /// **'Zapisuję nagranie...'**
  String get recording_saving;

  /// No description provided for @recording_minimize_confirm_header.
  ///
  /// In pl, this message translates to:
  /// **'Wyjście z ekranu nagrywania'**
  String get recording_minimize_confirm_header;

  /// No description provided for @recording_minimize_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Sesja jest w toku. Możesz zminimalizować ten ekran, aby np. przejść do notatek (nagrywanie będzie kontynuowane w tle).'**
  String get recording_minimize_confirm_body;

  /// No description provided for @recording_minimize_action.
  ///
  /// In pl, this message translates to:
  /// **'Zminimalizuj (zostaw w tle)'**
  String get recording_minimize_action;

  /// No description provided for @recording_minimize_discard.
  ///
  /// In pl, this message translates to:
  /// **'Zatrzymaj i skasuj nagranie'**
  String get recording_minimize_discard;

  /// No description provided for @recording_minimize_resume.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do nagrywania'**
  String get recording_minimize_resume;

  /// No description provided for @recording_discard_confirm_action.
  ///
  /// In pl, this message translates to:
  /// **'Tak, skasuj bezpowrotnie'**
  String get recording_discard_confirm_action;

  /// No description provided for @recording_discard_confirm_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Nie, wróć'**
  String get recording_discard_confirm_cancel;

  /// No description provided for @active_session_card_title.
  ///
  /// In pl, this message translates to:
  /// **'Sesja w toku...'**
  String get active_session_card_title;

  /// No description provided for @active_session_card_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do trwającej sesji'**
  String get active_session_card_subtitle;

  /// No description provided for @active_session_card_paused_title.
  ///
  /// In pl, this message translates to:
  /// **'Sesja wstrzymana'**
  String get active_session_card_paused_title;

  /// No description provided for @active_session_card_paused_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Wznów lub zakończ sesję'**
  String get active_session_card_paused_subtitle;

  /// No description provided for @settings_live_activities.
  ///
  /// In pl, this message translates to:
  /// **'Aktywność na ekranie blokady'**
  String get settings_live_activities;

  /// No description provided for @settings_live_activities_on.
  ///
  /// In pl, this message translates to:
  /// **'Czas i status sesji widoczne bez odblokowywania telefonu.'**
  String get settings_live_activities_on;

  /// No description provided for @settings_live_activities_off.
  ///
  /// In pl, this message translates to:
  /// **'Status sesji widoczny tylko w aplikacji.'**
  String get settings_live_activities_off;

  /// No description provided for @live_activity_info_title.
  ///
  /// In pl, this message translates to:
  /// **'Miej sesję zawsze na oku'**
  String get live_activity_info_title;

  /// No description provided for @live_activity_info_body.
  ///
  /// In pl, this message translates to:
  /// **'Włącz podgląd na ekranie blokady, aby widzieć czas sesji bez otwierania aplikacji.'**
  String get live_activity_info_body;

  /// No description provided for @live_activity_info_enable.
  ///
  /// In pl, this message translates to:
  /// **'Włącz podgląd'**
  String get live_activity_info_enable;

  /// No description provided for @live_activity_info_dismiss.
  ///
  /// In pl, this message translates to:
  /// **'Nie teraz'**
  String get live_activity_info_dismiss;

  /// No description provided for @live_activity_minimize_toast.
  ///
  /// In pl, this message translates to:
  /// **'Sesja działa w tle. Aby widzieć jej czas na ekranie blokady, włącz podgląd w Ustawieniach.'**
  String get live_activity_minimize_toast;

  /// No description provided for @live_activity_status_recording.
  ///
  /// In pl, this message translates to:
  /// **'Sesja w toku'**
  String get live_activity_status_recording;

  /// No description provided for @live_activity_status_paused.
  ///
  /// In pl, this message translates to:
  /// **'Pauza'**
  String get live_activity_status_paused;

  /// No description provided for @live_activity_status_uploading.
  ///
  /// In pl, this message translates to:
  /// **'Wgrywanie nagrania...'**
  String get live_activity_status_uploading;

  /// No description provided for @live_activity_status_analyzing.
  ///
  /// In pl, this message translates to:
  /// **'Analizowanie sesji...'**
  String get live_activity_status_analyzing;

  /// No description provided for @live_activity_status_report_ready.
  ///
  /// In pl, this message translates to:
  /// **'Nowy raport czeka w kartotece'**
  String get live_activity_status_report_ready;

  /// No description provided for @live_activity_show_report.
  ///
  /// In pl, this message translates to:
  /// **'Pokaż raport'**
  String get live_activity_show_report;

  /// No description provided for @live_activity_permission_title.
  ///
  /// In pl, this message translates to:
  /// **'Wymagana zgoda systemowa'**
  String get live_activity_permission_title;

  /// No description provided for @live_activity_permission_body.
  ///
  /// In pl, this message translates to:
  /// **'Podgląd sesji na ekranie blokady wymaga włączenia Aktywności na żywo w ustawieniach systemu.'**
  String get live_activity_permission_body;

  /// No description provided for @live_activity_permission_open_settings.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz ustawienia'**
  String get live_activity_permission_open_settings;

  /// No description provided for @live_activity_permission_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj'**
  String get live_activity_permission_cancel;
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
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
