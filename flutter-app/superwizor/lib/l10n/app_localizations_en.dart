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
  String get common_not_found => 'Not found';

  @override
  String get language_pl_name => 'Polski';

  @override
  String get language_pl_sub => 'Polish';

  @override
  String get language_en_name => 'English';

  @override
  String get language_en_sub => 'English (UK)';

  @override
  String get session_name_fallback => 'Conversation';

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
  String get auth_shared_machine_warning_title => 'Using a shared computer?';

  @override
  String get auth_shared_machine_warning_body =>
      'Sign out when you\'re done so your session data isn\'t available to the next person who uses this computer.';

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
  String get auth_sign_in_with_google => 'Continue with Google';

  @override
  String get auth_sign_in_with_apple => 'Sign in with Apple';

  @override
  String get auth_or_use_email => 'Or use your email';

  @override
  String get auth_social_error =>
      'Sign-in with external account failed. Please try again.';

  @override
  String get auth_social_cancelled => 'Sign-in cancelled.';

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
  String get modality_gestalt => 'Gestalt';

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
  String get addPatient_title => 'New record';

  @override
  String get addPatient_subtitle =>
      'Fill in client details to create a record.';

  @override
  String get addPatient_first_name_label => 'First name (required)';

  @override
  String get addPatient_last_name_label => 'Initial or alias';

  @override
  String get addPatient_email_label => 'Client email';

  @override
  String get addPatient_email_hint => 'Optional (for the action plan)';

  @override
  String get addPatient_modality_label => 'Therapy modality';

  @override
  String get addPatient_language_label => 'Report language';

  @override
  String get addPatient_consent_label =>
      'The client consented to recording and data processing according to the Privacy Policy and DPA of Superwizor AI.';

  @override
  String get addPatient_consent_link_label => 'View DPA.';

  @override
  String get addPatient_save_primary => 'Create record';

  @override
  String get addPatient_no_consent_header => 'No consent to record.';

  @override
  String get addPatient_no_consent_body =>
      'We cannot start a session without explicit patient consent. Data protection laws require this.';

  @override
  String get addPatient_no_consent_primary => 'I understand.';

  @override
  String get addPatient_duplicate_header => 'This client already exists.';

  @override
  String get addPatient_duplicate_body =>
      'You already have a record with this name combination. Add an initial or alias to avoid confusion.';

  @override
  String get addPatient_duplicate_primary => 'I\'ll fix the name.';

  @override
  String get addPatient_step1_subtitle => 'Fill in the basic client details.';

  @override
  String get addPatient_step1_next => 'Next';

  @override
  String get addPatient_step2_title => 'Customize your workflow';

  @override
  String get addPatient_step2_subtitle => 'Settings that guide the AI.';

  @override
  String get addPatient_alias_label => 'Working alias';

  @override
  String get addPatient_alias_hint =>
      'Your private shortcut. Only you can see it.';

  @override
  String get addPatient_discard_title => 'Discard changes?';

  @override
  String get addPatient_discard_body => 'Nothing will be saved.';

  @override
  String get addPatient_discard_action => 'Discard';

  @override
  String get addPatient_discard_stay => 'Keep editing';

  @override
  String get editPatient_title => 'Edit client file';

  @override
  String get editPatient_save_primary => 'Save changes';

  @override
  String get editPatient_erase_destructive => 'Erase client file permanently';

  @override
  String get editPatient_erase_confirm_header => 'Permanent erasure';

  @override
  String get editPatient_erase_confirm_body =>
      'This action permanently deletes the client file and ALL their sessions and transcripts (GDPR right to be forgotten). This cannot be undone.';

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
  String get recording_instructions_title =>
      'A few tips for a better recording';

  @override
  String get recording_instructions_subtitle =>
      'Good recording conditions mean better transcription quality and more accurate AI insights.';

  @override
  String get recording_instruction_1 =>
      'Place the phone on a table, between speakers (50–100 cm distance).';

  @override
  String get recording_instruction_2 =>
      'Point the microphone towards the conversation, do not cover it.';

  @override
  String get recording_instruction_3 =>
      'Quiet environment – close windows/doors, turn off noise sources.';

  @override
  String get recording_instruction_4 =>
      'For video conferences (e.g. Google Meet, Zoom), always use a secondary device to record.';

  @override
  String get recording_instruction_5 =>
      'Recording stops automatically after a set time, and you\'ll get a periodic reminder (with an optional sound) — both adjustable in Settings → Recording.';

  @override
  String get recording_status_initializing => 'Starting recording…';

  @override
  String get recording_status_recording => 'Recording in progress.';

  @override
  String get recording_status_paused => 'Recording paused.';

  @override
  String get minimized_recording_paused => 'Recording paused';

  @override
  String get minimized_recording_active => 'Recording session...';

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
  String get recording_discard_confirm_header =>
      'Are you sure you want to delete this recording?';

  @override
  String get recording_discard_confirm_body =>
      'This recording cannot be recovered. It will be permanently deleted from this device and will not be sent for analysis.';

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
  String get recording_fgs_notification_title =>
      'Session recording in progress';

  @override
  String get recording_fgs_notification_body =>
      'Superwizor is recording the session. Keep the app open.';

  @override
  String get recording_interrupted_banner_title => 'Recording paused';

  @override
  String get recording_interrupted_banner_body =>
      'A phone call or another app interrupted the recording. Everything captured so far is safe.';

  @override
  String get recording_interrupted_resume => 'Resume recording';

  @override
  String get recording_resume_failed_header => 'Could not resume';

  @override
  String get recording_resume_failed_body =>
      'Recording could not be resumed. Everything captured so far is safe, you can end the session and send it for analysis.';

  @override
  String get recording_resume_failed_retry => 'Try again';

  @override
  String get recording_resume_failed_finish => 'Finish and send';

  @override
  String get recovery_sheet_header => 'Interrupted recording found';

  @override
  String recovery_sheet_body(String patientAlias, String date, int minutes) {
    return 'The session recording for $patientAlias from $date (~$minutes min) was never sent, as the app was interrupted while recording. What would you like to do?';
  }

  @override
  String get recovery_sheet_send => 'Send for analysis';

  @override
  String get recovery_sheet_later => 'Decide later';

  @override
  String get recovery_sheet_delete => 'Delete recording';

  @override
  String get recovery_delete_confirm_header => 'Delete permanently?';

  @override
  String get recovery_delete_confirm_body =>
      'This recording cannot be recovered.';

  @override
  String get recovery_delete_confirm_destructive => 'Delete';

  @override
  String get recovery_enqueued_snackbar =>
      'Recording added to the upload queue';

  @override
  String get stepper_step1_uploaded => 'Audio safely on our servers.';

  @override
  String get stepper_step1_queued => 'Audio waiting in upload queue.';

  @override
  String get stepper_step1_uploading => 'Uploading audio to server.';

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
  String get session_status_title => 'Secure analysis in progress.';

  @override
  String get session_status_subtitle =>
      'We are preparing your reports and transcriptions. This may take up to 15 minutes. You can come back shortly.';

  @override
  String get session_status_success => 'Done!';

  @override
  String get session_status_back_to_records => 'Back to records';

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
  String get drawer_fallback_name => 'Therapist';

  @override
  String get drawer_settings_header => 'SETTINGS';

  @override
  String get drawer_legal_header => 'LEGAL DOCUMENTS';

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
  String get settings_professional_title => 'Professional title';

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
  String get settings_language_app => 'App language';

  @override
  String get settings_delete_confirm_title =>
      'Are you sure you want\nto delete your account?';

  @override
  String get settings_delete_confirm_body =>
      'This action is IRREVERSIBLE.\nYou will lose all clinical documentation and patient data.';

  @override
  String get settings_delete_confirm_proceed => 'I understand, proceed.';

  @override
  String get settings_delete_confirm_cancel => 'Cancel, keep my account.';

  @override
  String get settings_choose_language => 'Choose language';

  @override
  String get delete_account_title => 'Delete account';

  @override
  String get delete_account_consequence_1 =>
      'All clinical documentation (all patients, records, sessions, and AI reports) will be permanently deleted.';

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

  @override
  String get report_rating_thumbs_up_tooltip => 'Good report';

  @override
  String get report_rating_thumbs_down_tooltip => 'Something is off';

  @override
  String get report_rating_saved_positive => 'Thanks for the positive rating.';

  @override
  String get report_rating_saved_negative =>
      'Thanks, we\'ll factor this into future reports.';

  @override
  String get report_rating_save_error =>
      'Could not save rating. Please try again.';

  @override
  String get report_rating_modal_title => 'What went wrong?';

  @override
  String get report_rating_modal_subtitle =>
      'Pick one or more categories. This helps us tune future reports.';

  @override
  String get report_rating_notes_label => 'Additional note (optional)';

  @override
  String get report_rating_notes_hint => 'Short comment, max 200 chars…';

  @override
  String get report_rating_submit => 'Submit rating';

  @override
  String get report_rating_chip_too_long => 'Too long';

  @override
  String get report_rating_chip_too_short => 'Too short';

  @override
  String get report_rating_chip_wrong_tone => 'Wrong tone';

  @override
  String get report_rating_chip_too_many_quotes => 'Too many quotes';

  @override
  String get report_rating_chip_too_few_quotes => 'Too few quotes';

  @override
  String get report_rating_chip_inaccurate_interpretation =>
      'Inaccurate interpretation';

  @override
  String get report_rating_chip_missing_strengths =>
      'Missing patient strengths';

  @override
  String get report_rating_chip_missing_context =>
      'Missing context / wrong emphasis';

  @override
  String get report_rating_chip_other => 'Other';

  @override
  String get settings_section_report_preferences => 'REPORT PREFERENCES';

  @override
  String get report_prefs_intro_title => 'Report style';

  @override
  String get report_prefs_intro_subtitle =>
      'Tune how AI writes reports from your sessions.';

  @override
  String get report_prefs_load_error => 'Could not load preferences.';

  @override
  String get report_prefs_save_error =>
      'Could not save preferences. Please try again.';

  @override
  String get report_prefs_saved => 'Preferences saved.';

  @override
  String get report_prefs_length_label => 'Report length';

  @override
  String get report_prefs_length_brief => 'Brief';

  @override
  String get report_prefs_length_standard => 'Standard';

  @override
  String get report_prefs_length_detailed => 'Detailed';

  @override
  String get report_prefs_tone_label => 'Tone';

  @override
  String get report_prefs_tone_clinical_formal => 'Clinical, formal';

  @override
  String get report_prefs_tone_empathic_warm => 'Empathic, warm';

  @override
  String get report_prefs_tone_pragmatic_direct => 'Pragmatic, direct';

  @override
  String get report_prefs_tone_academic_rigorous => 'Academic, rigorous';

  @override
  String get report_prefs_quote_density_label => 'Quotes from session';

  @override
  String get report_prefs_quote_density_few => 'Few';

  @override
  String get report_prefs_quote_density_selective => 'Selective';

  @override
  String get report_prefs_quote_density_many => 'Many';

  @override
  String get report_prefs_diagnostic_language_label => 'Diagnostic language';

  @override
  String get report_prefs_diagnostic_language_descriptive => 'Descriptive';

  @override
  String get report_prefs_diagnostic_language_clinical_labels =>
      'Clinical labels';

  @override
  String get report_prefs_diagnostic_language_dsm_icd => 'DSM / ICD';

  @override
  String get report_prefs_hypothesis_hedging_label =>
      'Hypothesis assertiveness';

  @override
  String get report_prefs_hypothesis_hedging_tentative => 'Tentative';

  @override
  String get report_prefs_hypothesis_hedging_balanced => 'Balanced';

  @override
  String get report_prefs_hypothesis_hedging_assertive => 'Assertive';

  @override
  String get report_prefs_section_emphasis_label => 'Sections to expand';

  @override
  String get report_prefs_section_emphasis_subtitle =>
      'Pick sections AI should focus on.';

  @override
  String get report_prefs_section_clinical_picture => 'Clinical picture';

  @override
  String get report_prefs_section_interventions => 'Interventions';

  @override
  String get report_prefs_section_case_formulation => 'Case formulation';

  @override
  String get report_prefs_section_supervisory_recommendations =>
      'Supervisory recommendations';

  @override
  String get report_prefs_section_homework_between_sessions =>
      'Homework between sessions';

  @override
  String get report_prefs_section_cultural_context => 'Cultural context';

  @override
  String get report_prefs_section_safety_and_risk => 'Safety and risk';

  @override
  String get report_prefs_strengths_framing_label => 'Strengths framing';

  @override
  String get report_prefs_strengths_framing_problem_focused =>
      'Problem-focused';

  @override
  String get report_prefs_strengths_framing_balanced => 'Balanced';

  @override
  String get report_prefs_strengths_framing_strengths_first =>
      'Strengths-first';

  @override
  String get report_prefs_free_text_label => 'Additional guidance';

  @override
  String get report_prefs_free_text_subtitle =>
      'Free text, max 500 chars. AI will factor this into every report.';

  @override
  String get report_prefs_free_text_hint =>
      'e.g. Focus on patient body language observations…';

  @override
  String get report_prefs_value_not_set => 'Default';

  @override
  String get report_prefs_picker_title => 'Pick an option';

  @override
  String get report_prefs_save => 'Save';

  @override
  String get report_prefs_too_long => 'Text too long (max 500 chars).';

  @override
  String get suggestion_banner_header => 'AI suggestion';

  @override
  String suggestion_banner_body(
    String reason,
    int count,
    String dimension,
    String toValue,
  ) {
    return 'You rated recent reports as \"$reason\" ($count×). Change $dimension to \"$toValue\"?';
  }

  @override
  String suggestion_banner_body_section_emphasis(String reason, int count) {
    return 'You rated recent reports as \"$reason\" ($count×). Open settings to tune section emphasis.';
  }

  @override
  String get suggestion_banner_apply => 'Apply';

  @override
  String get suggestion_banner_open_settings => 'Open settings';

  @override
  String get suggestion_banner_dismiss => 'Not now';

  @override
  String get suggestion_banner_applied_toast =>
      'Changed, future reports will reflect this.';

  @override
  String get suggestion_banner_apply_error => 'Could not change the setting.';

  @override
  String billing_quota_warning_short(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tokens left.',
      one: '1 token left.',
    );
    return '$_temp0';
  }

  @override
  String get billing_quota_critical_short => 'Only 1 token left.';

  @override
  String get billing_quota_exhausted_short => 'Token pool exhausted.';

  @override
  String get billing_quota_exhausted_subtitle =>
      'New sessions will be saved locally until renewal.';

  @override
  String billing_period_end_label(String date) {
    return 'Pool renews on $date.';
  }

  @override
  String get billing_expand_plan_cta => 'Upgrade plan';

  @override
  String get billing_dismiss_cta => 'OK, continue';

  @override
  String get billing_exhausted_dialog_title => 'Token pool exhausted';

  @override
  String get billing_exhausted_dialog_body =>
      'You\'ve used all available sessions. You can still record, audio will be securely encrypted and saved locally. Check your email to learn more.';

  @override
  String get billing_exhausted_dialog_record_locally => 'Record locally';

  @override
  String billing_pending_sessions_title(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sessions waiting to be processed',
      one: '1 session waiting to be processed',
    );
    return '$_temp0';
  }

  @override
  String get billing_pending_session_subtitle =>
      'Audio saved locally · Waiting for tokens';

  @override
  String billing_pending_session_card_meta(
    String date,
    String time,
    int duration,
  ) {
    return 'Session from $date, $time ($duration min)';
  }

  @override
  String get billing_resume_processing => 'Resume processing';

  @override
  String get billing_delete_local_audio => 'Delete';

  @override
  String billing_tokens_available_required(int available, int required) {
    return 'Tokens available: $available / Required: $required';
  }

  @override
  String get billing_delete_confirm_title => 'Delete session recording?';

  @override
  String get billing_delete_confirm_body =>
      'Audio will be permanently deleted from this device. This action cannot be undone.';

  @override
  String get billing_delete_confirm_action => 'Delete permanently';

  @override
  String get billing_reservation_expired_title => 'Processing failed';

  @override
  String get billing_reservation_expired_body =>
      'Token reservation expired after 4 hours. Audio is still saved locally.';

  @override
  String get billing_retry_cta => 'Try again';

  @override
  String get billing_past_due_title => 'Payment issue';

  @override
  String get billing_past_due_body =>
      'We could not process your subscription payment. New sessions will not be processed until this is resolved.';

  @override
  String get subscription_screen_title => 'Subscription';

  @override
  String get subscription_plan_section_header => 'Your plan';

  @override
  String get subscription_tier_solo => 'Discovery';

  @override
  String get subscription_tier_pro => 'Balance';

  @override
  String get subscription_tier_clinic => 'Flourishing';

  @override
  String get subscription_tier_trial => 'Trial';

  @override
  String get subscription_cycle_monthly => 'monthly';

  @override
  String get subscription_cycle_semi_annual => 'semi-annual';

  @override
  String get subscription_cycle_annual => 'annual';

  @override
  String subscription_sessions_per_period(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sessions per period',
      one: '1 session per period',
    );
    return '$_temp0';
  }

  @override
  String subscription_sessions_left(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sessions left in period',
      one: '1 session left in period',
      zero: 'No sessions left in period',
    );
    return '$_temp0';
  }

  @override
  String subscription_sessions_used(int used, int limit) {
    return 'Used: $used of $limit';
  }

  @override
  String subscription_period_ends(String date) {
    return 'Period ends $date';
  }

  @override
  String get subscription_no_data_title => 'No subscription data';

  @override
  String get subscription_no_data_body =>
      'Could not load your plan info. Check your connection and try again.';

  @override
  String get subscription_refresh_cta => 'Refresh';

  @override
  String get stepper_step1_quota_blocked =>
      'Token pool exhausted. Renew your plan to resume.';

  @override
  String get quota_blocked_queue_label => 'Token pool exhausted';

  @override
  String get upload_resend => 'Resend';

  @override
  String get upload_cancel_processing => 'Delete';

  @override
  String get cancel_session_confirm_title => 'Cancel processing?';

  @override
  String get cancel_session_confirm_body =>
      'The session will be cancelled and the recording removed from the queue. This cannot be undone.';

  @override
  String get cancel_session_confirm_action => 'Yes, delete';

  @override
  String get cancel_session_keep => 'No, keep it';

  @override
  String get cancel_session_success => 'Session cancelled';

  @override
  String get note_add_label => 'ADD NOTE';

  @override
  String get note_add_subtitle => 'Quick note about the client';

  @override
  String get note_sheet_title => 'New note';

  @override
  String get note_sheet_hint => 'Type your note…';

  @override
  String get note_sheet_save => 'Save';

  @override
  String get note_sheet_cancel => 'Cancel';

  @override
  String get note_delete_confirm => 'Delete note?';

  @override
  String get note_delete_action => 'Delete';

  @override
  String get note_empty_text => 'Note cannot be empty.';

  @override
  String get note_title_hint => 'Note title';

  @override
  String get note_body_hint => 'Note content…';

  @override
  String get note_discard_title => 'Discard changes?';

  @override
  String get note_discard_body =>
      'You have unsaved changes. Do you want to discard them?';

  @override
  String get note_discard_action => 'Discard';

  @override
  String get note_discard_save => 'Save';

  @override
  String get note_edit_label => 'Edit note';

  @override
  String get note_untitled => 'Untitled';

  @override
  String get note_saved => 'Note saved ✓';

  @override
  String get note_deleted => 'Note deleted';

  @override
  String get action_plan_send_button => 'Send action plan to patient';

  @override
  String get action_plan_save_only => 'Save';

  @override
  String get action_plan_save_and_send => 'Save and send';

  @override
  String get action_plan_no_email_title => 'No e-mail address';

  @override
  String get action_plan_no_email_body =>
      'The plan can\'t be sent, because the patient has no e-mail address on file. Add an e-mail in the client record.';

  @override
  String get action_plan_send_confirm_title => 'Send the action plan?';

  @override
  String action_plan_send_confirm_body(String email) {
    return 'The plan will be sent to: $email';
  }

  @override
  String get action_plan_send_cancel => 'Cancel';

  @override
  String get action_plan_send_confirm_action => 'Send';

  @override
  String get action_plan_sent_toast => 'Action plan sent to client';

  @override
  String get action_plan_saved_not_sent =>
      'Note saved, but the e-mail couldn\'t be sent. Try sending again later.';

  @override
  String get session_delete_error =>
      'Couldn\'t delete the session. Please try again.';

  @override
  String get session_rename_error =>
      'Couldn\'t save the title on the server. Please try again.';

  @override
  String get action_plan_default_title => 'Action plan';

  @override
  String get action_plan_fill_email_hint =>
      'Fill in the client\'s e-mail address and resend.';

  @override
  String get note_save_error => 'Couldn\'t save the note';

  @override
  String get note_send_to_client => 'Send to client';

  @override
  String get note_send_confirm_title => 'Send note to client?';

  @override
  String note_send_confirm_body(String email) {
    return 'The note will be sent to: $email';
  }

  @override
  String get note_sent_toast => 'Note sent to client';

  @override
  String get recording_consent_missing_header => 'No consent recorded';

  @override
  String get recording_consent_missing_body =>
      'No patient consent found in the system. Did the patient consent to recording and data processing?';

  @override
  String get recording_consent_grant => 'Yes, they consented';

  @override
  String get recording_mic_error_header => 'Microphone error';

  @override
  String get recording_upload_error_header => 'Upload error';

  @override
  String recording_too_short_abort_body(String duration) {
    return 'Recording was $duration. Upload cancelled.';
  }

  @override
  String get recording_saving => 'Saving recording...';

  @override
  String get recording_minimize_confirm_header => 'Exit recording screen';

  @override
  String get recording_minimize_confirm_body =>
      'Recording is in progress. You can minimize this screen to access notes (recording will continue in the background).';

  @override
  String get recording_minimize_action => 'Minimize (keep in background)';

  @override
  String get recording_minimize_discard => 'Stop and delete recording';

  @override
  String get recording_minimize_resume => 'Return to recording';

  @override
  String get recording_discard_confirm_action => 'Yes, delete permanently';

  @override
  String get recording_discard_confirm_cancel => 'No, go back';

  @override
  String get active_session_card_title => 'Session in progress...';

  @override
  String get active_session_card_subtitle => 'Return to the ongoing session';

  @override
  String get active_session_card_paused_title => 'Session paused';

  @override
  String get active_session_card_paused_subtitle => 'Resume or end the session';

  @override
  String get settings_live_activities => 'Lock screen activity';

  @override
  String get settings_live_activities_on =>
      'Session time and status visible without unlocking your phone.';

  @override
  String get settings_live_activities_off =>
      'Session status visible only inside the app.';

  @override
  String get live_activity_info_title => 'Keep your session in sight';

  @override
  String get live_activity_info_body =>
      'Enable lock screen preview to see your session timer without opening the app.';

  @override
  String get live_activity_info_enable => 'Enable preview';

  @override
  String get live_activity_info_dismiss => 'Not now';

  @override
  String get live_activity_minimize_toast =>
      'Session is running in the background. To see its timer on the lock screen, enable the preview in Settings.';

  @override
  String get live_activity_status_recording => 'Session in progress';

  @override
  String get live_activity_status_paused => 'Paused';

  @override
  String get live_activity_status_uploading => 'Uploading recording...';

  @override
  String get live_activity_status_analyzing => 'Analyzing session...';

  @override
  String get live_activity_status_report_ready => 'New report is ready';

  @override
  String get live_activity_show_report => 'Show report';

  @override
  String get live_activity_permission_title => 'System permission required';

  @override
  String get live_activity_permission_body =>
      'Lock screen session preview requires Live Activities to be enabled in system settings.';

  @override
  String get live_activity_permission_open_settings => 'Open settings';

  @override
  String get live_activity_permission_cancel => 'Cancel';

  @override
  String get home_greeting_prefix => 'Welcome, ';

  @override
  String get home_greeting_subtitle => 'Who are we working with today?';

  @override
  String get home_search_hint => 'Search client…';

  @override
  String get home_empty_list => 'Add your first client to get started.';

  @override
  String home_no_search_results(String query) {
    return 'No results for “$query”';
  }

  @override
  String get home_section_active => 'YOUR CLIENT RECORDS';

  @override
  String get home_section_active_filtered => 'YOUR CLIENT RECORDS • FILTER';

  @override
  String home_section_paused(int count) {
    return 'PAUSED ($count)';
  }

  @override
  String home_section_completed(int count) {
    return 'COMPLETED ($count)';
  }

  @override
  String get home_status_awaiting_first_session => 'Awaiting first session';

  @override
  String get home_status_new_client => 'New client';

  @override
  String get home_card_sessions_prefix => 'Sessions: ';

  @override
  String get home_card_last_session_prefix => ' • Last: ';

  @override
  String get home_card_last_prefix_only => 'Last: ';

  @override
  String get home_status_recording => 'Recording';

  @override
  String get home_status_has_new_report => 'New report';

  @override
  String get home_status_analyzing => 'AI analyzing';

  @override
  String get home_status_uploading => 'Uploading…';

  @override
  String get home_status_upload_failed => 'Upload\nfailed';

  @override
  String get home_status_error => 'Analysis error';

  @override
  String get home_status_active => 'Active';

  @override
  String get home_status_completed => 'Completed';

  @override
  String get home_status_paused => 'Paused';

  @override
  String get home_status_new => 'New';

  @override
  String get home_menu_lifecycle_active => 'Active';

  @override
  String get home_menu_lifecycle_completed => 'Completed';

  @override
  String get home_menu_lifecycle_paused => 'Paused';

  @override
  String get home_menu_edit_data => 'Edit details';

  @override
  String get home_menu_edit_data_desc => 'Change name, alias, or email';

  @override
  String get home_menu_delete_patient => 'Delete record';

  @override
  String get home_menu_delete_patient_desc =>
      'Erase history, sessions, and notes';

  @override
  String get home_menu_field_first_name => 'First name (required)';

  @override
  String get home_menu_field_last_name => 'Initial or alias';

  @override
  String get home_menu_field_email => 'Client email';

  @override
  String get home_menu_btn_back => 'Back';

  @override
  String get home_menu_btn_save => 'Save';

  @override
  String get home_menu_manage_client => 'Manage client record';

  @override
  String get home_menu_edit_client => 'Edit client file';

  @override
  String home_delete_title(String name) {
    return 'Delete client: $name';
  }

  @override
  String get home_delete_warning_body =>
      'All clinical documentation — sessions, AI notes, and audio recordings — will be permanently and irreversibly deleted from medical databases.\nIn accordance with GDPR (right to be forgotten).';

  @override
  String get home_delete_warning_understand =>
      'I understand, this is irreversible.';

  @override
  String get home_delete_btn_continue => 'Continue deletion';

  @override
  String get home_delete_confirm_instruction => 'To confirm, type:';

  @override
  String get home_delete_confirm_word => 'delete';

  @override
  String get home_delete_confirm_hint => 'type here…';

  @override
  String get home_delete_btn_confirm => 'Delete client';

  @override
  String get home_delete_btn_cancel => 'Cancel.';

  @override
  String home_error_loading(String error) {
    return 'Error: $error';
  }

  @override
  String get common_close => 'Close';

  @override
  String get common_copied_to_clipboard => 'Copied to clipboard';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_got_it => 'Got it';

  @override
  String pendingUploads_pill_attention(int count) {
    return '$count requires attention';
  }

  @override
  String pendingUploads_pill_retrying(int count) {
    return '$count retrying';
  }

  @override
  String pendingUploads_pill_analyzing(int count) {
    return '$count analyzing';
  }

  @override
  String pendingUploads_pill_in_progress(int count) {
    return '$count in progress';
  }

  @override
  String get pending_uploads_title => 'Session Queue';

  @override
  String get pending_uploads_subtitle =>
      'Upload and processing status of recordings.';

  @override
  String pending_uploads_error(String error) {
    return 'Error: $error';
  }

  @override
  String get pending_uploads_empty_title => 'No files in queue';

  @override
  String get pending_uploads_empty_body => 'All sessions have been uploaded.';

  @override
  String get pending_uploads_no_internet_title => 'No internet connection';

  @override
  String get pending_uploads_error_title => 'Upload error';

  @override
  String get pending_uploads_no_internet_desc =>
      'Upload was interrupted, but your recording is safely saved on this device. Try uploading again when you regain connection.';

  @override
  String get pending_uploads_error_desc =>
      'Upload was interrupted due to an error, but your recording is safely saved on this device. Try uploading again.';

  @override
  String get pending_uploads_btn_resend => 'Resend';

  @override
  String get pending_uploads_default_patient_name => 'Patient';

  @override
  String get pending_uploads_resending_auto_prefix =>
      'RETRYING AUTOMATICALLY: ';

  @override
  String get pending_uploads_quota_dialog_title => 'No sessions available';

  @override
  String get pending_uploads_quota_dialog_body =>
      'Your session pool for this month has been exhausted. To process this recording, visit the Superwizor platform in a web browser to manage your plan.';

  @override
  String get pending_uploads_err_reason_no_internet => 'no internet connection';

  @override
  String get pending_uploads_err_reason_timeout =>
      'server did not respond in time';

  @override
  String get pending_uploads_err_reason_link_expired => 'upload link expired';

  @override
  String get pending_uploads_err_reason_unavailable =>
      'server temporarily unavailable';

  @override
  String pending_uploads_err_reason_prefix(String reason) {
    return 'Error reason: $reason';
  }

  @override
  String get pending_uploads_phase_resuming => 'Resuming upload...';

  @override
  String get pending_uploads_phase_encrypting => 'Encrypting recording...';

  @override
  String get pending_uploads_phase_converting => 'Converting audio file...';

  @override
  String get pending_uploads_phase_pending => 'In queue';

  @override
  String get pending_uploads_phase_uploading => 'Uploading to server...';

  @override
  String get pending_uploads_phase_uploaded => 'Uploaded — finalizing...';

  @override
  String get pending_uploads_phase_converted =>
      'Conversion ready — finalizing...';

  @override
  String get pending_uploads_phase_completed => 'Uploaded';

  @override
  String get pending_uploads_phase_failed => 'Upload interrupted';

  @override
  String pending_uploads_detail_attempt(int attempt) {
    return ' • attempt $attempt';
  }

  @override
  String get pending_uploads_quota_card_title =>
      'Recording is waiting to resume.';

  @override
  String get pending_uploads_quota_card_desc =>
      'Token pool has been exhausted. The session is safely saved and will be processed after the plan renews.';

  @override
  String get pending_uploads_btn_checking => 'Checking...';

  @override
  String get pending_uploads_btn_send_again => 'Send again';

  @override
  String get addPatient_email_required_error =>
      'Please provide email or change client language.';

  @override
  String get addPatient_alias_instruction =>
      'Give the client a unique label — it will make navigation easier.';

  @override
  String get addPatient_background_color => 'BACKGROUND COLOR';

  @override
  String get addPatient_skip_for_now => 'Skip for now';

  @override
  String get clientDetails_profile_not_loaded =>
      'Profile has not been loaded yet. Try again in a moment.';

  @override
  String clientDetails_error(String error) {
    return 'Error: $error';
  }

  @override
  String clientDetails_session_error(String error) {
    return 'Session error: $error';
  }

  @override
  String get clientDetails_start_work => 'Start work';

  @override
  String get clientDetails_start_work_desc =>
      'Start recording and the system will take care of secure transcription and prepare a clinical report.';

  @override
  String get clientDetails_encryption_notice_part1 =>
      'Your data is encrypted end-to-end. ';

  @override
  String get clientDetails_encryption_notice_part2 =>
      'No one but you has access to it.';

  @override
  String get clientDetails_upload_recording =>
      'Upload voice recorder recording';

  @override
  String get clientDetails_record_new_session => 'Record new therapy session';

  @override
  String get clientDetails_start_first_analysis => 'Start first analysis';

  @override
  String get clientDetails_status_converting => 'Converting audio…';

  @override
  String get clientDetails_status_uploading => 'Uploading audio…';

  @override
  String get clientDetails_status_interrupted => 'Upload interrupted';

  @override
  String get clientDetails_delete_session_title => 'Permanent session deletion';

  @override
  String get clientDetails_delete_session_desc =>
      'The session, recording, and transcription will be permanently deleted. This action cannot be undone.';

  @override
  String get clientDetails_btn_yes_delete => 'Yes, delete';

  @override
  String get clientDetails_manage_session => 'Manage session';

  @override
  String get clientDetails_manage_session_desc =>
      'Change title or delete session';

  @override
  String get clientDetails_session_title_label => 'Session title';

  @override
  String get clientDetails_btn_save_title => 'Save title';

  @override
  String get clientDetails_btn_delete_session => 'Delete session';

  @override
  String get clientDetails_btn_delete_session_desc =>
      'Permanently delete recording and analysis';

  @override
  String get clientDetails_edit_note_subtitle =>
      'Change title or content of note';

  @override
  String get clientDetails_copy_content => 'Copy content';

  @override
  String get clientDetails_copy_content_desc => 'Copy note to clipboard';

  @override
  String clientDetails_note_sent_at(String date) {
    return 'Sent $date';
  }

  @override
  String get clientDetails_send_note_desc => 'Send note via email to client';

  @override
  String get clientDetails_note_sent_badge => 'Sent';

  @override
  String get clientDetails_delete_note_desc => 'Permanently delete this note';

  @override
  String get clientDetails_no_content => 'No content';

  @override
  String get sessionDetails_stat_modality => 'MODALITY';

  @override
  String get sessionDetails_stat_words => 'WORDS';

  @override
  String get sessionDetails_stat_sentiment => 'SENTIMENT';

  @override
  String get sessionDetails_stat_sentiment_neutral => 'Neutral';

  @override
  String get sessionDetails_stat_sentiment_unknown => 'Unknown';

  @override
  String get sessionDetails_stat_status => 'STATUS';

  @override
  String get sessionDetails_stat_status_new => 'New';

  @override
  String get sessionDetails_tab_analyses => 'Analysis';

  @override
  String get sessionDetails_tab_transcriptions => 'Transcripts';

  @override
  String get sessionDetails_toast_reports_copied =>
      'All reports copied to clipboard';

  @override
  String get sessionDetails_toast_transcript_copied =>
      'Transcript copied to clipboard';

  @override
  String get sessionDetails_ai_reports_soon => 'AI Reports — coming soon';

  @override
  String get sessionDetails_ai_reports_soon_desc =>
      'Session analysis and automatic reports will be available\nin the next update.';

  @override
  String get sessionDetails_transcript_soon => 'Transcription — coming soon';

  @override
  String get sessionDetails_transcript_soon_desc =>
      'Automatic transcription with speaker recognition\nwill be available in the next update.';

  @override
  String get sessionDetails_copy_transcript => 'Copy transcription';

  @override
  String get report_copy_desc => 'Copy content to clipboard';

  @override
  String get report_edit_summary_desc => 'Correct or complete the AI summary';

  @override
  String get report_btn_copy_section => 'Copy section';

  @override
  String get report_btn_edit_section => 'Edit content';

  @override
  String get report_edit_section_desc => 'Correct or complete the AI report';

  @override
  String get report_edit_section_hint => 'Edit section content...';

  @override
  String get report_intro_title => 'Introduction';

  @override
  String get menu_avatar_title => 'Profile picture';

  @override
  String get menu_avatar_desc => 'Choose where you want to add the photo from.';

  @override
  String get menu_avatar_updated => 'Profile picture updated';

  @override
  String menu_save_error(String error) {
    return 'An error occurred while saving: $error';
  }

  @override
  String get menu_invalid_email => 'Provide a valid email address.';

  @override
  String menu_verification_sent(String email) {
    return 'Verification link sent to $email';
  }

  @override
  String get menu_reauth_required => 'Log in again to change email.';

  @override
  String get menu_email_in_use => 'This email address is already in use.';

  @override
  String menu_error_message(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get menu_change_email_title => 'Change email address';

  @override
  String get menu_change_email_desc =>
      'We will send a verification link to the new address.';

  @override
  String get menu_btn_send_verification => 'Send verification';

  @override
  String get menu_delete_account_confirm_title =>
      'Permanent and irreversible deletion';

  @override
  String get sessionStatus_uploading_desc =>
      'Superwizor is uploading the session recording to the server.';

  @override
  String get sessionStatus_btn_delete_session => 'Delete session';

  @override
  String get sessionStatus_upload_stopped_title => 'Upload stopped';

  @override
  String get sessionStatus_upload_stopped_net_err =>
      'A network connection problem occurred.\n\n';

  @override
  String get sessionStatus_upload_stopped_safe =>
      'The recording is safe on your device. ';

  @override
  String get sessionStatus_upload_stopped_resume =>
      'The system will resume uploading when you regain coverage.';

  @override
  String get sessionStatus_report_failed_temp =>
      'The report creation process encountered a difficulty.\n\n';

  @override
  String get sessionStatus_report_failed_retry =>
      'Please try analyzing again in a while.';

  @override
  String get sessionStatus_report_failed_perm =>
      'Could not generate report for this session.\n\n';

  @override
  String get sessionStatus_report_failed_contact =>
      'If the situation persists, please let us know.';

  @override
  String get sessionStatus_status_uploading => 'Uploading to server';

  @override
  String get sessionStatus_status_queued => 'In queue to upload';

  @override
  String get sessionStatus_bg_processing_notice =>
      'You can safely leave this screen,\nthe session will process in the background.';

  @override
  String get recording_ios_only_title => 'Recording available in iOS app';

  @override
  String recording_ios_only_body_part1(String alias) {
    return 'To record a session with $alias, use the ';
  }

  @override
  String get recording_ios_only_body_part2 =>
      'Superwizor app on iPhone. After uploading the recording, ';

  @override
  String get recording_ios_only_body_part3 =>
      'the transcript and report will appear here.';

  @override
  String get recording_btn_back => 'Go Back';

  @override
  String get newSession_error_header => 'Error';

  @override
  String get newSession_upload_file_header => 'FILE UPLOAD';

  @override
  String get newSession_new_session_header => 'NEW SESSION';

  @override
  String get newSession_pick_file_desc =>
      'Select an audio file from disk. After upload, the file will be automatically analyzed.';

  @override
  String get newSession_record_or_upload_desc =>
      'Record this session, or upload an audio file from a voice recorder.';

  @override
  String get newSession_secure_upload_title => 'Secure upload.';

  @override
  String get newSession_secure_upload_desc =>
      'Your file is encrypted and securely sent to our servers in Europe. No one but you has access to this data.';

  @override
  String get newSession_recording_in_progress_err =>
      'Another session recording is in progress. Return to it to continue.';

  @override
  String newSession_format_not_supported(String ext) {
    return 'Format \"$ext\" is not supported.\n\n';
  }

  @override
  String get newSession_supported_formats =>
      'Supported formats: FLAC, WAV, MP3, OGG, OPUS, M4A, AAC, WEBM, AMR.';

  @override
  String newSession_file_too_large(String size) {
    return 'File is too large ($size MB). ';
  }

  @override
  String get newSession_uploading_file => 'Uploading file...';

  @override
  String get newSession_recording_active_err =>
      'Session recording is active. Return to it to continue.';

  @override
  String get newSession_preparing_file => 'Preparing file...';

  @override
  String get newSession_queuing => 'Queuing...';

  @override
  String get newSession_encryption_notice_part1 =>
      'Your recordings are protected by end-to-end encryption and are used solely ';

  @override
  String get newSession_encryption_notice_part2 =>
      'for AI analysis. No one but you has access to the data.';

  @override
  String newSession_upload_error(String error) {
    return 'Error uploading file:\n$error';
  }

  @override
  String login_auth_error(String code, String message) {
    return 'Auth error [$code]: $message';
  }

  @override
  String get login_accept_terms_error =>
      'Accept the Terms and Privacy Policy to continue.';

  @override
  String get login_subtitle => 'Sign in to Superwizor AI';

  @override
  String get login_title => 'Welcome back';

  @override
  String get login_forgot_password => 'Forgot password';

  @override
  String get login_btn_sign_in => 'Sign in';

  @override
  String get login_btn_sign_up => 'Sign up';

  @override
  String get login_register_title => 'Create account';

  @override
  String get login_register_subtitle => 'Join the therapist community';

  @override
  String get login_name_field => 'Full name';

  @override
  String get login_password_hint => 'Create password (min. 8 characters)';

  @override
  String get login_already_have_account => 'Already have an account? ';

  @override
  String get login_accept_prefix => 'I accept the ';

  @override
  String get login_accept_privacy => 'Privacy Policy';

  @override
  String get login_privacy_policy_title => 'Privacy Policy';

  @override
  String get forgot_err_user_not_found =>
      'We did not find an account with this address.';

  @override
  String get forgot_err_invalid_email => 'This email address looks invalid.';

  @override
  String get forgot_err_too_many_requests =>
      'Too many attempts. Wait a moment.';

  @override
  String get forgot_err_generic => 'Something went wrong. Please try again.';

  @override
  String get forgot_title => 'Reset password';

  @override
  String get forgot_desc_part1 =>
      'Enter the email address associated with your account. ';

  @override
  String get forgot_desc_part2 =>
      'We will send you a link to set a new password.';

  @override
  String get forgot_email_hint => 'Your email address';

  @override
  String get forgot_btn_send_link => 'Send link';

  @override
  String get forgot_check_mailbox_title => 'Check your mailbox';

  @override
  String get forgot_sent_msg_prefix => 'We sent a message to the address\n';

  @override
  String get forgot_step_open_email => 'Open your email inbox';

  @override
  String get forgot_step_click_link => 'Click the \"Reset password\" link';

  @override
  String get forgot_step_login => 'Set new password and log in';

  @override
  String get forgot_spam_check_part1 =>
      'Don\'t see the message? Check your spam folder. ';

  @override
  String get forgot_spam_check_part2 => 'Delivery may take up to 2 minutes.';

  @override
  String get forgot_btn_back_to_login => 'Return to login';

  @override
  String get forgot_btn_send_again => 'Resend';

  @override
  String get transcript_default_speaker_label => 'Voice';

  @override
  String home_error_toast(String error) {
    return 'Error: $error';
  }

  @override
  String get home_manage_edit_card => 'Edit details';

  @override
  String get home_manage_card => 'Manage client record';

  @override
  String get sort_filter_header_sorting => 'SORTING';

  @override
  String get sort_filter_last_activity => 'Last activity';

  @override
  String get sort_filter_last_activity_desc =>
      'Clients you recently worked with';

  @override
  String get sort_filter_long_unseen => 'Long unseen';

  @override
  String get sort_filter_no_sessions_longest_desc =>
      'Clients without sessions for the longest time';

  @override
  String get sort_filter_alphabetical => 'Alphabetically';

  @override
  String get sort_filter_alphabetical_desc => 'File names from A to Z';

  @override
  String get sort_filter_longest_processes => 'Longest processes';

  @override
  String get sort_filter_longest_processes_desc =>
      'Clients with the most sessions';

  @override
  String get sort_filter_show_only => 'SHOW ONLY';

  @override
  String get sort_filter_new_reports => 'New reports and analyses';

  @override
  String get sort_filter_ready_reports_desc =>
      'Ready AI reports or ongoing analysis';

  @override
  String get sort_filter_modality => 'MODALITY';

  @override
  String get sort_filter_clear_filters => 'Clear filters';

  @override
  String editPatient_error(String error) {
    return 'Error: $error';
  }

  @override
  String activeAnalysis_uploading_status(int errors, int progress) {
    String _temp0 = intl.Intl.pluralLogic(
      errors,
      locale: localeName,
      other: 'errors',
      one: 'error',
    );
    return 'Uploading: $errors $_temp0, $progress in progress.';
  }

  @override
  String get activeAnalysis_uploading_status_desc =>
      'Some files require attention, but the rest are uploading without interruption.';

  @override
  String get activeAnalysis_check_details => 'Check details';

  @override
  String get activeAnalysis_upload_attention => 'Upload requires attention.';

  @override
  String get activeAnalysis_upload_attention_desc =>
      'Session could not be uploaded. Check details.';

  @override
  String get activeAnalysis_quota_blocked_desc =>
      'Token pool has been exhausted. The session is safely saved and will be processed after the plan renews.';

  @override
  String get activeAnalysis_view_details => 'View details';

  @override
  String get activeAnalysis_upload_interrupted =>
      'Upload has been interrupted.';

  @override
  String get activeAnalysis_upload_interrupted_desc =>
      'Automatic resume will be attempted. Recording is safe.';

  @override
  String get activeAnalysis_preparing => 'Preparing recording.';

  @override
  String get activeAnalysis_preparing_desc =>
      'Session is encrypted before uploading to the server.';

  @override
  String get activeAnalysis_view_progress => 'View progress';

  @override
  String get activeAnalysis_converting => 'Converting audio file.';

  @override
  String get activeAnalysis_converting_desc =>
      'File format requires conversion. This will take a moment.';

  @override
  String get activeAnalysis_uploading =>
      'Session is being uploaded to the server.';

  @override
  String get activeAnalysis_uploading_desc =>
      'File is safely reaching the server. You can continue working.';

  @override
  String get activeAnalysis_analyzing_desc =>
      'Session is already on the server. Report will appear in a few minutes.';

  @override
  String get recording_countdown_preparing => 'Get ready…';

  @override
  String get drawer_btn_logout => 'Sign out';

  @override
  String get drawer_btn_delete_account => 'Delete account';

  @override
  String get avatar_customize_desc =>
      'Give your clients unique labels to quickly find them in records.';

  @override
  String get avatar_customize_background_color => 'BACKGROUND COLOR';

  @override
  String get profile_edit_desc =>
      'Provide your first name, last name, and professional title.';

  @override
  String get profile_edit_first_name => 'First name';

  @override
  String get profile_edit_professional_title =>
      'Professional title (e.g. MA, Psychologist)';

  @override
  String get report_detail_copy_content => 'Copy content';

  @override
  String get hard_delete_error => 'Deletion error';

  @override
  String get hard_delete_title => 'Account deletion is irreversible.';

  @override
  String hard_delete_body(String word) {
    return 'We will delete your therapist profile, all sessions, transcriptions, and reports. This action cannot be undone. If you are sure, type the word $word.';
  }

  @override
  String get hard_delete_btn_confirm => 'Delete permanently';

  @override
  String get common_done => 'Done';

  @override
  String get addPatient_additional_data_title => 'Additional data';

  @override
  String get addPatient_customize_label_title => 'Customize label';

  @override
  String get addPatient_avatar_format_hint =>
      'Letters, numbers or emoji (max 2)';

  @override
  String get clientDetails_subtitle => 'What are we working on today?';

  @override
  String get clientDetails_upload_file_btn => 'UPLOAD FILE FROM DISK';

  @override
  String get clientDetails_record_btn => 'START RECORDING';

  @override
  String get clientDetails_status_processing => 'Processing…';

  @override
  String get clientDetails_status_queued => 'In queue…';

  @override
  String get clientDetails_status_processing_audio => 'Processing audio…';

  @override
  String get clientDetails_status_finalizing => 'Finalizing session…';

  @override
  String home_delete_error_toast(String error) {
    return 'Deletion error: $error';
  }

  @override
  String get report_btn_copy_summary => 'Copy summary';

  @override
  String get report_btn_edit_summary => 'Edit summary';

  @override
  String get report_toast_summary_copied => 'Summary copied';

  @override
  String get report_toast_summary_updated => 'Summary updated';

  @override
  String get report_edit_summary_title => 'Edit summary';

  @override
  String get report_edit_summary_hint => 'Edit session summary...';

  @override
  String get report_toast_reports_copied => 'Reports copied to clipboard';

  @override
  String get report_tooltip_copy_reports => 'Copy reports';

  @override
  String get report_toast_section_copied => 'Section copied to clipboard';

  @override
  String get report_edit_section_title => 'Edit section';

  @override
  String get report_toast_section_updated => 'Section updated';

  @override
  String get menu_avatar_camera => 'Camera';

  @override
  String get menu_avatar_gallery => 'Gallery';

  @override
  String get common_or => 'or';

  @override
  String get activeAnalysis_analyzing => 'Analysis in progress.';

  @override
  String get activeAnalysis_processing => 'Processing session.';

  @override
  String get activeAnalysis_processing_desc =>
      'Your session is going through the next stages of analysis.';

  @override
  String get profile_edit_title => 'Edit profile.';

  @override
  String get profile_edit_last_name => 'Last name (optional)';

  @override
  String get profile_title_suggestion_1 => 'MA/MS';

  @override
  String get profile_title_suggestion_2 => 'PhD';

  @override
  String get profile_title_suggestion_3 => 'PhD, ScD';

  @override
  String get profile_title_suggestion_4 => 'Prof.';

  @override
  String get profile_title_suggestion_5 => 'Psychologist';

  @override
  String get profile_title_suggestion_6 => 'Psychotherapist';

  @override
  String get profile_title_suggestion_7 => 'Therapist';

  @override
  String get profile_title_suggestion_8 => 'Psychiatrist';

  @override
  String get profile_title_suggestion_9 => 'Coach';

  @override
  String get clientDetails_status_requires_attention => 'Requires attention';

  @override
  String get clientDetails_status_processing_label => 'Processing';

  @override
  String get clientDetails_status_new_session => 'New session';

  @override
  String get clientDetails_status_waiting_audio => 'Waiting for audio…';

  @override
  String get clientDetails_status_ready => 'Ready';

  @override
  String get clientDetails_status_new_report => 'New report';

  @override
  String get clientDetails_status_analyzing => 'AI analyzing…';

  @override
  String get clientDetails_status_uploading_label => 'Uploading…';

  @override
  String get clientDetails_status_error => 'Analysis error';

  @override
  String get clientDetails_session_title => 'Session';

  @override
  String get cancelUpload_warning_text =>
      'This session is currently being analyzed. Deleting it means permanent loss of the recording and transcription. This cannot be undone.';

  @override
  String get cancelUpload_delete_btn => 'Remove from analysis';

  @override
  String get cancelUpload_confirm_title => 'Are you sure?';

  @override
  String get cancelUpload_confirm_body =>
      'This operation cannot be undone. The recording and transcription will be permanently deleted.';

  @override
  String get cancelUpload_back_btn => 'Go back';

  @override
  String get forgot_password_link_expiry => 'Link expires after 1 hour';

  @override
  String home_report_ready_toast(String name) {
    return 'Report ready, $name 🎉';
  }

  @override
  String get appLock_title => 'App locked';

  @override
  String get appLock_subtitle => 'Unlock to access your records';

  @override
  String get appLock_unlock => 'Unlock';

  @override
  String get appLock_reason => 'Authenticate to access Superwizor';

  @override
  String recording_reminder_toast(String duration) {
    return 'Still recording — $duration';
  }

  @override
  String recording_autopause_remaining(String time) {
    return 'Auto-pause in $time';
  }

  @override
  String get settings_recording_section => 'Recording';

  @override
  String get settings_recording_autopause => 'Auto-pause';

  @override
  String settings_recording_autopause_value(int minutes) {
    return '$minutes min';
  }

  @override
  String get settings_recording_reminder => 'Recording reminder';

  @override
  String get settings_recording_reminder_off => 'Off';

  @override
  String get settings_recording_reminder_sound => 'Reminder sound';

  @override
  String get settings_recording_reminder_sound_warning =>
      'The sound will be captured in the session';

  @override
  String get settings_recording_reminder_sound_hint =>
      'When a reminder is on, it also plays a sound (which is captured in the session too).';

  @override
  String get deactivated_title => 'Account inactive';

  @override
  String get deactivated_body =>
      'Your account has been deactivated by your organization\'s administrator. Contact them to restore access.';

  @override
  String get deactivated_logout => 'Sign out';

  @override
  String get client_home_title => 'Your sessions';

  @override
  String get client_home_subtitle =>
      'Materials shared by your therapist and your notes.';

  @override
  String get client_home_empty =>
      'Your therapist hasn\'t shared any materials yet.';

  @override
  String client_home_error(String error) {
    return 'Failed to load: $error';
  }

  @override
  String client_kartoteka_therapist(String name) {
    return 'Therapist: $name';
  }

  @override
  String client_kartoteka_counts(int sessions, int notes) {
    return '$sessions sessions · $notes notes';
  }

  @override
  String client_unread_badge(int count) {
    return '$count new';
  }

  @override
  String get client_tab_sessions => 'Sessions';

  @override
  String get client_tab_notes => 'Notes';

  @override
  String get client_sessions_empty => 'No shared sessions yet.';

  @override
  String client_session_title(int number) {
    return 'Session $number';
  }

  @override
  String get client_session_no_transcript =>
      'The transcript is not available yet.';

  @override
  String get client_notes_empty =>
      'No notes yet. Create one and send it to your therapist.';

  @override
  String get client_note_from_therapist => 'From your therapist';

  @override
  String get client_note_mine => 'My note';

  @override
  String get client_note_new => 'New note';

  @override
  String get client_note_title_hint => 'Title';

  @override
  String get client_note_text_hint => 'Your thoughts…';

  @override
  String get client_note_send => 'Send to therapist';

  @override
  String get client_note_sent => 'Note sent to your therapist.';

  @override
  String get client_note_empty_error => 'The note cannot be empty.';

  @override
  String get client_logout => 'Sign out';

  @override
  String get invite_client_title => 'Invite client';

  @override
  String get invite_client_desc =>
      'The client will receive an e-mail with a link to a secure panel where they can see shared sessions and notes and write notes back to you.';

  @override
  String get invite_client_email_label => 'Client e-mail';

  @override
  String get invite_client_send => 'Send invitation';

  @override
  String get invite_client_resend => 'Send again';

  @override
  String get invite_client_sent => 'Invitation sent.';

  @override
  String invite_client_status_pending(String email, String date) {
    return 'Invitation pending — sent to $email, valid until $date.';
  }

  @override
  String get invite_client_status_active => 'Client panel is active.';

  @override
  String get invite_client_status_inactive =>
      'The client account is deactivated.';

  @override
  String get invite_client_email_taken =>
      'This e-mail is already linked to another account.';

  @override
  String get invite_client_email_missing => 'Enter a valid client e-mail.';

  @override
  String get invite_client_error =>
      'Failed to send the invitation. Please try again.';

  @override
  String get share_with_client => 'Share in the client panel';

  @override
  String get unshare_with_client => 'Unshare';

  @override
  String get share_with_client_desc =>
      'The client will see this item in their panel';

  @override
  String share_note_shared_at(String date) {
    return 'Shared $date';
  }

  @override
  String get share_shared_badge => 'Shared';

  @override
  String get share_session_label => 'Share with client';

  @override
  String get share_toggled_on => 'Shared in the client panel.';

  @override
  String get share_toggled_off => 'Sharing removed.';

  @override
  String get share_toggle_error => 'Could not change sharing.';

  @override
  String get note_from_client => 'From client';

  @override
  String get note_from_client_new => 'NEW';

  @override
  String get home_menu_invite_client_desc =>
      'Send an e-mail with client panel access';

  @override
  String get client_new_badge => 'NEW';

  @override
  String get client_session_transcript_chip => 'Transcript';
}
