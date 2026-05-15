// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Superwizor AI';

  @override
  String get common_understand => 'I understand.';

  @override
  String get common_back => 'Back.';

  @override
  String get common_cancel => 'Cancel.';

  @override
  String get common_continue => 'Continue.';

  @override
  String get common_save => 'Save.';

  @override
  String get common_retry => 'Retry.';

  @override
  String get common_loading => 'Loading…';

  @override
  String get common_error => 'An error occurred.';

  @override
  String get connectivity_offline_banner =>
      'No connection. Some features are limited.';

  @override
  String get auth_login_title => 'Sign In.';

  @override
  String get auth_email_label => 'Email Address';

  @override
  String get auth_password_label => 'Password';

  @override
  String get auth_login_primary => 'Sign In.';

  @override
  String get auth_register_primary => 'Create Account.';

  @override
  String get auth_toggle_to_register => 'No account? Create one.';

  @override
  String get auth_toggle_to_login => 'Already have an account? Sign in.';

  @override
  String get auth_forgot_password => 'Forgot password.';

  @override
  String get auth_password_reset_sent_title => 'Password reset link sent.';

  @override
  String get auth_password_reset_sent_body =>
      'We have sent a password reset link to your email.';

  @override
  String get auth_error_invalid_credential => 'Invalid email or password.';

  @override
  String get auth_error_email_already_in_use =>
      'Account with this email already exists. Sign in.';

  @override
  String get auth_error_weak_password =>
      'Password is too short. Use at least 6 characters.';

  @override
  String get auth_error_invalid_email => 'Invalid email format.';

  @override
  String get auth_error_network => 'No internet connection. Try again.';

  @override
  String get auth_error_too_many_requests =>
      'Too many login attempts. Please wait and try again.';

  @override
  String get auth_error_user_disabled =>
      'This account has been disabled. Contact support.';

  @override
  String get auth_error_generic => 'A login error occurred. Try again.';

  @override
  String get setup_title => 'Set up your profile.';

  @override
  String get setup_subtitle =>
      'Tell us how you work, we\'ll tailor the analysis to it.';

  @override
  String get setup_modality_label => 'Primary therapy modality';

  @override
  String get setup_language_label => 'Session language';

  @override
  String get setup_continue => 'Continue.';

  @override
  String get language_popup_title => 'App language.';

  @override
  String get language_popup_body => 'Language successfully changed.';

  @override
  String get modality_integrative => 'Universal / Integrative';

  @override
  String get modality_cbt => 'Cognitive-Behavioral (CBT)';

  @override
  String get modality_psychodynamic => 'Psychodynamic';

  @override
  String get modality_positive => 'Positive (PPT)';

  @override
  String get modality_schema => 'Schema Therapy (ST)';

  @override
  String get modality_systemic => 'Systemic (Couples/Families)';

  @override
  String get modality_eft => 'Emotionally Focused (EFT)';

  @override
  String get modality_coaching => 'Coaching (ICF/GROW)';

  @override
  String get modality_sheet_title => 'Choose your approach';

  @override
  String get modality_sheet_subtitle =>
      'This affects how your reports are generated. You can change it anytime.';

  @override
  String get addPatient_title => 'New Patient.';

  @override
  String get addPatient_first_name_label => 'Patient\'s first name (required)';

  @override
  String get addPatient_last_name_label => 'Patient\'s last name (optional)';

  @override
  String get addPatient_modality_label =>
      'Session modality (inherited from profile)';

  @override
  String get addPatient_language_label => 'Session language';

  @override
  String get addPatient_consent_label =>
      'I declare that the patient consented to recording and data processing according to the Privacy Policy and DPA of Superwizor AI.';

  @override
  String get addPatient_consent_link_label => 'View DPA document.';

  @override
  String get addPatient_save_primary => 'Save patient.';

  @override
  String get addPatient_no_consent_header => 'No consent to record.';

  @override
  String get addPatient_no_consent_body =>
      'We cannot start a session without explicit patient consent. Data protection laws require this.';

  @override
  String get addPatient_no_consent_primary => 'I understand.';

  @override
  String get editPatient_title => 'Edit patient details.';

  @override
  String get editPatient_save_primary => 'Save changes.';

  @override
  String get editPatient_erase_destructive => 'Erase patient permanently';

  @override
  String get editPatient_erase_confirm_header => 'Permanent erasure';

  @override
  String get editPatient_erase_confirm_body =>
      'This action permanently deletes the patient and ALL their sessions and transcripts (GDPR right to be forgotten). This cannot be undone.';

  @override
  String get addSession_title => 'New Session.';

  @override
  String get addSession_subtitle => 'Choose modality for this session:';

  @override
  String get home_title => 'Your Patients.';

  @override
  String get home_empty_title => 'You don\'t have any patients yet.';

  @override
  String get home_empty_body => 'Add a patient to start your first session.';

  @override
  String get home_add_patient_fab => 'Add patient';

  @override
  String get patient_no_sessions => 'No sessions.';

  @override
  String get patient_start_session => 'Start recording session.';

  @override
  String patient_session_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
      zero: 'No sessions',
    );
    return '$_temp0';
  }

  @override
  String get recording_screen_title => 'Session in progress.';

  @override
  String get recording_instructions_title => 'How to record best?';

  @override
  String get recording_instruction_1 =>
      'Do not lock the screen while recording.';

  @override
  String get recording_instruction_2 =>
      'Place the phone on a table, between speakers (50–100 cm distance).';

  @override
  String get recording_instruction_3 =>
      'Point the microphone towards the conversation, do not cover it.';

  @override
  String get recording_instruction_4 =>
      'Quiet environment – close windows/doors, turn off noise sources.';

  @override
  String get recording_instruction_5 =>
      'For video conferences (e.g. Google Meet, Zoom), always use a secondary device to record.';

  @override
  String get recording_status_recording => 'Recording in progress.';

  @override
  String get recording_status_paused => 'Recording paused.';

  @override
  String get recording_mic_denied_header => 'No microphone access.';

  @override
  String get recording_mic_denied_body =>
      'To record a session, enable microphone access in system settings. Go to Settings → Superwizor → Microphone.';

  @override
  String get recording_mic_denied_open_settings => 'Open settings.';

  @override
  String get recording_mic_denied_cancel => 'Back.';

  @override
  String get recording_discard_confirm_header => 'Exit recording?';

  @override
  String get recording_discard_confirm_body =>
      'Recording is in progress. If you exit, the session will be permanently deleted.';

  @override
  String get recording_discard_confirm_destructive =>
      'Exit and delete recording.';

  @override
  String get recording_discard_confirm_secondary => 'Return to recording.';

  @override
  String get recording_button_start => 'Start recording.';

  @override
  String get recording_button_pause => 'Pause.';

  @override
  String get recording_button_resume => 'Resume.';

  @override
  String get recording_button_stop => 'End.';

  @override
  String get recording_too_short_header => 'Recording is too short.';

  @override
  String get recording_too_short_body =>
      'A session cannot be shorter than 5 minutes for the AI to draw reliable conclusions. Recording is still running.';

  @override
  String get recording_too_short_primary => 'Continue recording.';

  @override
  String get recording_too_short_destructive => 'End without saving.';

  @override
  String get recording_confirm_end_header => 'End and analyze session.';

  @override
  String get recording_confirm_end_body =>
      'The audio file is secured. Do you want to close the recording now and submit it for secure analysis?';

  @override
  String get recording_confirm_end_primary => 'Start session analysis.';

  @override
  String get recording_confirm_end_secondary => 'Return to recording.';

  @override
  String get recording_confirm_end_destructive =>
      'Delete this recording permanently.';

  @override
  String get recording_max_duration_header => 'Recording time limit reached.';

  @override
  String get recording_max_duration_body =>
      'The session reached the maximum allowed time of 130 minutes and was safely stopped. Submit it now for analysis or delete it if this was a test recording.';

  @override
  String get recording_max_duration_primary => 'Start session analysis.';

  @override
  String get recording_max_duration_destructive =>
      'Delete this recording permanently.';

  @override
  String get recording_pending_upload_header =>
      'We have your unfinished recording.';

  @override
  String recording_pending_upload_body(String date) {
    return 'The session from $date hit the 130 minutes limit. The recording is safely stored on your device and waiting to be submitted for analysis.';
  }

  @override
  String get recording_pending_upload_primary => 'Submit for analysis.';

  @override
  String get recording_pending_upload_destructive =>
      'Delete this recording permanently.';

  @override
  String get stepper_step1_uploaded => 'Audio safely on our servers.';

  @override
  String get stepper_step2_transcribing => 'Creating transcription.';

  @override
  String get stepper_step3_analyzing => 'AI is preparing clinical insights.';

  @override
  String get stepper_step4_finalizing =>
      'Compiling insights into a readable report.';

  @override
  String get stepper_step5_done =>
      'Process complete. We have prepared your report.';

  @override
  String get session_failed_header => 'Failed to prepare report.';

  @override
  String get session_failed_body =>
      'Something went wrong during analysis. We will retry automatically. If the problem persists, contact technical support.';

  @override
  String get session_failed_primary => 'Contact support.';

  @override
  String get session_loading =>
      'Transcription is preparing. You can return here shortly.';

  @override
  String get session_load_error_header => 'Failed to load session.';

  @override
  String get session_load_error_body =>
      'Something failed on our end. Please try again shortly.';

  @override
  String get transcript_tab => 'Transcript';

  @override
  String get report_tab => 'Report';

  @override
  String get transcript_filter_all => 'All';

  @override
  String get transcript_search_hint => 'Search in transcript…';

  @override
  String get transcript_low_confidence_tooltip =>
      'Low transcription confidence in this segment. You can playback to verify.';

  @override
  String get transcript_segment_unknown_speaker => '—';

  @override
  String get transcript_actions_copy => 'Copy quote.';

  @override
  String get transcript_actions_copy_with_timestamp =>
      'Copy quote with timestamp.';

  @override
  String get transcript_actions_play_from_here => 'Play from here.';

  @override
  String get transcript_actions_export => 'Export transcript to PDF.';

  @override
  String get transcript_export_phi_header => 'Exporting sensitive data.';

  @override
  String get transcript_export_phi_body =>
      'This document contains a therapy session transcript. Do not share it via unencrypted email or messengers without an E2E layer.';

  @override
  String get transcript_export_phi_primary => 'I understand, export.';

  @override
  String get transcript_export_phi_secondary => 'Cancel.';

  @override
  String get transcript_pdf_title => 'Session transcript';

  @override
  String transcript_pdf_meta_patient(String name) {
    return 'Patient: $name';
  }

  @override
  String transcript_pdf_meta_date(String date) {
    return 'Session date: $date';
  }

  @override
  String transcript_pdf_meta_duration(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get transcript_pdf_footer =>
      'Generated by Superwizor AI · Document contains sensitive patient data.';

  @override
  String get report_section_summary => 'Session Summary';

  @override
  String get report_section_themes => 'Main Themes';

  @override
  String get report_section_alliance => 'Therapeutic Alliance';

  @override
  String get report_section_interventions => 'Observed Interventions';

  @override
  String get report_section_hitop => 'HiTOP Dimensions';

  @override
  String get report_section_risk => 'Risk Assessment';

  @override
  String get report_section_recommendations =>
      'Recommendations for Next Session';

  @override
  String get report_empty_themes =>
      'No main themes identified in this session.';

  @override
  String get report_empty_interventions =>
      'No therapeutic interventions identified.';

  @override
  String get report_empty_recommendations => 'No recommendations.';

  @override
  String get report_empty_hitop => 'No HiTOP measurements in this session.';

  @override
  String get risk_level_high => 'High Risk';

  @override
  String get risk_level_moderate => 'Moderate Risk';

  @override
  String get risk_level_low => 'Low Risk';

  @override
  String get risk_level_none => 'No Risk Signals';

  @override
  String get drawer_profile => 'My Profile';

  @override
  String get drawer_language => 'App Language';

  @override
  String get drawer_modalities => 'Therapy Modalities';

  @override
  String get drawer_legal_terms => 'Terms of Service';

  @override
  String get drawer_legal_dpa => 'DPA / GDPR';

  @override
  String get drawer_about => 'About App';

  @override
  String get drawer_logout => 'Sign Out.';

  @override
  String get drawer_delete_account => 'Delete Account.';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_subtitle => 'CUSTOMIZE YOUR EXPERIENCE';

  @override
  String get settings_section_account => 'YOUR ACCOUNT';

  @override
  String settings_logged_in_as(String email) {
    return 'Logged in as: $email';
  }

  @override
  String get settings_name => 'Name';

  @override
  String get settings_email => 'Email';

  @override
  String get settings_avatar => 'Profile picture';

  @override
  String get settings_modality => 'Default therapy modality';

  @override
  String get settings_section_preferences => 'PREFERENCES';

  @override
  String get settings_sounds => 'Sounds';

  @override
  String get settings_sounds_on => 'Sounds enabled';

  @override
  String get settings_sounds_off => 'Sounds disabled';

  @override
  String get settings_haptics => 'Haptics';

  @override
  String get settings_haptics_on => 'Haptics enabled';

  @override
  String get settings_haptics_off => 'Haptics disabled';

  @override
  String get settings_language => 'App language';

  @override
  String get settings_section_support => 'SUPPORT';

  @override
  String get settings_contact => 'Contact us';

  @override
  String get settings_waitlist => 'Waitlist';

  @override
  String get settings_section_legal => 'LEGAL INFORMATION';

  @override
  String get settings_terms => 'Terms of Service';

  @override
  String get settings_privacy => 'Privacy Policy';

  @override
  String get settings_dpa => 'DPA / GDPR';

  @override
  String get settings_licenses => 'Software licenses';

  @override
  String get settings_section_account_management => 'ACCOUNT MANAGEMENT';

  @override
  String get settings_logout => 'Sign out';

  @override
  String get settings_delete_account => 'Delete account permanently';

  @override
  String get settings_logout_confirm_title => 'Sign out?';

  @override
  String get settings_logout_confirm_body =>
      'You will need to sign in again to access your patients.';

  @override
  String get settings_logout_confirm_cancel => 'Stay';

  @override
  String get settings_logout_confirm_logout => 'Sign out';

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
  String get settings_language_app => 'App language';

  @override
  String get settings_delete_confirm_title =>
      'Are you sure you want\nto delete your account?';

  @override
  String get settings_delete_confirm_body =>
      'This action is IRREVERSIBLE.\nYou will lose all clinical documentation and patient data.';

  @override
  String get settings_delete_confirm_proceed => 'I understand — proceed.';

  @override
  String get settings_delete_confirm_cancel => 'Cancel — keep my account.';

  @override
  String get settings_choose_language => 'Choose language';

  @override
  String get delete_account_title => 'Delete account';

  @override
  String get delete_account_consequence_1 =>
      'All clinical documentation — all patients, records, sessions, and AI reports — will be permanently deleted.';

  @override
  String get delete_account_consequence_2 =>
      'Your subscription (if you have one) will not be automatically canceled. You must cancel it separately in the App Store or Google Play.';

  @override
  String get delete_account_consequence_3 =>
      'You will not be able to recover your data after completing this process. The operation is irreversible.';

  @override
  String get delete_account_toggle_text =>
      'I understand the consequences\nand want to delete my account';

  @override
  String get delete_account_button => 'Delete my account';

  @override
  String get delete_account_sheet_title => 'Final step.';

  @override
  String get delete_account_sheet_subtitle => 'To confirm, type:';

  @override
  String get delete_account_sheet_hint => 'type here…';

  @override
  String get delete_account_sheet_button => 'DELETE ACCOUNT';

  @override
  String get delete_account_sheet_cancel => 'Cancel.';

  @override
  String get delete_account_relogin_error =>
      'Please log in again to delete your account.';

  @override
  String get delete_account_confirm_word => 'delete';

  @override
  String get settings_licenses_desc =>
      'This application was built thanks to the work of thousands of developers around the world. Below you\'ll find information about the open-source software we use to deliver the highest quality experience.';
}
