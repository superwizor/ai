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
  String get addPatient_email_hint => 'Optional — for future notifications';

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
  String get stepper_step1_queued => 'Audio waiting in upload queue.';

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

  @override
  String get report_rating_thumbs_up_tooltip => 'Good report';

  @override
  String get report_rating_thumbs_down_tooltip => 'Something is off';

  @override
  String get report_rating_saved_positive => 'Thanks for the positive rating.';

  @override
  String get report_rating_saved_negative =>
      'Thanks — we\'ll factor this into future reports.';

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
      'Changed — future reports will reflect this.';

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
      'You can still record the session — audio will be securely encrypted and saved locally on your device. After upgrading your plan or pool renewal, you can resume processing from the Patient File.';

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
  String get subscription_tier_solo => 'Solo';

  @override
  String get subscription_tier_pro => 'Pro';

  @override
  String get subscription_tier_clinic => 'Clinic';

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
      'The plan can\'t be sent — the patient has no e-mail address on file. Add an e-mail in the client record.';

  @override
  String get action_plan_send_confirm_title => 'Send the action plan?';

  @override
  String action_plan_send_confirm_body(String email) {
    return 'The plan will be sent to: $email';
  }

  @override
  String get action_plan_send_sim_caption =>
      '(simulation — e-mail delivery will be wired to the backend)';

  @override
  String get action_plan_send_cancel => 'Cancel';

  @override
  String get action_plan_send_confirm_action => 'Send';

  @override
  String get action_plan_sent_toast =>
      'Action plan saved and sent (simulation)';

  @override
  String get action_plan_default_title => 'Action plan';

  @override
  String get action_plan_fill_email_hint =>
      'Fill in the client\'s e-mail address and resend.';
}
