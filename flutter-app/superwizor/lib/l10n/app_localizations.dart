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

  /// No description provided for @common_not_found.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono'**
  String get common_not_found;

  /// No description provided for @language_pl_name.
  ///
  /// In pl, this message translates to:
  /// **'Polski'**
  String get language_pl_name;

  /// No description provided for @language_pl_sub.
  ///
  /// In pl, this message translates to:
  /// **'polski'**
  String get language_pl_sub;

  /// No description provided for @language_en_name.
  ///
  /// In pl, this message translates to:
  /// **'English'**
  String get language_en_name;

  /// No description provided for @language_en_sub.
  ///
  /// In pl, this message translates to:
  /// **'angielski (Wlk. Brytania)'**
  String get language_en_sub;

  /// No description provided for @session_name_fallback.
  ///
  /// In pl, this message translates to:
  /// **'Rozmowa'**
  String get session_name_fallback;

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

  /// No description provided for @recording_instruction_5.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywanie zatrzyma się automatycznie po ustawionym czasie, a co jakiś czas dostaniesz przypomnienie (z opcjonalnym dźwiękiem) – oba dostosujesz w Ustawieniach → Nagrywanie.'**
  String get recording_instruction_5;

  /// No description provided for @recording_status_initializing.
  ///
  /// In pl, this message translates to:
  /// **'Rozpoczynam nagrywanie…'**
  String get recording_status_initializing;

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

  /// No description provided for @minimized_recording_paused.
  ///
  /// In pl, this message translates to:
  /// **'Pauza nagrywania'**
  String get minimized_recording_paused;

  /// No description provided for @minimized_recording_active.
  ///
  /// In pl, this message translates to:
  /// **'Trwa nagrywanie sesji'**
  String get minimized_recording_active;

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

  /// No description provided for @stepper_step1_uploading.
  ///
  /// In pl, this message translates to:
  /// **'Ładujemy audio na serwer.'**
  String get stepper_step1_uploading;

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
  /// **'Zamknij ekran'**
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

  /// No description provided for @drawer_fallback_name.
  ///
  /// In pl, this message translates to:
  /// **'Terapeuta'**
  String get drawer_fallback_name;

  /// No description provided for @drawer_settings_header.
  ///
  /// In pl, this message translates to:
  /// **'USTAWIENIA'**
  String get drawer_settings_header;

  /// No description provided for @drawer_legal_header.
  ///
  /// In pl, this message translates to:
  /// **'DOKUMENTY PRAWNE'**
  String get drawer_legal_header;

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

  /// No description provided for @home_greeting_prefix.
  ///
  /// In pl, this message translates to:
  /// **'Witaj, '**
  String get home_greeting_prefix;

  /// No description provided for @home_greeting_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Z kim dzisiaj pracujemy?'**
  String get home_greeting_subtitle;

  /// No description provided for @home_search_hint.
  ///
  /// In pl, this message translates to:
  /// **'Szukaj klienta…'**
  String get home_search_hint;

  /// No description provided for @home_empty_list.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj pierwszego klienta, aby rozpocząć.'**
  String get home_empty_list;

  /// No description provided for @home_no_search_results.
  ///
  /// In pl, this message translates to:
  /// **'Brak wyników dla „{query}”'**
  String home_no_search_results(String query);

  /// No description provided for @home_section_active.
  ///
  /// In pl, this message translates to:
  /// **'TWOJE KARTOTEKI'**
  String get home_section_active;

  /// No description provided for @home_section_active_filtered.
  ///
  /// In pl, this message translates to:
  /// **'TWOJE KARTOTEKI • FILTR'**
  String get home_section_active_filtered;

  /// No description provided for @home_section_paused.
  ///
  /// In pl, this message translates to:
  /// **'WSTRZYMANE ({count})'**
  String home_section_paused(int count);

  /// No description provided for @home_section_completed.
  ///
  /// In pl, this message translates to:
  /// **'ZAKOŃCZONE ({count})'**
  String home_section_completed(int count);

  /// No description provided for @home_status_awaiting_first_session.
  ///
  /// In pl, this message translates to:
  /// **'Oczekuje na pierwszą sesję'**
  String get home_status_awaiting_first_session;

  /// No description provided for @home_status_new_client.
  ///
  /// In pl, this message translates to:
  /// **'Nowy klient'**
  String get home_status_new_client;

  /// No description provided for @home_card_sessions_prefix.
  ///
  /// In pl, this message translates to:
  /// **'Sesje: '**
  String get home_card_sessions_prefix;

  /// No description provided for @home_card_last_session_prefix.
  ///
  /// In pl, this message translates to:
  /// **' • Ostatnio: '**
  String get home_card_last_session_prefix;

  /// No description provided for @home_card_last_prefix_only.
  ///
  /// In pl, this message translates to:
  /// **'Ostatnio: '**
  String get home_card_last_prefix_only;

  /// No description provided for @home_status_recording.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywanie'**
  String get home_status_recording;

  /// No description provided for @home_status_has_new_report.
  ///
  /// In pl, this message translates to:
  /// **'Nowy raport'**
  String get home_status_has_new_report;

  /// No description provided for @home_status_analyzing.
  ///
  /// In pl, this message translates to:
  /// **'AI analizuje'**
  String get home_status_analyzing;

  /// No description provided for @home_status_uploading.
  ///
  /// In pl, this message translates to:
  /// **'Wgrywanie…'**
  String get home_status_uploading;

  /// No description provided for @home_status_upload_failed.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłanie\nprzerwane'**
  String get home_status_upload_failed;

  /// No description provided for @home_status_error.
  ///
  /// In pl, this message translates to:
  /// **'Błąd analizy'**
  String get home_status_error;

  /// No description provided for @home_status_active.
  ///
  /// In pl, this message translates to:
  /// **'Aktywny'**
  String get home_status_active;

  /// No description provided for @home_status_completed.
  ///
  /// In pl, this message translates to:
  /// **'Zakończony'**
  String get home_status_completed;

  /// No description provided for @home_status_paused.
  ///
  /// In pl, this message translates to:
  /// **'Wstrzymany'**
  String get home_status_paused;

  /// No description provided for @home_status_new.
  ///
  /// In pl, this message translates to:
  /// **'Nowy'**
  String get home_status_new;

  /// No description provided for @home_menu_lifecycle_active.
  ///
  /// In pl, this message translates to:
  /// **'Aktywna'**
  String get home_menu_lifecycle_active;

  /// No description provided for @home_menu_lifecycle_completed.
  ///
  /// In pl, this message translates to:
  /// **'Zakończona'**
  String get home_menu_lifecycle_completed;

  /// No description provided for @home_menu_lifecycle_paused.
  ///
  /// In pl, this message translates to:
  /// **'Wstrzymana'**
  String get home_menu_lifecycle_paused;

  /// No description provided for @home_menu_edit_data.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj dane'**
  String get home_menu_edit_data;

  /// No description provided for @home_menu_edit_data_desc.
  ///
  /// In pl, this message translates to:
  /// **'Zmień imię, nazwisko, email'**
  String get home_menu_edit_data_desc;

  /// No description provided for @home_menu_delete_patient.
  ///
  /// In pl, this message translates to:
  /// **'Usuń kartotekę'**
  String get home_menu_delete_patient;

  /// No description provided for @home_menu_delete_patient_desc.
  ///
  /// In pl, this message translates to:
  /// **'Skasuj historię, sesje i notatki'**
  String get home_menu_delete_patient_desc;

  /// No description provided for @home_menu_field_first_name.
  ///
  /// In pl, this message translates to:
  /// **'Imię (wymagane)'**
  String get home_menu_field_first_name;

  /// No description provided for @home_menu_field_last_name.
  ///
  /// In pl, this message translates to:
  /// **'Inicjał lub pseudonim'**
  String get home_menu_field_last_name;

  /// No description provided for @home_menu_field_email.
  ///
  /// In pl, this message translates to:
  /// **'E-mail klienta'**
  String get home_menu_field_email;

  /// No description provided for @home_menu_btn_back.
  ///
  /// In pl, this message translates to:
  /// **'Wróć'**
  String get home_menu_btn_back;

  /// No description provided for @home_menu_btn_save.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get home_menu_btn_save;

  /// No description provided for @home_menu_manage_client.
  ///
  /// In pl, this message translates to:
  /// **'Zarządzaj kartoteką klienta'**
  String get home_menu_manage_client;

  /// No description provided for @home_menu_edit_client.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj kartotekę'**
  String get home_menu_edit_client;

  /// No description provided for @home_delete_title.
  ///
  /// In pl, this message translates to:
  /// **'Usunęcie klienta: {name}'**
  String home_delete_title(String name);

  /// No description provided for @home_delete_warning_body.
  ///
  /// In pl, this message translates to:
  /// **'Cała dokumentacja kliniczna — sesje, notatki AI oraz nagrania audio — zostanie trwale i bezpowrotnie usunięta z baz medycznych.\nZgodnie z RODO (prawo do zapomnienia).'**
  String get home_delete_warning_body;

  /// No description provided for @home_delete_warning_understand.
  ///
  /// In pl, this message translates to:
  /// **'Rozumiem, to nieodwracalne.'**
  String get home_delete_warning_understand;

  /// No description provided for @home_delete_btn_continue.
  ///
  /// In pl, this message translates to:
  /// **'Kontynuuj kasowanie'**
  String get home_delete_btn_continue;

  /// No description provided for @home_delete_confirm_instruction.
  ///
  /// In pl, this message translates to:
  /// **'Aby potwierdzić, wpisz:'**
  String get home_delete_confirm_instruction;

  /// No description provided for @home_delete_confirm_word.
  ///
  /// In pl, this message translates to:
  /// **'usuwam'**
  String get home_delete_confirm_word;

  /// No description provided for @home_delete_confirm_hint.
  ///
  /// In pl, this message translates to:
  /// **'wpisz tutaj…'**
  String get home_delete_confirm_hint;

  /// No description provided for @home_delete_btn_confirm.
  ///
  /// In pl, this message translates to:
  /// **'Usuń klienta'**
  String get home_delete_btn_confirm;

  /// No description provided for @home_delete_btn_cancel.
  ///
  /// In pl, this message translates to:
  /// **'Anuluj.'**
  String get home_delete_btn_cancel;

  /// No description provided for @home_error_loading.
  ///
  /// In pl, this message translates to:
  /// **'Błąd: {error}'**
  String home_error_loading(String error);

  /// No description provided for @common_close.
  ///
  /// In pl, this message translates to:
  /// **'Zamknij'**
  String get common_close;

  /// No description provided for @common_copied_to_clipboard.
  ///
  /// In pl, this message translates to:
  /// **'Skopiowano do schowka'**
  String get common_copied_to_clipboard;

  /// No description provided for @common_delete.
  ///
  /// In pl, this message translates to:
  /// **'Usuń'**
  String get common_delete;

  /// No description provided for @common_got_it.
  ///
  /// In pl, this message translates to:
  /// **'Zrozumiałem'**
  String get common_got_it;

  /// No description provided for @pendingUploads_pill_attention.
  ///
  /// In pl, this message translates to:
  /// **'{count} wymaga uwagi'**
  String pendingUploads_pill_attention(int count);

  /// No description provided for @pendingUploads_pill_retrying.
  ///
  /// In pl, this message translates to:
  /// **'{count} wznawianie'**
  String pendingUploads_pill_retrying(int count);

  /// No description provided for @pendingUploads_pill_analyzing.
  ///
  /// In pl, this message translates to:
  /// **'{count} analiza'**
  String pendingUploads_pill_analyzing(int count);

  /// No description provided for @pendingUploads_pill_in_progress.
  ///
  /// In pl, this message translates to:
  /// **'{count} w toku'**
  String pendingUploads_pill_in_progress(int count);

  /// No description provided for @pending_uploads_title.
  ///
  /// In pl, this message translates to:
  /// **'Kolejka sesji'**
  String get pending_uploads_title;

  /// No description provided for @pending_uploads_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Status przesyłania i przetwarzania nagrań.'**
  String get pending_uploads_subtitle;

  /// No description provided for @pending_uploads_error.
  ///
  /// In pl, this message translates to:
  /// **'Błąd: {error}'**
  String pending_uploads_error(String error);

  /// No description provided for @pending_uploads_empty_title.
  ///
  /// In pl, this message translates to:
  /// **'Brak plików w kolejce'**
  String get pending_uploads_empty_title;

  /// No description provided for @pending_uploads_empty_body.
  ///
  /// In pl, this message translates to:
  /// **'Wszystkie sesje zostały wgrane.'**
  String get pending_uploads_empty_body;

  /// No description provided for @pending_uploads_no_internet_title.
  ///
  /// In pl, this message translates to:
  /// **'Brak połączenia z internetem'**
  String get pending_uploads_no_internet_title;

  /// No description provided for @pending_uploads_error_title.
  ///
  /// In pl, this message translates to:
  /// **'Błąd przesyłania'**
  String get pending_uploads_error_title;

  /// No description provided for @pending_uploads_no_internet_desc.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłanie zostało przerwane, ale Twoje nagranie jest bezpiecznie zapisane na tym urządzeniu. Spróbuj przesłać je ponownie, gdy odzyskasz zasięg.'**
  String get pending_uploads_no_internet_desc;

  /// No description provided for @pending_uploads_error_desc.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłanie zostało przerwane z powodu błędu, ale Twoje nagranie jest bezpiecznie zapisane na tym urządzeniu. Spróbuj przesłać je ponownie.'**
  String get pending_uploads_error_desc;

  /// No description provided for @pending_uploads_btn_resend.
  ///
  /// In pl, this message translates to:
  /// **'Prześlij ponownie'**
  String get pending_uploads_btn_resend;

  /// No description provided for @pending_uploads_default_patient_name.
  ///
  /// In pl, this message translates to:
  /// **'Pacjent'**
  String get pending_uploads_default_patient_name;

  /// No description provided for @pending_uploads_resending_auto_prefix.
  ///
  /// In pl, this message translates to:
  /// **'WZNAWIAM AUTOMATYCZNIE: '**
  String get pending_uploads_resending_auto_prefix;

  /// No description provided for @pending_uploads_quota_dialog_title.
  ///
  /// In pl, this message translates to:
  /// **'Brak dostępnych sesji'**
  String get pending_uploads_quota_dialog_title;

  /// No description provided for @pending_uploads_quota_dialog_body.
  ///
  /// In pl, this message translates to:
  /// **'Twoja pula sesji w tym miesiącu została wyczerpana. Aby przetworzyć to nagranie, odwiedź platformę Superwizor w przeglądarce internetowej, aby zarządzać swoim planem.'**
  String get pending_uploads_quota_dialog_body;

  /// No description provided for @pending_uploads_err_reason_no_internet.
  ///
  /// In pl, this message translates to:
  /// **'brak połączenia z internetem'**
  String get pending_uploads_err_reason_no_internet;

  /// No description provided for @pending_uploads_err_reason_timeout.
  ///
  /// In pl, this message translates to:
  /// **'serwer nie odpowiedział w terminie'**
  String get pending_uploads_err_reason_timeout;

  /// No description provided for @pending_uploads_err_reason_link_expired.
  ///
  /// In pl, this message translates to:
  /// **'link do przesyłania wygasł'**
  String get pending_uploads_err_reason_link_expired;

  /// No description provided for @pending_uploads_err_reason_unavailable.
  ///
  /// In pl, this message translates to:
  /// **'serwer chwilowo niedostępny'**
  String get pending_uploads_err_reason_unavailable;

  /// No description provided for @pending_uploads_err_reason_prefix.
  ///
  /// In pl, this message translates to:
  /// **'Powód błędu: {reason}'**
  String pending_uploads_err_reason_prefix(String reason);

  /// No description provided for @pending_uploads_phase_resuming.
  ///
  /// In pl, this message translates to:
  /// **'Wznawianie przesyłania...'**
  String get pending_uploads_phase_resuming;

  /// No description provided for @pending_uploads_phase_encrypting.
  ///
  /// In pl, this message translates to:
  /// **'Szyfrowanie nagrania...'**
  String get pending_uploads_phase_encrypting;

  /// No description provided for @pending_uploads_phase_converting.
  ///
  /// In pl, this message translates to:
  /// **'Konwersja pliku audio...'**
  String get pending_uploads_phase_converting;

  /// No description provided for @pending_uploads_phase_pending.
  ///
  /// In pl, this message translates to:
  /// **'W kolejce'**
  String get pending_uploads_phase_pending;

  /// No description provided for @pending_uploads_phase_uploading.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłam na serwer...'**
  String get pending_uploads_phase_uploading;

  /// No description provided for @pending_uploads_phase_uploaded.
  ///
  /// In pl, this message translates to:
  /// **'Przesłano — finalizuję...'**
  String get pending_uploads_phase_uploaded;

  /// No description provided for @pending_uploads_phase_converted.
  ///
  /// In pl, this message translates to:
  /// **'Konwersja gotowa — finalizuję...'**
  String get pending_uploads_phase_converted;

  /// No description provided for @pending_uploads_phase_completed.
  ///
  /// In pl, this message translates to:
  /// **'Wgrane'**
  String get pending_uploads_phase_completed;

  /// No description provided for @pending_uploads_phase_failed.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłanie przerwane'**
  String get pending_uploads_phase_failed;

  /// No description provided for @pending_uploads_detail_attempt.
  ///
  /// In pl, this message translates to:
  /// **' • próba {attempt}'**
  String pending_uploads_detail_attempt(int attempt);

  /// No description provided for @pending_uploads_quota_card_title.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie czeka na wznowienie.'**
  String get pending_uploads_quota_card_title;

  /// No description provided for @pending_uploads_quota_card_desc.
  ///
  /// In pl, this message translates to:
  /// **'Pula sesji została wyczerpana. Sesja jest bezpiecznie zapisana i zostanie przetworzona po odnowieniu planu.'**
  String get pending_uploads_quota_card_desc;

  /// No description provided for @pending_uploads_btn_checking.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdzam...'**
  String get pending_uploads_btn_checking;

  /// No description provided for @pending_uploads_btn_send_again.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij ponownie'**
  String get pending_uploads_btn_send_again;

  /// No description provided for @addPatient_email_required_error.
  ///
  /// In pl, this message translates to:
  /// **'Podaj e-mail lub zmień język klienta.'**
  String get addPatient_email_required_error;

  /// No description provided for @addPatient_alias_instruction.
  ///
  /// In pl, this message translates to:
  /// **'Nadaj klientowi unikalne oznaczenie — ułatwi nawigację.'**
  String get addPatient_alias_instruction;

  /// No description provided for @addPatient_background_color.
  ///
  /// In pl, this message translates to:
  /// **'KOLOR TŁA'**
  String get addPatient_background_color;

  /// No description provided for @addPatient_skip_for_now.
  ///
  /// In pl, this message translates to:
  /// **'Pomiń na razie'**
  String get addPatient_skip_for_now;

  /// No description provided for @clientDetails_profile_not_loaded.
  ///
  /// In pl, this message translates to:
  /// **'Profil nie został jeszcze załadowany. Spróbuj za chwilę.'**
  String get clientDetails_profile_not_loaded;

  /// No description provided for @clientDetails_error.
  ///
  /// In pl, this message translates to:
  /// **'Błąd: {error}'**
  String clientDetails_error(String error);

  /// No description provided for @clientDetails_session_error.
  ///
  /// In pl, this message translates to:
  /// **'Błąd sesji: {error}'**
  String clientDetails_session_error(String error);

  /// No description provided for @clientDetails_start_work.
  ///
  /// In pl, this message translates to:
  /// **'Rozpocznij pracę'**
  String get clientDetails_start_work;

  /// No description provided for @clientDetails_start_work_desc.
  ///
  /// In pl, this message translates to:
  /// **'Rozpocznij nagrywanie, a system zadba o bezpieczną transkrypcję i przygotuje raport kliniczny.'**
  String get clientDetails_start_work_desc;

  /// No description provided for @clientDetails_encryption_notice_part1.
  ///
  /// In pl, this message translates to:
  /// **'Twoje dane są szyfrowane end-to-end. '**
  String get clientDetails_encryption_notice_part1;

  /// No description provided for @clientDetails_encryption_notice_part2.
  ///
  /// In pl, this message translates to:
  /// **'Nikt poza Tobą nie ma do nich dostępu.'**
  String get clientDetails_encryption_notice_part2;

  /// No description provided for @clientDetails_upload_recording.
  ///
  /// In pl, this message translates to:
  /// **'Prześlij nagranie z dyktafonu'**
  String get clientDetails_upload_recording;

  /// No description provided for @clientDetails_record_new_session.
  ///
  /// In pl, this message translates to:
  /// **'Nagraj nową sesję terapeutyczną'**
  String get clientDetails_record_new_session;

  /// No description provided for @clientDetails_start_first_analysis.
  ///
  /// In pl, this message translates to:
  /// **'Rozpocznij pierwszą analizę'**
  String get clientDetails_start_first_analysis;

  /// No description provided for @clientDetails_status_converting.
  ///
  /// In pl, this message translates to:
  /// **'Konwertuję audio…'**
  String get clientDetails_status_converting;

  /// No description provided for @clientDetails_status_uploading.
  ///
  /// In pl, this message translates to:
  /// **'Wysyłanie audio…'**
  String get clientDetails_status_uploading;

  /// No description provided for @clientDetails_status_interrupted.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłanie przerwane'**
  String get clientDetails_status_interrupted;

  /// No description provided for @clientDetails_delete_session_title.
  ///
  /// In pl, this message translates to:
  /// **'Bezpowrotne usunięcie sesji'**
  String get clientDetails_delete_session_title;

  /// No description provided for @clientDetails_delete_session_desc.
  ///
  /// In pl, this message translates to:
  /// **'Sesja, nagranie i transkrypcja zostaną trwale usunięte. Tej operacji nie można cofnąć.'**
  String get clientDetails_delete_session_desc;

  /// No description provided for @clientDetails_btn_yes_delete.
  ///
  /// In pl, this message translates to:
  /// **'Tak, usuń'**
  String get clientDetails_btn_yes_delete;

  /// No description provided for @clientDetails_manage_session.
  ///
  /// In pl, this message translates to:
  /// **'Zarządzaj sesją'**
  String get clientDetails_manage_session;

  /// No description provided for @clientDetails_manage_session_desc.
  ///
  /// In pl, this message translates to:
  /// **'Zmień tytuł lub usuń sesję'**
  String get clientDetails_manage_session_desc;

  /// No description provided for @clientDetails_session_title_label.
  ///
  /// In pl, this message translates to:
  /// **'Tytuł sesji'**
  String get clientDetails_session_title_label;

  /// No description provided for @clientDetails_btn_save_title.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz tytuł'**
  String get clientDetails_btn_save_title;

  /// No description provided for @clientDetails_btn_delete_session.
  ///
  /// In pl, this message translates to:
  /// **'Usuń sesję'**
  String get clientDetails_btn_delete_session;

  /// No description provided for @clientDetails_btn_delete_session_desc.
  ///
  /// In pl, this message translates to:
  /// **'Trwale usuń nagranie i analizę'**
  String get clientDetails_btn_delete_session_desc;

  /// No description provided for @clientDetails_edit_note_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Zmień tytuł lub treść notatki'**
  String get clientDetails_edit_note_subtitle;

  /// No description provided for @clientDetails_copy_content.
  ///
  /// In pl, this message translates to:
  /// **'Kopiuj treść'**
  String get clientDetails_copy_content;

  /// No description provided for @clientDetails_copy_content_desc.
  ///
  /// In pl, this message translates to:
  /// **'Skopiuj notatkę do schowka'**
  String get clientDetails_copy_content_desc;

  /// No description provided for @clientDetails_note_sent_at.
  ///
  /// In pl, this message translates to:
  /// **'Wysłano {date}'**
  String clientDetails_note_sent_at(String date);

  /// No description provided for @clientDetails_send_note_desc.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij notatkę mailem do klienta'**
  String get clientDetails_send_note_desc;

  /// No description provided for @clientDetails_note_sent_badge.
  ///
  /// In pl, this message translates to:
  /// **'Wysłano'**
  String get clientDetails_note_sent_badge;

  /// No description provided for @clientDetails_delete_note_desc.
  ///
  /// In pl, this message translates to:
  /// **'Trwale usuń tę notatkę'**
  String get clientDetails_delete_note_desc;

  /// No description provided for @clientDetails_no_content.
  ///
  /// In pl, this message translates to:
  /// **'Brak treści'**
  String get clientDetails_no_content;

  /// No description provided for @sessionDetails_stat_modality.
  ///
  /// In pl, this message translates to:
  /// **'MODALNOŚĆ'**
  String get sessionDetails_stat_modality;

  /// No description provided for @sessionDetails_stat_words.
  ///
  /// In pl, this message translates to:
  /// **'SŁOWA'**
  String get sessionDetails_stat_words;

  /// No description provided for @sessionDetails_stat_sentiment.
  ///
  /// In pl, this message translates to:
  /// **'SENTYMENT'**
  String get sessionDetails_stat_sentiment;

  /// No description provided for @sessionDetails_stat_sentiment_neutral.
  ///
  /// In pl, this message translates to:
  /// **'Neutralny'**
  String get sessionDetails_stat_sentiment_neutral;

  /// No description provided for @sessionDetails_stat_sentiment_unknown.
  ///
  /// In pl, this message translates to:
  /// **'Nieznany'**
  String get sessionDetails_stat_sentiment_unknown;

  /// No description provided for @sessionDetails_stat_status.
  ///
  /// In pl, this message translates to:
  /// **'STATUS'**
  String get sessionDetails_stat_status;

  /// No description provided for @sessionDetails_stat_status_new.
  ///
  /// In pl, this message translates to:
  /// **'Nowa'**
  String get sessionDetails_stat_status_new;

  /// No description provided for @sessionDetails_tab_analyses.
  ///
  /// In pl, this message translates to:
  /// **'Analizy'**
  String get sessionDetails_tab_analyses;

  /// No description provided for @sessionDetails_tab_transcriptions.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcje'**
  String get sessionDetails_tab_transcriptions;

  /// No description provided for @sessionDetails_toast_reports_copied.
  ///
  /// In pl, this message translates to:
  /// **'Wszystkie raporty skopiowane do schowka'**
  String get sessionDetails_toast_reports_copied;

  /// No description provided for @sessionDetails_toast_transcript_copied.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcja skopiowana do schowka'**
  String get sessionDetails_toast_transcript_copied;

  /// No description provided for @sessionDetails_ai_reports_soon.
  ///
  /// In pl, this message translates to:
  /// **'Raporty AI — wkrótce'**
  String get sessionDetails_ai_reports_soon;

  /// No description provided for @sessionDetails_ai_reports_soon_desc.
  ///
  /// In pl, this message translates to:
  /// **'Analiza sesji i automatyczne raporty będą dostępne\nw kolejnej aktualizacji.'**
  String get sessionDetails_ai_reports_soon_desc;

  /// No description provided for @sessionDetails_transcript_soon.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcja — wkrótce'**
  String get sessionDetails_transcript_soon;

  /// No description provided for @sessionDetails_transcript_soon_desc.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczna transkrypcja z rozpoznawaniem mówców\nbędzie dostępna w kolejnej aktualizacji.'**
  String get sessionDetails_transcript_soon_desc;

  /// No description provided for @sessionDetails_copy_transcript.
  ///
  /// In pl, this message translates to:
  /// **'Skopiuj transkrypcję'**
  String get sessionDetails_copy_transcript;

  /// No description provided for @report_copy_desc.
  ///
  /// In pl, this message translates to:
  /// **'Skopiuj treść do schowka'**
  String get report_copy_desc;

  /// No description provided for @report_edit_summary_desc.
  ///
  /// In pl, this message translates to:
  /// **'Popraw lub uzupełnij podsumowanie AI'**
  String get report_edit_summary_desc;

  /// No description provided for @report_btn_copy_section.
  ///
  /// In pl, this message translates to:
  /// **'Kopiuj sekcję'**
  String get report_btn_copy_section;

  /// No description provided for @report_btn_edit_section.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj treść'**
  String get report_btn_edit_section;

  /// No description provided for @report_edit_section_desc.
  ///
  /// In pl, this message translates to:
  /// **'Popraw lub uzupełnij raport AI'**
  String get report_edit_section_desc;

  /// No description provided for @report_edit_section_hint.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj treść sekcji...'**
  String get report_edit_section_hint;

  /// No description provided for @report_intro_title.
  ///
  /// In pl, this message translates to:
  /// **'Wstęp'**
  String get report_intro_title;

  /// No description provided for @menu_avatar_title.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcie profilowe'**
  String get menu_avatar_title;

  /// No description provided for @menu_avatar_desc.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz skąd chcesz dodać zdjęcie.'**
  String get menu_avatar_desc;

  /// No description provided for @menu_avatar_updated.
  ///
  /// In pl, this message translates to:
  /// **'Zdjęcie profilowe zaktualizowane'**
  String get menu_avatar_updated;

  /// No description provided for @menu_save_error.
  ///
  /// In pl, this message translates to:
  /// **'Wystąpił błąd podczas zapisu: {error}'**
  String menu_save_error(String error);

  /// No description provided for @menu_invalid_email.
  ///
  /// In pl, this message translates to:
  /// **'Podaj prawidłowy adres e-mail.'**
  String get menu_invalid_email;

  /// No description provided for @menu_verification_sent.
  ///
  /// In pl, this message translates to:
  /// **'Link weryfikacyjny wysłany na {email}'**
  String menu_verification_sent(String email);

  /// No description provided for @menu_reauth_required.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się ponownie, aby zmienić e-mail.'**
  String get menu_reauth_required;

  /// No description provided for @menu_email_in_use.
  ///
  /// In pl, this message translates to:
  /// **'Ten adres jest już używany.'**
  String get menu_email_in_use;

  /// No description provided for @menu_error_message.
  ///
  /// In pl, this message translates to:
  /// **'Wystąpił błąd: {error}'**
  String menu_error_message(String error);

  /// No description provided for @menu_change_email_title.
  ///
  /// In pl, this message translates to:
  /// **'Zmień adres e-mail'**
  String get menu_change_email_title;

  /// No description provided for @menu_change_email_desc.
  ///
  /// In pl, this message translates to:
  /// **'Wyślemy link weryfikacyjny na nowy adres.'**
  String get menu_change_email_desc;

  /// No description provided for @menu_btn_send_verification.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij weryfikację'**
  String get menu_btn_send_verification;

  /// No description provided for @menu_delete_account_confirm_title.
  ///
  /// In pl, this message translates to:
  /// **'Trwałe i nieodwracalne usunięcie'**
  String get menu_delete_account_confirm_title;

  /// No description provided for @sessionStatus_uploading_desc.
  ///
  /// In pl, this message translates to:
  /// **'Superwizor przesyła nagranie sesji na serwer.'**
  String get sessionStatus_uploading_desc;

  /// No description provided for @sessionStatus_btn_delete_session.
  ///
  /// In pl, this message translates to:
  /// **'Usuń sesję'**
  String get sessionStatus_btn_delete_session;

  /// No description provided for @sessionStatus_upload_stopped_title.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłanie zatrzymane'**
  String get sessionStatus_upload_stopped_title;

  /// No description provided for @sessionStatus_upload_stopped_net_err.
  ///
  /// In pl, this message translates to:
  /// **'Wystąpił problem z połączeniem sieciowym.\n\n'**
  String get sessionStatus_upload_stopped_net_err;

  /// No description provided for @sessionStatus_upload_stopped_safe.
  ///
  /// In pl, this message translates to:
  /// **'Nagranie jest bezpieczne na Twoim urządzeniu. '**
  String get sessionStatus_upload_stopped_safe;

  /// No description provided for @sessionStatus_upload_stopped_resume.
  ///
  /// In pl, this message translates to:
  /// **'System wznowi przesyłanie, gdy odzyskasz zasięg.'**
  String get sessionStatus_upload_stopped_resume;

  /// No description provided for @sessionStatus_report_failed_temp.
  ///
  /// In pl, this message translates to:
  /// **'Proces tworzenia raportu napotkał trudność.\n\n'**
  String get sessionStatus_report_failed_temp;

  /// No description provided for @sessionStatus_report_failed_retry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponowić analizę za jakiś czas.'**
  String get sessionStatus_report_failed_retry;

  /// No description provided for @sessionStatus_report_failed_perm.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wygenerować raportu dla tej sesji.\n\n'**
  String get sessionStatus_report_failed_perm;

  /// No description provided for @sessionStatus_report_failed_contact.
  ///
  /// In pl, this message translates to:
  /// **'Jeśli sytuacja się powtarza, daj nam znać.'**
  String get sessionStatus_report_failed_contact;

  /// No description provided for @sessionStatus_status_uploading.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłanie na serwer'**
  String get sessionStatus_status_uploading;

  /// No description provided for @sessionStatus_status_queued.
  ///
  /// In pl, this message translates to:
  /// **'W kolejce do przesłania'**
  String get sessionStatus_status_queued;

  /// No description provided for @sessionStatus_bg_processing_notice.
  ///
  /// In pl, this message translates to:
  /// **'Możesz bezpiecznie opuścić ten ekran,\nsesja przetworzy się w tle.'**
  String get sessionStatus_bg_processing_notice;

  /// No description provided for @recording_ios_only_title.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywanie dostępne w aplikacji iOS'**
  String get recording_ios_only_title;

  /// No description provided for @recording_ios_only_body_part1.
  ///
  /// In pl, this message translates to:
  /// **'Aby nagrać sesję z {alias}, użyj aplikacji '**
  String recording_ios_only_body_part1(String alias);

  /// No description provided for @recording_ios_only_body_part2.
  ///
  /// In pl, this message translates to:
  /// **'Superwizor na iPhone. Po przesłaniu nagrania '**
  String get recording_ios_only_body_part2;

  /// No description provided for @recording_ios_only_body_part3.
  ///
  /// In pl, this message translates to:
  /// **'transkrypcja i raport pojawią się tutaj.'**
  String get recording_ios_only_body_part3;

  /// No description provided for @recording_btn_back.
  ///
  /// In pl, this message translates to:
  /// **'Powrót'**
  String get recording_btn_back;

  /// No description provided for @newSession_error_header.
  ///
  /// In pl, this message translates to:
  /// **'Błąd'**
  String get newSession_error_header;

  /// No description provided for @newSession_upload_file_header.
  ///
  /// In pl, this message translates to:
  /// **'PRZESYŁANIE PLIKU'**
  String get newSession_upload_file_header;

  /// No description provided for @newSession_new_session_header.
  ///
  /// In pl, this message translates to:
  /// **'NOWA SESJA'**
  String get newSession_new_session_header;

  /// No description provided for @newSession_pick_file_desc.
  ///
  /// In pl, this message translates to:
  /// **'Wybierz plik audio z dysku. Po przesłaniu plik zostanie automatycznie przeanalizowany.'**
  String get newSession_pick_file_desc;

  /// No description provided for @newSession_record_or_upload_desc.
  ///
  /// In pl, this message translates to:
  /// **'Nagraj tę sesję, lub prześlij plik audio z dyktafonu.'**
  String get newSession_record_or_upload_desc;

  /// No description provided for @newSession_secure_upload_title.
  ///
  /// In pl, this message translates to:
  /// **'Bezpieczne przesyłanie.'**
  String get newSession_secure_upload_title;

  /// No description provided for @newSession_secure_upload_desc.
  ///
  /// In pl, this message translates to:
  /// **'Twój plik jest szyfrowany i bezpiecznie przesyłany na nasze serwery w Europie. Nikt poza Tobą nie ma dostępu do tych danych.'**
  String get newSession_secure_upload_desc;

  /// No description provided for @newSession_recording_in_progress_err.
  ///
  /// In pl, this message translates to:
  /// **'Trwa nagrywanie innej sesji. Wróć do niej, aby kontynuować.'**
  String get newSession_recording_in_progress_err;

  /// No description provided for @newSession_format_not_supported.
  ///
  /// In pl, this message translates to:
  /// **'Format \"{ext}\" nie jest obsługiwany.\n\n'**
  String newSession_format_not_supported(String ext);

  /// No description provided for @newSession_supported_formats.
  ///
  /// In pl, this message translates to:
  /// **'Obsługiwane formaty: FLAC, WAV, MP3, OGG, OPUS, M4A, AAC, WEBM, AMR.'**
  String get newSession_supported_formats;

  /// No description provided for @newSession_file_too_large.
  ///
  /// In pl, this message translates to:
  /// **'Plik jest zbyt duży ({size} MB). '**
  String newSession_file_too_large(String size);

  /// No description provided for @newSession_uploading_file.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłam plik...'**
  String get newSession_uploading_file;

  /// No description provided for @newSession_recording_active_err.
  ///
  /// In pl, this message translates to:
  /// **'Trwa nagrywanie sesji. Wróć do niej, aby kontynuować.'**
  String get newSession_recording_active_err;

  /// No description provided for @newSession_preparing_file.
  ///
  /// In pl, this message translates to:
  /// **'Przygotowuję plik...'**
  String get newSession_preparing_file;

  /// No description provided for @newSession_queuing.
  ///
  /// In pl, this message translates to:
  /// **'Kolejkuję...'**
  String get newSession_queuing;

  /// No description provided for @newSession_encryption_notice_part1.
  ///
  /// In pl, this message translates to:
  /// **'Twoje nagrania są chronione szyfrowaniem end-to-end i służą wyłącznie '**
  String get newSession_encryption_notice_part1;

  /// No description provided for @newSession_encryption_notice_part2.
  ///
  /// In pl, this message translates to:
  /// **'do analizy AI. Nikt poza Tobą nie ma dostępu do danych.'**
  String get newSession_encryption_notice_part2;

  /// No description provided for @newSession_upload_error.
  ///
  /// In pl, this message translates to:
  /// **'Błąd podczas przesyłania pliku:\n{error}'**
  String newSession_upload_error(String error);

  /// No description provided for @login_auth_error.
  ///
  /// In pl, this message translates to:
  /// **'Błąd uwierzytelniania [{code}]: {message}'**
  String login_auth_error(String code, String message);

  /// No description provided for @login_accept_terms_error.
  ///
  /// In pl, this message translates to:
  /// **'Zaakceptuj Regulamin i Politykę Prywatności, aby kontynuować.'**
  String get login_accept_terms_error;

  /// No description provided for @login_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się do Superwizor AI'**
  String get login_subtitle;

  /// No description provided for @login_title.
  ///
  /// In pl, this message translates to:
  /// **'Witaj ponownie'**
  String get login_title;

  /// No description provided for @login_forgot_password.
  ///
  /// In pl, this message translates to:
  /// **'Nie pamiętam hasła'**
  String get login_forgot_password;

  /// No description provided for @login_btn_sign_in.
  ///
  /// In pl, this message translates to:
  /// **'Zaloguj się'**
  String get login_btn_sign_in;

  /// No description provided for @login_btn_sign_up.
  ///
  /// In pl, this message translates to:
  /// **'Zarejestruj się'**
  String get login_btn_sign_up;

  /// No description provided for @login_register_title.
  ///
  /// In pl, this message translates to:
  /// **'Utwórz konto'**
  String get login_register_title;

  /// No description provided for @login_register_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Dołącz do społeczności terapeutów'**
  String get login_register_subtitle;

  /// No description provided for @login_name_field.
  ///
  /// In pl, this message translates to:
  /// **'Imię i nazwisko'**
  String get login_name_field;

  /// No description provided for @login_password_hint.
  ///
  /// In pl, this message translates to:
  /// **'Utwórz hasło (min. 8 znaków)'**
  String get login_password_hint;

  /// No description provided for @login_already_have_account.
  ///
  /// In pl, this message translates to:
  /// **'Masz już konto? '**
  String get login_already_have_account;

  /// No description provided for @login_accept_prefix.
  ///
  /// In pl, this message translates to:
  /// **'Akceptuję '**
  String get login_accept_prefix;

  /// No description provided for @login_accept_privacy.
  ///
  /// In pl, this message translates to:
  /// **'Politykę Prywatności'**
  String get login_accept_privacy;

  /// No description provided for @login_privacy_policy_title.
  ///
  /// In pl, this message translates to:
  /// **'Polityka Prywatności'**
  String get login_privacy_policy_title;

  /// No description provided for @forgot_err_user_not_found.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleźliśmy konta z tym adresem.'**
  String get forgot_err_user_not_found;

  /// No description provided for @forgot_err_invalid_email.
  ///
  /// In pl, this message translates to:
  /// **'Ten adres e-mail wygląda nieprawidłowo.'**
  String get forgot_err_invalid_email;

  /// No description provided for @forgot_err_too_many_requests.
  ///
  /// In pl, this message translates to:
  /// **'Za dużo prób. Odczekaj chwilę.'**
  String get forgot_err_too_many_requests;

  /// No description provided for @forgot_err_generic.
  ///
  /// In pl, this message translates to:
  /// **'Coś poszło nie tak. Spróbuj ponownie.'**
  String get forgot_err_generic;

  /// No description provided for @forgot_title.
  ///
  /// In pl, this message translates to:
  /// **'Resetowanie hasła'**
  String get forgot_title;

  /// No description provided for @forgot_desc_part1.
  ///
  /// In pl, this message translates to:
  /// **'Podaj adres e-mail powiązany z Twoim kontem. '**
  String get forgot_desc_part1;

  /// No description provided for @forgot_desc_part2.
  ///
  /// In pl, this message translates to:
  /// **'Wyślemy Ci link do ustawienia nowego hasła.'**
  String get forgot_desc_part2;

  /// No description provided for @forgot_email_hint.
  ///
  /// In pl, this message translates to:
  /// **'Twój adres e-mail'**
  String get forgot_email_hint;

  /// No description provided for @forgot_btn_send_link.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij link'**
  String get forgot_btn_send_link;

  /// No description provided for @forgot_check_mailbox_title.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź skrzynkę'**
  String get forgot_check_mailbox_title;

  /// No description provided for @forgot_sent_msg_prefix.
  ///
  /// In pl, this message translates to:
  /// **'Wysłaliśmy wiadomość na adres\n'**
  String get forgot_sent_msg_prefix;

  /// No description provided for @forgot_step_open_email.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz swoją skrzynkę e-mail'**
  String get forgot_step_open_email;

  /// No description provided for @forgot_step_click_link.
  ///
  /// In pl, this message translates to:
  /// **'Kliknij w link „Zresetuj hasło\"'**
  String get forgot_step_click_link;

  /// No description provided for @forgot_step_login.
  ///
  /// In pl, this message translates to:
  /// **'Ustaw nowe hasło i zaloguj się'**
  String get forgot_step_login;

  /// No description provided for @forgot_spam_check_part1.
  ///
  /// In pl, this message translates to:
  /// **'Nie widzisz wiadomości? Sprawdź folder spam. '**
  String get forgot_spam_check_part1;

  /// No description provided for @forgot_spam_check_part2.
  ///
  /// In pl, this message translates to:
  /// **'Wysyłka może potrwać do 2 minut.'**
  String get forgot_spam_check_part2;

  /// No description provided for @forgot_btn_back_to_login.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do logowania'**
  String get forgot_btn_back_to_login;

  /// No description provided for @forgot_btn_send_again.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij ponownie'**
  String get forgot_btn_send_again;

  /// No description provided for @transcript_default_speaker_label.
  ///
  /// In pl, this message translates to:
  /// **'Głos'**
  String get transcript_default_speaker_label;

  /// No description provided for @home_error_toast.
  ///
  /// In pl, this message translates to:
  /// **'Błąd: {error}'**
  String home_error_toast(String error);

  /// No description provided for @home_manage_edit_card.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj kartotekę'**
  String get home_manage_edit_card;

  /// No description provided for @home_manage_card.
  ///
  /// In pl, this message translates to:
  /// **'Zarządzaj kartoteką klienta'**
  String get home_manage_card;

  /// No description provided for @sort_filter_header_sorting.
  ///
  /// In pl, this message translates to:
  /// **'SORTOWANIE'**
  String get sort_filter_header_sorting;

  /// No description provided for @sort_filter_last_activity.
  ///
  /// In pl, this message translates to:
  /// **'Ostatnia aktywność'**
  String get sort_filter_last_activity;

  /// No description provided for @sort_filter_last_activity_desc.
  ///
  /// In pl, this message translates to:
  /// **'Klienci, z którymi ostatnio pracowałeś'**
  String get sort_filter_last_activity_desc;

  /// No description provided for @sort_filter_long_unseen.
  ///
  /// In pl, this message translates to:
  /// **'Dawno niewidziani'**
  String get sort_filter_long_unseen;

  /// No description provided for @sort_filter_no_sessions_longest_desc.
  ///
  /// In pl, this message translates to:
  /// **'Klienci bez sesji od najdłuższego czasu'**
  String get sort_filter_no_sessions_longest_desc;

  /// No description provided for @sort_filter_alphabetical.
  ///
  /// In pl, this message translates to:
  /// **'Alfabetycznie'**
  String get sort_filter_alphabetical;

  /// No description provided for @sort_filter_alphabetical_desc.
  ///
  /// In pl, this message translates to:
  /// **'Nazwy kartotek od A do Z'**
  String get sort_filter_alphabetical_desc;

  /// No description provided for @sort_filter_longest_processes.
  ///
  /// In pl, this message translates to:
  /// **'Najdłuższe procesy'**
  String get sort_filter_longest_processes;

  /// No description provided for @sort_filter_longest_processes_desc.
  ///
  /// In pl, this message translates to:
  /// **'Klienci z największą liczbą sesji'**
  String get sort_filter_longest_processes_desc;

  /// No description provided for @sort_filter_show_only.
  ///
  /// In pl, this message translates to:
  /// **'POKAŻ TYLKO'**
  String get sort_filter_show_only;

  /// No description provided for @sort_filter_new_reports.
  ///
  /// In pl, this message translates to:
  /// **'Nowe raporty i analizy'**
  String get sort_filter_new_reports;

  /// No description provided for @sort_filter_ready_reports_desc.
  ///
  /// In pl, this message translates to:
  /// **'Gotowe raporty AI lub trwające analizy'**
  String get sort_filter_ready_reports_desc;

  /// No description provided for @sort_filter_modality.
  ///
  /// In pl, this message translates to:
  /// **'MODALNOŚĆ'**
  String get sort_filter_modality;

  /// No description provided for @sort_filter_clear_filters.
  ///
  /// In pl, this message translates to:
  /// **'Wyczyść filtry'**
  String get sort_filter_clear_filters;

  /// No description provided for @editPatient_error.
  ///
  /// In pl, this message translates to:
  /// **'Błąd: {error}'**
  String editPatient_error(String error);

  /// No description provided for @activeAnalysis_uploading_status.
  ///
  /// In pl, this message translates to:
  /// **'Wgrywanie: {errors} {errors, plural, =1{błąd} few{błędy} many{błędów} other{błędów}}, {progress} w toku.'**
  String activeAnalysis_uploading_status(int errors, int progress);

  /// No description provided for @activeAnalysis_uploading_status_desc.
  ///
  /// In pl, this message translates to:
  /// **'Część plików wymaga uwagi, ale przesyłanie reszty trwa bez zakłóceń.'**
  String get activeAnalysis_uploading_status_desc;

  /// No description provided for @activeAnalysis_check_details.
  ///
  /// In pl, this message translates to:
  /// **'Sprawdź szczegóły'**
  String get activeAnalysis_check_details;

  /// No description provided for @activeAnalysis_upload_attention.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłanie wymaga uwagi.'**
  String get activeAnalysis_upload_attention;

  /// No description provided for @activeAnalysis_upload_attention_desc.
  ///
  /// In pl, this message translates to:
  /// **'Sesja nie mogła zostać wgrana. Sprawdź szczegóły.'**
  String get activeAnalysis_upload_attention_desc;

  /// No description provided for @activeAnalysis_quota_blocked_desc.
  ///
  /// In pl, this message translates to:
  /// **'Pula sesji została wyczerpana. Sesja jest bezpiecznie zapisana i zostanie przetworzona po odnowieniu planu.'**
  String get activeAnalysis_quota_blocked_desc;

  /// No description provided for @activeAnalysis_view_details.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz szczegóły'**
  String get activeAnalysis_view_details;

  /// No description provided for @activeAnalysis_upload_interrupted.
  ///
  /// In pl, this message translates to:
  /// **'Przesyłanie zostało przerwane.'**
  String get activeAnalysis_upload_interrupted;

  /// No description provided for @activeAnalysis_upload_interrupted_desc.
  ///
  /// In pl, this message translates to:
  /// **'Próba wznowienia nastąpi automatycznie. Nagranie jest bezpieczne.'**
  String get activeAnalysis_upload_interrupted_desc;

  /// No description provided for @activeAnalysis_preparing.
  ///
  /// In pl, this message translates to:
  /// **'Przygotowuję nagranie.'**
  String get activeAnalysis_preparing;

  /// No description provided for @activeAnalysis_preparing_desc.
  ///
  /// In pl, this message translates to:
  /// **'Sesja jest szyfrowana przed przesłaniem na serwer.'**
  String get activeAnalysis_preparing_desc;

  /// No description provided for @activeAnalysis_view_progress.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz postęp'**
  String get activeAnalysis_view_progress;

  /// No description provided for @activeAnalysis_converting.
  ///
  /// In pl, this message translates to:
  /// **'Konwertuję plik audio.'**
  String get activeAnalysis_converting;

  /// No description provided for @activeAnalysis_converting_desc.
  ///
  /// In pl, this message translates to:
  /// **'Format pliku wymaga konwersji. Potrwa to chwilę.'**
  String get activeAnalysis_converting_desc;

  /// No description provided for @activeAnalysis_uploading.
  ///
  /// In pl, this message translates to:
  /// **'Sesja jest przesyłana na serwer.'**
  String get activeAnalysis_uploading;

  /// No description provided for @activeAnalysis_uploading_desc.
  ///
  /// In pl, this message translates to:
  /// **'Plik trafia bezpiecznie na serwer. Możesz kontynuować pracę.'**
  String get activeAnalysis_uploading_desc;

  /// No description provided for @activeAnalysis_analyzing_desc.
  ///
  /// In pl, this message translates to:
  /// **'Sesja jest już na serwerze. Raport pojawi się za kilka minut.'**
  String get activeAnalysis_analyzing_desc;

  /// No description provided for @recording_countdown_preparing.
  ///
  /// In pl, this message translates to:
  /// **'Przygotuj się…'**
  String get recording_countdown_preparing;

  /// No description provided for @drawer_btn_logout.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj się'**
  String get drawer_btn_logout;

  /// No description provided for @drawer_btn_delete_account.
  ///
  /// In pl, this message translates to:
  /// **'Usuń konto'**
  String get drawer_btn_delete_account;

  /// No description provided for @avatar_customize_desc.
  ///
  /// In pl, this message translates to:
  /// **'Nadaj swoim klientom unikalne oznaczenia, aby szybko znaleźć ich w kartotece.'**
  String get avatar_customize_desc;

  /// No description provided for @avatar_customize_background_color.
  ///
  /// In pl, this message translates to:
  /// **'KOLOR TŁA'**
  String get avatar_customize_background_color;

  /// No description provided for @profile_edit_desc.
  ///
  /// In pl, this message translates to:
  /// **'Podaj swoje imię, nazwisko i tytuł zawodowy.'**
  String get profile_edit_desc;

  /// No description provided for @profile_edit_first_name.
  ///
  /// In pl, this message translates to:
  /// **'Imię'**
  String get profile_edit_first_name;

  /// No description provided for @profile_edit_professional_title.
  ///
  /// In pl, this message translates to:
  /// **'Tytuł zawodowy (np. mgr, Psycholog)'**
  String get profile_edit_professional_title;

  /// No description provided for @report_detail_copy_content.
  ///
  /// In pl, this message translates to:
  /// **'Skopiuj treść'**
  String get report_detail_copy_content;

  /// No description provided for @hard_delete_error.
  ///
  /// In pl, this message translates to:
  /// **'Błąd usuwania'**
  String get hard_delete_error;

  /// No description provided for @hard_delete_title.
  ///
  /// In pl, this message translates to:
  /// **'Usunięcie konta jest bezpowrotne.'**
  String get hard_delete_title;

  /// No description provided for @hard_delete_body.
  ///
  /// In pl, this message translates to:
  /// **'Skasujemy Twój profil terapeuty, wszystkie sesje, transkrypcje i raporty. Tej akcji nie można cofnąć. Jeśli jesteś pewna/pewien, wpisz słowo {word}.'**
  String hard_delete_body(String word);

  /// No description provided for @hard_delete_btn_confirm.
  ///
  /// In pl, this message translates to:
  /// **'Usuń bezpowrotnie'**
  String get hard_delete_btn_confirm;

  /// No description provided for @common_done.
  ///
  /// In pl, this message translates to:
  /// **'Gotowe'**
  String get common_done;

  /// No description provided for @addPatient_additional_data_title.
  ///
  /// In pl, this message translates to:
  /// **'Dodatkowe dane'**
  String get addPatient_additional_data_title;

  /// No description provided for @addPatient_customize_label_title.
  ///
  /// In pl, this message translates to:
  /// **'Spersonalizuj oznaczenie'**
  String get addPatient_customize_label_title;

  /// No description provided for @addPatient_avatar_format_hint.
  ///
  /// In pl, this message translates to:
  /// **'Litery, cyfry lub emoji (max 2)'**
  String get addPatient_avatar_format_hint;

  /// No description provided for @clientDetails_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Nad czym dzisiaj pracujemy?'**
  String get clientDetails_subtitle;

  /// No description provided for @clientDetails_upload_file_btn.
  ///
  /// In pl, this message translates to:
  /// **'WGRAJ PLIK Z DYSKU'**
  String get clientDetails_upload_file_btn;

  /// No description provided for @clientDetails_record_btn.
  ///
  /// In pl, this message translates to:
  /// **'ROZPOCZNIJ NAGRYWANIE'**
  String get clientDetails_record_btn;

  /// No description provided for @clientDetails_status_processing.
  ///
  /// In pl, this message translates to:
  /// **'W trakcie przetwarzania…'**
  String get clientDetails_status_processing;

  /// No description provided for @clientDetails_status_queued.
  ///
  /// In pl, this message translates to:
  /// **'W kolejce…'**
  String get clientDetails_status_queued;

  /// No description provided for @clientDetails_status_processing_audio.
  ///
  /// In pl, this message translates to:
  /// **'Przetwarzanie audio…'**
  String get clientDetails_status_processing_audio;

  /// No description provided for @clientDetails_status_finalizing.
  ///
  /// In pl, this message translates to:
  /// **'Finalizowanie sesji…'**
  String get clientDetails_status_finalizing;

  /// No description provided for @home_delete_error_toast.
  ///
  /// In pl, this message translates to:
  /// **'Błąd usunięcia: {error}'**
  String home_delete_error_toast(String error);

  /// No description provided for @report_btn_copy_summary.
  ///
  /// In pl, this message translates to:
  /// **'Kopiuj podsumowanie'**
  String get report_btn_copy_summary;

  /// No description provided for @report_btn_edit_summary.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj podsumowanie'**
  String get report_btn_edit_summary;

  /// No description provided for @report_toast_summary_copied.
  ///
  /// In pl, this message translates to:
  /// **'Podsumowanie skopiowane'**
  String get report_toast_summary_copied;

  /// No description provided for @report_toast_summary_updated.
  ///
  /// In pl, this message translates to:
  /// **'Podsumowanie zaktualizowane'**
  String get report_toast_summary_updated;

  /// No description provided for @report_edit_summary_title.
  ///
  /// In pl, this message translates to:
  /// **'Edycja podsumowania'**
  String get report_edit_summary_title;

  /// No description provided for @report_edit_summary_hint.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj podsumowanie sesji...'**
  String get report_edit_summary_hint;

  /// No description provided for @report_toast_reports_copied.
  ///
  /// In pl, this message translates to:
  /// **'Raporty skopiowane do schowka'**
  String get report_toast_reports_copied;

  /// No description provided for @report_tooltip_copy_reports.
  ///
  /// In pl, this message translates to:
  /// **'Skopiuj raporty'**
  String get report_tooltip_copy_reports;

  /// No description provided for @report_toast_section_copied.
  ///
  /// In pl, this message translates to:
  /// **'Sekcja skopiowana do schowka'**
  String get report_toast_section_copied;

  /// No description provided for @report_edit_section_title.
  ///
  /// In pl, this message translates to:
  /// **'Edycja sekcji'**
  String get report_edit_section_title;

  /// No description provided for @report_toast_section_updated.
  ///
  /// In pl, this message translates to:
  /// **'Sekcja zaktualizowana'**
  String get report_toast_section_updated;

  /// No description provided for @menu_avatar_camera.
  ///
  /// In pl, this message translates to:
  /// **'Aparat'**
  String get menu_avatar_camera;

  /// No description provided for @menu_avatar_gallery.
  ///
  /// In pl, this message translates to:
  /// **'Galeria'**
  String get menu_avatar_gallery;

  /// No description provided for @common_or.
  ///
  /// In pl, this message translates to:
  /// **'lub'**
  String get common_or;

  /// No description provided for @activeAnalysis_analyzing.
  ///
  /// In pl, this message translates to:
  /// **'Analiza w toku.'**
  String get activeAnalysis_analyzing;

  /// No description provided for @activeAnalysis_processing.
  ///
  /// In pl, this message translates to:
  /// **'Przetwarzanie sesji.'**
  String get activeAnalysis_processing;

  /// No description provided for @activeAnalysis_processing_desc.
  ///
  /// In pl, this message translates to:
  /// **'Twoja sesja przechodzi kolejne etapy analizy.'**
  String get activeAnalysis_processing_desc;

  /// No description provided for @profile_edit_title.
  ///
  /// In pl, this message translates to:
  /// **'Edytuj profil.'**
  String get profile_edit_title;

  /// No description provided for @profile_edit_last_name.
  ///
  /// In pl, this message translates to:
  /// **'Nazwisko (opcjonalne)'**
  String get profile_edit_last_name;

  /// No description provided for @profile_title_suggestion_1.
  ///
  /// In pl, this message translates to:
  /// **'mgr'**
  String get profile_title_suggestion_1;

  /// No description provided for @profile_title_suggestion_2.
  ///
  /// In pl, this message translates to:
  /// **'dr'**
  String get profile_title_suggestion_2;

  /// No description provided for @profile_title_suggestion_3.
  ///
  /// In pl, this message translates to:
  /// **'dr hab.'**
  String get profile_title_suggestion_3;

  /// No description provided for @profile_title_suggestion_4.
  ///
  /// In pl, this message translates to:
  /// **'prof.'**
  String get profile_title_suggestion_4;

  /// No description provided for @profile_title_suggestion_5.
  ///
  /// In pl, this message translates to:
  /// **'Psycholog'**
  String get profile_title_suggestion_5;

  /// No description provided for @profile_title_suggestion_6.
  ///
  /// In pl, this message translates to:
  /// **'Psychoterapeuta'**
  String get profile_title_suggestion_6;

  /// No description provided for @profile_title_suggestion_7.
  ///
  /// In pl, this message translates to:
  /// **'Terapeuta'**
  String get profile_title_suggestion_7;

  /// No description provided for @profile_title_suggestion_8.
  ///
  /// In pl, this message translates to:
  /// **'Psychiatra'**
  String get profile_title_suggestion_8;

  /// No description provided for @profile_title_suggestion_9.
  ///
  /// In pl, this message translates to:
  /// **'Coach'**
  String get profile_title_suggestion_9;

  /// No description provided for @clientDetails_status_requires_attention.
  ///
  /// In pl, this message translates to:
  /// **'Wymaga uwagi'**
  String get clientDetails_status_requires_attention;

  /// No description provided for @clientDetails_status_processing_label.
  ///
  /// In pl, this message translates to:
  /// **'Przetwarzanie'**
  String get clientDetails_status_processing_label;

  /// No description provided for @clientDetails_status_new_session.
  ///
  /// In pl, this message translates to:
  /// **'Nowa sesja'**
  String get clientDetails_status_new_session;

  /// No description provided for @clientDetails_status_waiting_audio.
  ///
  /// In pl, this message translates to:
  /// **'Oczekiwanie na audio…'**
  String get clientDetails_status_waiting_audio;

  /// No description provided for @clientDetails_status_ready.
  ///
  /// In pl, this message translates to:
  /// **'Gotowy'**
  String get clientDetails_status_ready;

  /// No description provided for @clientDetails_status_new_report.
  ///
  /// In pl, this message translates to:
  /// **'Nowy raport'**
  String get clientDetails_status_new_report;

  /// No description provided for @clientDetails_status_analyzing.
  ///
  /// In pl, this message translates to:
  /// **'AI analizuje…'**
  String get clientDetails_status_analyzing;

  /// No description provided for @clientDetails_status_uploading_label.
  ///
  /// In pl, this message translates to:
  /// **'Wgrywanie…'**
  String get clientDetails_status_uploading_label;

  /// No description provided for @clientDetails_status_error.
  ///
  /// In pl, this message translates to:
  /// **'Błąd analizy'**
  String get clientDetails_status_error;

  /// No description provided for @clientDetails_session_title.
  ///
  /// In pl, this message translates to:
  /// **'Sesja'**
  String get clientDetails_session_title;

  /// No description provided for @cancelUpload_warning_text.
  ///
  /// In pl, this message translates to:
  /// **'Ta sesja jest w trakcie analizy. Usunięcie jej oznacza bezpowrotną utratę nagrania i transkrypcji. Nie będzie można tego cofnąć.'**
  String get cancelUpload_warning_text;

  /// No description provided for @cancelUpload_delete_btn.
  ///
  /// In pl, this message translates to:
  /// **'Usuń z analizy'**
  String get cancelUpload_delete_btn;

  /// No description provided for @cancelUpload_confirm_title.
  ///
  /// In pl, this message translates to:
  /// **'Na pewno?'**
  String get cancelUpload_confirm_title;

  /// No description provided for @cancelUpload_confirm_body.
  ///
  /// In pl, this message translates to:
  /// **'Tej operacji nie można cofnąć. Nagranie i transkrypcja zostaną trwale usunięte.'**
  String get cancelUpload_confirm_body;

  /// No description provided for @cancelUpload_back_btn.
  ///
  /// In pl, this message translates to:
  /// **'Wróć'**
  String get cancelUpload_back_btn;

  /// No description provided for @forgot_password_link_expiry.
  ///
  /// In pl, this message translates to:
  /// **'Link wygasa po 1 godzinie'**
  String get forgot_password_link_expiry;

  /// No description provided for @home_report_ready_toast.
  ///
  /// In pl, this message translates to:
  /// **'Raport gotowy, {name} 🎉'**
  String home_report_ready_toast(String name);

  /// No description provided for @appLock_title.
  ///
  /// In pl, this message translates to:
  /// **'Aplikacja zablokowana'**
  String get appLock_title;

  /// No description provided for @appLock_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Odblokuj, aby uzyskać dostęp do kartotek'**
  String get appLock_subtitle;

  /// No description provided for @appLock_unlock.
  ///
  /// In pl, this message translates to:
  /// **'Odblokuj'**
  String get appLock_unlock;

  /// No description provided for @appLock_reason.
  ///
  /// In pl, this message translates to:
  /// **'Uwierzytelnij się, aby uzyskać dostęp do Superwizora'**
  String get appLock_reason;

  /// No description provided for @recording_reminder_toast.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywanie wciąż trwa — {duration}'**
  String recording_reminder_toast(String duration);

  /// No description provided for @recording_autopause_remaining.
  ///
  /// In pl, this message translates to:
  /// **'Auto-pauza za {time}'**
  String recording_autopause_remaining(String time);

  /// No description provided for @settings_recording_section.
  ///
  /// In pl, this message translates to:
  /// **'Nagrywanie'**
  String get settings_recording_section;

  /// No description provided for @settings_recording_autopause.
  ///
  /// In pl, this message translates to:
  /// **'Automatyczna pauza'**
  String get settings_recording_autopause;

  /// No description provided for @settings_recording_autopause_value.
  ///
  /// In pl, this message translates to:
  /// **'{minutes} min'**
  String settings_recording_autopause_value(int minutes);

  /// No description provided for @settings_recording_reminder.
  ///
  /// In pl, this message translates to:
  /// **'Przypomnienie o nagrywaniu'**
  String get settings_recording_reminder;

  /// No description provided for @settings_recording_reminder_off.
  ///
  /// In pl, this message translates to:
  /// **'Wyłączone'**
  String get settings_recording_reminder_off;

  /// No description provided for @settings_recording_reminder_sound.
  ///
  /// In pl, this message translates to:
  /// **'Dźwięk przypomnienia'**
  String get settings_recording_reminder_sound;

  /// No description provided for @settings_recording_reminder_sound_warning.
  ///
  /// In pl, this message translates to:
  /// **'Dźwięk zostanie nagrany w sesji'**
  String get settings_recording_reminder_sound_warning;

  /// No description provided for @settings_recording_reminder_sound_hint.
  ///
  /// In pl, this message translates to:
  /// **'Gdy przypomnienie jest włączone, odtworzy się też dźwięk (nagrywany również w sesji).'**
  String get settings_recording_reminder_sound_hint;

  /// No description provided for @deactivated_title.
  ///
  /// In pl, this message translates to:
  /// **'Konto nieaktywne'**
  String get deactivated_title;

  /// No description provided for @deactivated_body.
  ///
  /// In pl, this message translates to:
  /// **'Twoje konto zostało dezaktywowane przez administratora organizacji. Skontaktuj się z nim, aby przywrócić dostęp.'**
  String get deactivated_body;

  /// No description provided for @deactivated_logout.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj się'**
  String get deactivated_logout;

  /// No description provided for @client_home_title.
  ///
  /// In pl, this message translates to:
  /// **'Twoje sesje'**
  String get client_home_title;

  /// No description provided for @client_home_subtitle.
  ///
  /// In pl, this message translates to:
  /// **'Materiały udostępnione przez terapeutę i Twoje notatki.'**
  String get client_home_subtitle;

  /// No description provided for @client_home_empty.
  ///
  /// In pl, this message translates to:
  /// **'Twój terapeuta nie udostępnił jeszcze żadnych materiałów.'**
  String get client_home_empty;

  /// No description provided for @client_home_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się załadować danych: {error}'**
  String client_home_error(String error);

  /// No description provided for @client_kartoteka_therapist.
  ///
  /// In pl, this message translates to:
  /// **'Terapeuta: {name}'**
  String client_kartoteka_therapist(String name);

  /// No description provided for @client_kartoteka_counts.
  ///
  /// In pl, this message translates to:
  /// **'{sessions} sesji · {notes} notatek'**
  String client_kartoteka_counts(int sessions, int notes);

  /// No description provided for @client_unread_badge.
  ///
  /// In pl, this message translates to:
  /// **'{count} nowe'**
  String client_unread_badge(int count);

  /// No description provided for @client_tab_sessions.
  ///
  /// In pl, this message translates to:
  /// **'Sesje'**
  String get client_tab_sessions;

  /// No description provided for @client_tab_notes.
  ///
  /// In pl, this message translates to:
  /// **'Notatki'**
  String get client_tab_notes;

  /// No description provided for @client_sessions_empty.
  ///
  /// In pl, this message translates to:
  /// **'Brak udostępnionych sesji.'**
  String get client_sessions_empty;

  /// No description provided for @client_session_title.
  ///
  /// In pl, this message translates to:
  /// **'Sesja {number}'**
  String client_session_title(int number);

  /// No description provided for @client_session_no_transcript.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcja nie jest jeszcze dostępna.'**
  String get client_session_no_transcript;

  /// No description provided for @client_notes_empty.
  ///
  /// In pl, this message translates to:
  /// **'Brak notatek. Utwórz pierwszą i wyślij ją terapeucie.'**
  String get client_notes_empty;

  /// No description provided for @client_note_from_therapist.
  ///
  /// In pl, this message translates to:
  /// **'Od terapeuty'**
  String get client_note_from_therapist;

  /// No description provided for @client_note_mine.
  ///
  /// In pl, this message translates to:
  /// **'Moja notatka'**
  String get client_note_mine;

  /// No description provided for @client_note_new.
  ///
  /// In pl, this message translates to:
  /// **'Nowa notatka'**
  String get client_note_new;

  /// No description provided for @client_note_title_hint.
  ///
  /// In pl, this message translates to:
  /// **'Tytuł'**
  String get client_note_title_hint;

  /// No description provided for @client_note_text_hint.
  ///
  /// In pl, this message translates to:
  /// **'Twoje przemyślenia…'**
  String get client_note_text_hint;

  /// No description provided for @client_note_send.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij do terapeuty'**
  String get client_note_send;

  /// No description provided for @client_note_sent.
  ///
  /// In pl, this message translates to:
  /// **'Notatka wysłana do terapeuty.'**
  String get client_note_sent;

  /// No description provided for @client_note_empty_error.
  ///
  /// In pl, this message translates to:
  /// **'Notatka nie może być pusta.'**
  String get client_note_empty_error;

  /// No description provided for @client_logout.
  ///
  /// In pl, this message translates to:
  /// **'Wyloguj się'**
  String get client_logout;

  /// No description provided for @invite_client_title.
  ///
  /// In pl, this message translates to:
  /// **'Zaproś klienta'**
  String get invite_client_title;

  /// No description provided for @invite_client_desc.
  ///
  /// In pl, this message translates to:
  /// **'Klient otrzyma e-mail z linkiem do bezpiecznego panelu, w którym zobaczy udostępnione sesje i notatki oraz będzie mógł pisać do Ciebie notatki.'**
  String get invite_client_desc;

  /// No description provided for @invite_client_email_label.
  ///
  /// In pl, this message translates to:
  /// **'E-mail klienta'**
  String get invite_client_email_label;

  /// No description provided for @invite_client_send.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij zaproszenie'**
  String get invite_client_send;

  /// No description provided for @invite_client_resend.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij ponownie'**
  String get invite_client_resend;

  /// No description provided for @invite_client_sent.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenie wysłane.'**
  String get invite_client_sent;

  /// No description provided for @invite_client_status_pending.
  ///
  /// In pl, this message translates to:
  /// **'Zaproszenie oczekuje — wysłane na {email}, ważne do {date}.'**
  String invite_client_status_pending(String email, String date);

  /// No description provided for @invite_client_status_active.
  ///
  /// In pl, this message translates to:
  /// **'Panel klienta jest aktywny.'**
  String get invite_client_status_active;

  /// No description provided for @invite_client_status_inactive.
  ///
  /// In pl, this message translates to:
  /// **'Konto klienta jest dezaktywowane.'**
  String get invite_client_status_inactive;

  /// No description provided for @invite_client_email_taken.
  ///
  /// In pl, this message translates to:
  /// **'Ten e-mail jest już powiązany z innym kontem.'**
  String get invite_client_email_taken;

  /// No description provided for @invite_client_email_missing.
  ///
  /// In pl, this message translates to:
  /// **'Podaj poprawny e-mail klienta.'**
  String get invite_client_email_missing;

  /// No description provided for @invite_client_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wysłać zaproszenia. Spróbuj ponownie.'**
  String get invite_client_error;

  /// No description provided for @share_with_client.
  ///
  /// In pl, this message translates to:
  /// **'Udostępnij w panelu klienta'**
  String get share_with_client;

  /// No description provided for @unshare_with_client.
  ///
  /// In pl, this message translates to:
  /// **'Cofnij udostępnienie'**
  String get unshare_with_client;

  /// No description provided for @share_with_client_desc.
  ///
  /// In pl, this message translates to:
  /// **'Klient zobaczy tę pozycję w swoim panelu'**
  String get share_with_client_desc;

  /// No description provided for @share_note_shared_at.
  ///
  /// In pl, this message translates to:
  /// **'Udostępniono {date}'**
  String share_note_shared_at(String date);

  /// No description provided for @share_shared_badge.
  ///
  /// In pl, this message translates to:
  /// **'Udostępniono'**
  String get share_shared_badge;

  /// No description provided for @share_session_label.
  ///
  /// In pl, this message translates to:
  /// **'Udostępnij klientowi'**
  String get share_session_label;

  /// No description provided for @share_toggled_on.
  ///
  /// In pl, this message translates to:
  /// **'Udostępniono w panelu klienta.'**
  String get share_toggled_on;

  /// No description provided for @share_toggled_off.
  ///
  /// In pl, this message translates to:
  /// **'Cofnięto udostępnienie.'**
  String get share_toggled_off;

  /// No description provided for @share_toggle_error.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się zmienić udostępniania.'**
  String get share_toggle_error;

  /// No description provided for @note_from_client.
  ///
  /// In pl, this message translates to:
  /// **'Od klienta'**
  String get note_from_client;

  /// No description provided for @note_from_client_new.
  ///
  /// In pl, this message translates to:
  /// **'NOWA'**
  String get note_from_client_new;

  /// No description provided for @home_menu_invite_client_desc.
  ///
  /// In pl, this message translates to:
  /// **'Wyślij e-mail z dostępem do panelu klienta'**
  String get home_menu_invite_client_desc;

  /// No description provided for @client_new_badge.
  ///
  /// In pl, this message translates to:
  /// **'NOWA'**
  String get client_new_badge;

  /// No description provided for @client_session_transcript_chip.
  ///
  /// In pl, this message translates to:
  /// **'Transkrypcja'**
  String get client_session_transcript_chip;

  /// No description provided for @account_deleted_title.
  ///
  /// In pl, this message translates to:
  /// **'Konto zablokowane'**
  String get account_deleted_title;

  /// No description provided for @account_deleted_body.
  ///
  /// In pl, this message translates to:
  /// **'To konto terapeuty zostało zablokowane przez administratora Superwizor AI. Skontaktuj się z pomocą, jeśli uważasz, że to pomyłka.'**
  String get account_deleted_body;

  /// No description provided for @account_not_found_title.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono konta'**
  String get account_not_found_title;

  /// No description provided for @account_not_found_body.
  ///
  /// In pl, this message translates to:
  /// **'Zalogowano jako {email}, ale to konto nie jest zarejestrowane w Superwizor AI. Jeśli otrzymałeś zaproszenie (terapeuta, manager lub klient), otwórz link z wiadomości e-mail. Konto terapeuty założysz na superwizor.ai.'**
  String account_not_found_body(String email);

  /// No description provided for @client_note_save.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz'**
  String get client_note_save;

  /// No description provided for @client_note_save_and_send.
  ///
  /// In pl, this message translates to:
  /// **'Zapisz i wyślij do terapeuty'**
  String get client_note_save_and_send;

  /// No description provided for @client_note_saved_draft.
  ///
  /// In pl, this message translates to:
  /// **'Notatka zapisana w panelu.'**
  String get client_note_saved_draft;

  /// No description provided for @client_note_mine_draft.
  ///
  /// In pl, this message translates to:
  /// **'Szkic (tylko dla Ciebie)'**
  String get client_note_mine_draft;

  /// No description provided for @client_note_mine_sent.
  ///
  /// In pl, this message translates to:
  /// **'Wysłana do terapeuty'**
  String get client_note_mine_sent;

  /// No description provided for @client_note_draft_badge.
  ///
  /// In pl, this message translates to:
  /// **'SZKIC'**
  String get client_note_draft_badge;

  /// No description provided for @client_note_close.
  ///
  /// In pl, this message translates to:
  /// **'Zamknij'**
  String get client_note_close;

  /// No description provided for @client_session_add_note.
  ///
  /// In pl, this message translates to:
  /// **'Dodaj notatkę do sesji'**
  String get client_session_add_note;
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
