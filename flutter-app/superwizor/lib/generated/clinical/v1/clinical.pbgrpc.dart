// This is a generated file - do not edit.
//
// Generated from clinical/v1/clinical.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import '../../billing/v1/billing.pb.dart' as $2;
import 'clinical.pb.dart' as $0;

export 'clinical.pb.dart';

@$pb.GrpcServiceName('clinical.v1.ClinicalService')
class ClinicalServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ClinicalServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.PatientFile> createPatientFile(
    $0.CreatePatientFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createPatientFile, request, options: options);
  }

  $grpc.ResponseFuture<$0.PatientFile> getPatientFile(
    $0.GetPatientFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPatientFile, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListPatientFilesResponse> listPatientFiles(
    $0.ListPatientFilesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPatientFiles, request, options: options);
  }

  $grpc.ResponseFuture<$0.PatientFile> updatePatientFile(
    $0.UpdatePatientFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updatePatientFile, request, options: options);
  }

  /// Hard delete since 000012 — cascades through all sessions / transcripts /
  /// reports / audio_uploads. Since 000013 it ALSO drops the paired
  /// users(role='PATIENT') row in the same transaction. PHI gone
  /// permanently (RODO right-to-erasure).
  $grpc.ResponseFuture<$1.Empty> deletePatientFile(
    $0.DeletePatientFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deletePatientFile, request, options: options);
  }

  /// Patient-user CRUD (added with migration 000013). These are
  /// SEPARATE from working_alias / initial_complaint edits — therapist
  /// can update one without touching the other.
  $grpc.ResponseFuture<$0.PatientFile> updatePatientUser(
    $0.UpdatePatientUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updatePatientUser, request, options: options);
  }

  /// RODO-style erasure on the patient axis. CASCADEs through every
  /// patient_file referencing this user (migration 000014), and from
  /// there through sessions / transcripts / reports / etc. Publishes
  /// one session.deleted Pub/Sub event per cascaded session for
  /// Firestore + inbox cleanup. Nothing left to return → Empty.
  $grpc.ResponseFuture<$1.Empty> deletePatientUser(
    $0.DeletePatientUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deletePatientUser, request, options: options);
  }

  /// Patient notes + action plan (docs/22).
  $grpc.ResponseFuture<$0.PatientNote> createPatientNote(
    $0.CreatePatientNoteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createPatientNote, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListPatientNotesResponse> listPatientNotes(
    $0.ListPatientNotesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPatientNotes, request, options: options);
  }

  $grpc.ResponseFuture<$0.PatientNote> updatePatientNote(
    $0.UpdatePatientNoteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updatePatientNote, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deletePatientNote(
    $0.DeletePatientNoteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deletePatientNote, request, options: options);
  }

  $grpc.ResponseFuture<$0.ActionPlanDraft> getActionPlanDraft(
    $0.GetActionPlanDraftRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getActionPlanDraft, request, options: options);
  }

  $grpc.ResponseFuture<$0.SavePatientNoteResponse> savePatientNote(
    $0.SavePatientNoteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$savePatientNote, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListModalitiesResponse> listModalities(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listModalities, request, options: options);
  }

  $grpc.ResponseFuture<$0.HealthCheckResponse> healthCheck(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$healthCheck, request, options: options);
  }

  /// Thin proxy to billing-svc.GetSubscription, scoped to the
  /// calling user's organization. Lets Flutter read the canonical
  /// counter snapshot (used / reserved / limit / remaining + plan)
  /// without exposing billing-svc directly to public clients.
  /// Authentication: identity-svc-validated Firebase JWT (same as
  /// every other clinical-svc RPC). Organization is derived from
  /// users.organization_id — clients never specify it.
  $grpc.ResponseFuture<$2.Subscription> getMyBillingState(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMyBillingState, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateSpeakerLabelsResponse> updateSpeakerLabels(
    $0.UpdateSpeakerLabelsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateSpeakerLabels, request, options: options);
  }

  /// Sessions and Analysis
  $grpc.ResponseFuture<$0.ListSessionsResponse> listSessions(
    $0.ListSessionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listSessions, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetSessionDetailsResponse> getSessionDetails(
    $0.GetSessionDetailsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSessionDetails, request, options: options);
  }

  /// Rename a single session — currently only `name` is mutable.
  $grpc.ResponseFuture<$0.Session> updateSession(
    $0.UpdateSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateSession, request, options: options);
  }

  /// Hard delete a single session — cascades transcripts/reports/hitop.
  /// Publishes session.deleted Pub/Sub event for downstream Firestore +
  /// inbox cleanup.
  $grpc.ResponseFuture<$1.Empty> deleteSession(
    $0.DeleteSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteSession, request, options: options);
  }

  /// User-initiated cancellation of an IN-PROGRESS session
  /// (PENDING_UPLOAD … ANALYZING). Flips status to CANCELLED_BY_USER,
  /// releases the held billing reservation, and cancels the
  /// audio_uploads row. Hidden from the kartoteka afterward. Idempotent
  /// (re-cancel on an already-terminal session returns OK). Rejects
  /// COMPLETED sessions — those use DeleteSession. See
  /// feat/tokens-exhausted.
  $grpc.ResponseFuture<$1.Empty> cancelSession(
    $0.CancelSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$cancelSession, request, options: options);
  }

  /// ─── Cross-device preference sync (migration 000059) ───
  /// Marks a completed session's report as viewed by the therapist.
  /// Idempotent — re-calling on an already-viewed session is a no-op.
  /// Replaces the Flutter-local SharedPreferences viewed_reports tracking.
  $grpc.ResponseFuture<$1.Empty> markReportViewed(
    $0.MarkReportViewedRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$markReportViewed, request, options: options);
  }

  /// Sets or clears the avatar customization (label + color) on a
  /// patient file. Empty avatar_config clears to defaults.
  $grpc.ResponseFuture<$1.Empty> setAvatarConfig(
    $0.SetAvatarConfigRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setAvatarConfig, request, options: options);
  }

  /// ─── Report ratings (docs/10_REPORT_CUSTOMIZATION.md §5) ───
  /// 👍/👎 rating on a generated report. Idempotent on
  /// (report_id, therapist_id) — re-rating UPSERTs in place.
  $grpc.ResponseFuture<$0.RateReportResponse> rateReport(
    $0.RateReportRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$rateReport, request, options: options);
  }

  /// Read the current rating (if any) the therapist gave a report.
  /// Returns NotFound if unrated.
  $grpc.ResponseFuture<$0.ReportRating> getReportRating(
    $0.GetReportRatingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getReportRating, request, options: options);
  }

  /// Returns a single preference-change suggestion if the therapist's
  /// recent ratings warrant one (≥3 negatives of same chip category
  /// in last 5 reports). Returns an empty PreferenceSuggestion with
  /// empty suggestion_id when no suggestion is active — Flutter
  /// hides the banner in that case. Called in parallel with
  /// identity-svc.GetReportPreferences on settings entry.
  $grpc.ResponseFuture<$0.PreferenceSuggestion> getActiveSuggestion(
    $0.GetActiveSuggestionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getActiveSuggestion, request, options: options);
  }

  /// Records that a suggestion-engine banner was either shown,
  /// applied, or dismissed. Telemetry only; safe to fire-and-forget.
  $grpc.ResponseFuture<$1.Empty> logPreferenceSuggestion(
    $0.LogPreferenceSuggestionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$logPreferenceSuggestion, request,
        options: options);
  }

  /// ─── SUPERWIZOR_ADMIN — cross-org session activity (2026-05-29) ──
  ///
  /// Read-only listing of recent therapist session activity for the
  /// /admin/sessions page. Gated on x-superwizor-role=SUPERWIZOR_ADMIN
  /// via the existing Connect auth interceptor; org_admin / therapist
  /// tokens get PermissionDenied.
  ///
  /// Filters (all AND-combined): created_at window, free-text on
  /// therapist name + email. CSV export is implemented client-side by
  /// requesting page_size up to MaxCsvPageSize and serialising the
  /// response.
  $grpc.ResponseFuture<$0.TrackEventsResponse> trackEvents(
    $0.TrackEventsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$trackEvents, request, options: options);
  }

  $grpc.ResponseFuture<$0.AdminListSessionsResponse> adminListSessions(
    $0.AdminListSessionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminListSessions, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetAdminAnalyticsResponse> getAdminAnalytics(
    $0.GetAdminAnalyticsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAdminAnalytics, request, options: options);
  }

  /// ─── Admin Prompt Studio (docs/31) — SUPERWIZOR_ADMIN only ───
  /// Versioned editor for modalities.therapist_ai_general_prompt.
  /// The live column is what llm-worker reads per report; every update
  /// bumps it AND appends a snapshot to modality_prompt_versions in one
  /// transaction. Restore = AdminUpdateModalityPrompt with historical
  /// text (no separate rollback RPC).
  $grpc.ResponseFuture<$0.AdminListModalityPromptsResponse>
      adminListModalityPrompts(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminListModalityPrompts, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.AdminGetModalityPromptHistoryResponse>
      adminGetModalityPromptHistory(
    $0.AdminGetModalityPromptHistoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminGetModalityPromptHistory, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.AdminUpdateModalityPromptResponse>
      adminUpdateModalityPrompt(
    $0.AdminUpdateModalityPromptRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminUpdateModalityPrompt, request,
        options: options);
  }

  /// ─── Org analytics (docs/38 §7) — ORG_ADMIN only ───
  /// Per-therapist metadata aggregates for the caller's organization.
  /// HARD privacy boundary (§7.3): counts and durations ONLY — never
  /// transcripts, reports, notes, or patient identity. Org resolved
  /// from the auth context, never from the request.
  $grpc.ResponseFuture<$0.OrgTherapistMetricsResponse> getOrgTherapistMetrics(
    $0.GetOrgTherapistMetricsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getOrgTherapistMetrics, request,
        options: options);
  }

  /// Org-scoped analytics widgets (docs/38 §7.2) — the /org Analityka
  /// tab's charts: WAU, weekly session/duration trends, day×hour
  /// heatmap, per-therapist token utilization, and the session counts
  /// behind the "time saved on reporting" KPI. Same §7.3 privacy
  /// boundary: aggregates only.
  $grpc.ResponseFuture<$0.GetOrgAnalyticsResponse> getOrgAnalytics(
    $0.GetOrgAnalyticsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getOrgAnalytics, request, options: options);
  }

  /// ─── Client panel (docs/39) — role PATIENT, self-access ───
  /// Separate read-only family gated by requireClientFileAccess
  /// (caller is the kartoteka's patient). Default-deny: only rows the
  /// therapist explicitly shared are visible (D2). No reports, no
  /// therapist-private notes — ever.
  $grpc.ResponseFuture<$0.ClientOverview> clientGetMyOverview(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clientGetMyOverview, request, options: options);
  }

  $grpc.ResponseFuture<$0.ClientListSessionsResponse> clientListSessions(
    $0.ClientListSessionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clientListSessions, request, options: options);
  }

  $grpc.ResponseFuture<$0.ClientGetTranscriptResponse> clientGetTranscript(
    $0.ClientGetTranscriptRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clientGetTranscript, request, options: options);
  }

  $grpc.ResponseFuture<$0.ClientListNotesResponse> clientListNotes(
    $0.ClientListNotesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clientListNotes, request, options: options);
  }

  $grpc.ResponseFuture<$0.ClientNote> clientCreateNote(
    $0.ClientCreateNoteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clientCreateNote, request, options: options);
  }

  $grpc.ResponseFuture<$0.ClientNote> clientSendNote(
    $0.ClientSendNoteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clientSendNote, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> clientMarkNoteRead(
    $0.ClientMarkNoteReadRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clientMarkNoteRead, request, options: options);
  }

  /// docs/39 PR13 — panel management.
  ///   ClientDeleteNote: HARD-delete the client's OWN note (CLIENT_NOTE)
  ///     everywhere, including from the therapist if it was already sent.
  ///   ClientHideItem: dismiss a therapist-shared session/note from the
  ///     client's panel only (client_hidden_at) — therapist keeps it.
  $grpc.ResponseFuture<$1.Empty> clientDeleteNote(
    $0.ClientDeleteNoteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clientDeleteNote, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> clientHideItem(
    $0.ClientHideItemRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$clientHideItem, request, options: options);
  }

  /// Therapist-side sharing toggles (docs/39 D2/D6) — gated by
  /// requireTherapistDataAccess like every kartoteka mutation.
  $grpc.ResponseFuture<$1.Empty> shareSessionWithClient(
    $0.ShareSessionWithClientRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$shareSessionWithClient, request,
        options: options);
  }

  $grpc.ResponseFuture<$1.Empty> shareNoteWithClient(
    $0.ShareNoteWithClientRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$shareNoteWithClient, request, options: options);
  }

  /// ─── RODO/GDPR DSAR endpoints ───
  /// Export all clinical and personal data related to a patient file,
  /// decrypting all PHI columns using KMS before returning.
  $grpc.ResponseFuture<$0.ExportPatientDataResponse> exportPatientData(
    $0.ExportPatientDataRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$exportPatientData, request, options: options);
  }

  /// Cascaded soft-delete of all patient data (patient file, sessions, notes).
  /// The daily hard-delete purger will physically delete the records after 30 days.
  $grpc.ResponseFuture<$1.Empty> deletePatientData(
    $0.DeletePatientDataRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deletePatientData, request, options: options);
  }

  // method descriptors

  static final _$createPatientFile =
      $grpc.ClientMethod<$0.CreatePatientFileRequest, $0.PatientFile>(
          '/clinical.v1.ClinicalService/CreatePatientFile',
          ($0.CreatePatientFileRequest value) => value.writeToBuffer(),
          $0.PatientFile.fromBuffer);
  static final _$getPatientFile =
      $grpc.ClientMethod<$0.GetPatientFileRequest, $0.PatientFile>(
          '/clinical.v1.ClinicalService/GetPatientFile',
          ($0.GetPatientFileRequest value) => value.writeToBuffer(),
          $0.PatientFile.fromBuffer);
  static final _$listPatientFiles = $grpc.ClientMethod<
          $0.ListPatientFilesRequest, $0.ListPatientFilesResponse>(
      '/clinical.v1.ClinicalService/ListPatientFiles',
      ($0.ListPatientFilesRequest value) => value.writeToBuffer(),
      $0.ListPatientFilesResponse.fromBuffer);
  static final _$updatePatientFile =
      $grpc.ClientMethod<$0.UpdatePatientFileRequest, $0.PatientFile>(
          '/clinical.v1.ClinicalService/UpdatePatientFile',
          ($0.UpdatePatientFileRequest value) => value.writeToBuffer(),
          $0.PatientFile.fromBuffer);
  static final _$deletePatientFile =
      $grpc.ClientMethod<$0.DeletePatientFileRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/DeletePatientFile',
          ($0.DeletePatientFileRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$updatePatientUser =
      $grpc.ClientMethod<$0.UpdatePatientUserRequest, $0.PatientFile>(
          '/clinical.v1.ClinicalService/UpdatePatientUser',
          ($0.UpdatePatientUserRequest value) => value.writeToBuffer(),
          $0.PatientFile.fromBuffer);
  static final _$deletePatientUser =
      $grpc.ClientMethod<$0.DeletePatientUserRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/DeletePatientUser',
          ($0.DeletePatientUserRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$createPatientNote =
      $grpc.ClientMethod<$0.CreatePatientNoteRequest, $0.PatientNote>(
          '/clinical.v1.ClinicalService/CreatePatientNote',
          ($0.CreatePatientNoteRequest value) => value.writeToBuffer(),
          $0.PatientNote.fromBuffer);
  static final _$listPatientNotes = $grpc.ClientMethod<
          $0.ListPatientNotesRequest, $0.ListPatientNotesResponse>(
      '/clinical.v1.ClinicalService/ListPatientNotes',
      ($0.ListPatientNotesRequest value) => value.writeToBuffer(),
      $0.ListPatientNotesResponse.fromBuffer);
  static final _$updatePatientNote =
      $grpc.ClientMethod<$0.UpdatePatientNoteRequest, $0.PatientNote>(
          '/clinical.v1.ClinicalService/UpdatePatientNote',
          ($0.UpdatePatientNoteRequest value) => value.writeToBuffer(),
          $0.PatientNote.fromBuffer);
  static final _$deletePatientNote =
      $grpc.ClientMethod<$0.DeletePatientNoteRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/DeletePatientNote',
          ($0.DeletePatientNoteRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$getActionPlanDraft =
      $grpc.ClientMethod<$0.GetActionPlanDraftRequest, $0.ActionPlanDraft>(
          '/clinical.v1.ClinicalService/GetActionPlanDraft',
          ($0.GetActionPlanDraftRequest value) => value.writeToBuffer(),
          $0.ActionPlanDraft.fromBuffer);
  static final _$savePatientNote =
      $grpc.ClientMethod<$0.SavePatientNoteRequest, $0.SavePatientNoteResponse>(
          '/clinical.v1.ClinicalService/SavePatientNote',
          ($0.SavePatientNoteRequest value) => value.writeToBuffer(),
          $0.SavePatientNoteResponse.fromBuffer);
  static final _$listModalities =
      $grpc.ClientMethod<$1.Empty, $0.ListModalitiesResponse>(
          '/clinical.v1.ClinicalService/ListModalities',
          ($1.Empty value) => value.writeToBuffer(),
          $0.ListModalitiesResponse.fromBuffer);
  static final _$healthCheck =
      $grpc.ClientMethod<$1.Empty, $0.HealthCheckResponse>(
          '/clinical.v1.ClinicalService/HealthCheck',
          ($1.Empty value) => value.writeToBuffer(),
          $0.HealthCheckResponse.fromBuffer);
  static final _$getMyBillingState =
      $grpc.ClientMethod<$1.Empty, $2.Subscription>(
          '/clinical.v1.ClinicalService/GetMyBillingState',
          ($1.Empty value) => value.writeToBuffer(),
          $2.Subscription.fromBuffer);
  static final _$updateSpeakerLabels = $grpc.ClientMethod<
          $0.UpdateSpeakerLabelsRequest, $0.UpdateSpeakerLabelsResponse>(
      '/clinical.v1.ClinicalService/UpdateSpeakerLabels',
      ($0.UpdateSpeakerLabelsRequest value) => value.writeToBuffer(),
      $0.UpdateSpeakerLabelsResponse.fromBuffer);
  static final _$listSessions =
      $grpc.ClientMethod<$0.ListSessionsRequest, $0.ListSessionsResponse>(
          '/clinical.v1.ClinicalService/ListSessions',
          ($0.ListSessionsRequest value) => value.writeToBuffer(),
          $0.ListSessionsResponse.fromBuffer);
  static final _$getSessionDetails = $grpc.ClientMethod<
          $0.GetSessionDetailsRequest, $0.GetSessionDetailsResponse>(
      '/clinical.v1.ClinicalService/GetSessionDetails',
      ($0.GetSessionDetailsRequest value) => value.writeToBuffer(),
      $0.GetSessionDetailsResponse.fromBuffer);
  static final _$updateSession =
      $grpc.ClientMethod<$0.UpdateSessionRequest, $0.Session>(
          '/clinical.v1.ClinicalService/UpdateSession',
          ($0.UpdateSessionRequest value) => value.writeToBuffer(),
          $0.Session.fromBuffer);
  static final _$deleteSession =
      $grpc.ClientMethod<$0.DeleteSessionRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/DeleteSession',
          ($0.DeleteSessionRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$cancelSession =
      $grpc.ClientMethod<$0.CancelSessionRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/CancelSession',
          ($0.CancelSessionRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$markReportViewed =
      $grpc.ClientMethod<$0.MarkReportViewedRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/MarkReportViewed',
          ($0.MarkReportViewedRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$setAvatarConfig =
      $grpc.ClientMethod<$0.SetAvatarConfigRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/SetAvatarConfig',
          ($0.SetAvatarConfigRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$rateReport =
      $grpc.ClientMethod<$0.RateReportRequest, $0.RateReportResponse>(
          '/clinical.v1.ClinicalService/RateReport',
          ($0.RateReportRequest value) => value.writeToBuffer(),
          $0.RateReportResponse.fromBuffer);
  static final _$getReportRating =
      $grpc.ClientMethod<$0.GetReportRatingRequest, $0.ReportRating>(
          '/clinical.v1.ClinicalService/GetReportRating',
          ($0.GetReportRatingRequest value) => value.writeToBuffer(),
          $0.ReportRating.fromBuffer);
  static final _$getActiveSuggestion = $grpc.ClientMethod<
          $0.GetActiveSuggestionRequest, $0.PreferenceSuggestion>(
      '/clinical.v1.ClinicalService/GetActiveSuggestion',
      ($0.GetActiveSuggestionRequest value) => value.writeToBuffer(),
      $0.PreferenceSuggestion.fromBuffer);
  static final _$logPreferenceSuggestion =
      $grpc.ClientMethod<$0.LogPreferenceSuggestionRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/LogPreferenceSuggestion',
          ($0.LogPreferenceSuggestionRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$trackEvents =
      $grpc.ClientMethod<$0.TrackEventsRequest, $0.TrackEventsResponse>(
          '/clinical.v1.ClinicalService/TrackEvents',
          ($0.TrackEventsRequest value) => value.writeToBuffer(),
          $0.TrackEventsResponse.fromBuffer);
  static final _$adminListSessions = $grpc.ClientMethod<
          $0.AdminListSessionsRequest, $0.AdminListSessionsResponse>(
      '/clinical.v1.ClinicalService/AdminListSessions',
      ($0.AdminListSessionsRequest value) => value.writeToBuffer(),
      $0.AdminListSessionsResponse.fromBuffer);
  static final _$getAdminAnalytics = $grpc.ClientMethod<
          $0.GetAdminAnalyticsRequest, $0.GetAdminAnalyticsResponse>(
      '/clinical.v1.ClinicalService/GetAdminAnalytics',
      ($0.GetAdminAnalyticsRequest value) => value.writeToBuffer(),
      $0.GetAdminAnalyticsResponse.fromBuffer);
  static final _$adminListModalityPrompts =
      $grpc.ClientMethod<$1.Empty, $0.AdminListModalityPromptsResponse>(
          '/clinical.v1.ClinicalService/AdminListModalityPrompts',
          ($1.Empty value) => value.writeToBuffer(),
          $0.AdminListModalityPromptsResponse.fromBuffer);
  static final _$adminGetModalityPromptHistory = $grpc.ClientMethod<
          $0.AdminGetModalityPromptHistoryRequest,
          $0.AdminGetModalityPromptHistoryResponse>(
      '/clinical.v1.ClinicalService/AdminGetModalityPromptHistory',
      ($0.AdminGetModalityPromptHistoryRequest value) => value.writeToBuffer(),
      $0.AdminGetModalityPromptHistoryResponse.fromBuffer);
  static final _$adminUpdateModalityPrompt = $grpc.ClientMethod<
          $0.AdminUpdateModalityPromptRequest,
          $0.AdminUpdateModalityPromptResponse>(
      '/clinical.v1.ClinicalService/AdminUpdateModalityPrompt',
      ($0.AdminUpdateModalityPromptRequest value) => value.writeToBuffer(),
      $0.AdminUpdateModalityPromptResponse.fromBuffer);
  static final _$getOrgTherapistMetrics = $grpc.ClientMethod<
          $0.GetOrgTherapistMetricsRequest, $0.OrgTherapistMetricsResponse>(
      '/clinical.v1.ClinicalService/GetOrgTherapistMetrics',
      ($0.GetOrgTherapistMetricsRequest value) => value.writeToBuffer(),
      $0.OrgTherapistMetricsResponse.fromBuffer);
  static final _$getOrgAnalytics =
      $grpc.ClientMethod<$0.GetOrgAnalyticsRequest, $0.GetOrgAnalyticsResponse>(
          '/clinical.v1.ClinicalService/GetOrgAnalytics',
          ($0.GetOrgAnalyticsRequest value) => value.writeToBuffer(),
          $0.GetOrgAnalyticsResponse.fromBuffer);
  static final _$clientGetMyOverview =
      $grpc.ClientMethod<$1.Empty, $0.ClientOverview>(
          '/clinical.v1.ClinicalService/ClientGetMyOverview',
          ($1.Empty value) => value.writeToBuffer(),
          $0.ClientOverview.fromBuffer);
  static final _$clientListSessions = $grpc.ClientMethod<
          $0.ClientListSessionsRequest, $0.ClientListSessionsResponse>(
      '/clinical.v1.ClinicalService/ClientListSessions',
      ($0.ClientListSessionsRequest value) => value.writeToBuffer(),
      $0.ClientListSessionsResponse.fromBuffer);
  static final _$clientGetTranscript = $grpc.ClientMethod<
          $0.ClientGetTranscriptRequest, $0.ClientGetTranscriptResponse>(
      '/clinical.v1.ClinicalService/ClientGetTranscript',
      ($0.ClientGetTranscriptRequest value) => value.writeToBuffer(),
      $0.ClientGetTranscriptResponse.fromBuffer);
  static final _$clientListNotes =
      $grpc.ClientMethod<$0.ClientListNotesRequest, $0.ClientListNotesResponse>(
          '/clinical.v1.ClinicalService/ClientListNotes',
          ($0.ClientListNotesRequest value) => value.writeToBuffer(),
          $0.ClientListNotesResponse.fromBuffer);
  static final _$clientCreateNote =
      $grpc.ClientMethod<$0.ClientCreateNoteRequest, $0.ClientNote>(
          '/clinical.v1.ClinicalService/ClientCreateNote',
          ($0.ClientCreateNoteRequest value) => value.writeToBuffer(),
          $0.ClientNote.fromBuffer);
  static final _$clientSendNote =
      $grpc.ClientMethod<$0.ClientSendNoteRequest, $0.ClientNote>(
          '/clinical.v1.ClinicalService/ClientSendNote',
          ($0.ClientSendNoteRequest value) => value.writeToBuffer(),
          $0.ClientNote.fromBuffer);
  static final _$clientMarkNoteRead =
      $grpc.ClientMethod<$0.ClientMarkNoteReadRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/ClientMarkNoteRead',
          ($0.ClientMarkNoteReadRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$clientDeleteNote =
      $grpc.ClientMethod<$0.ClientDeleteNoteRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/ClientDeleteNote',
          ($0.ClientDeleteNoteRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$clientHideItem =
      $grpc.ClientMethod<$0.ClientHideItemRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/ClientHideItem',
          ($0.ClientHideItemRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$shareSessionWithClient =
      $grpc.ClientMethod<$0.ShareSessionWithClientRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/ShareSessionWithClient',
          ($0.ShareSessionWithClientRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$shareNoteWithClient =
      $grpc.ClientMethod<$0.ShareNoteWithClientRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/ShareNoteWithClient',
          ($0.ShareNoteWithClientRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$exportPatientData = $grpc.ClientMethod<
          $0.ExportPatientDataRequest, $0.ExportPatientDataResponse>(
      '/clinical.v1.ClinicalService/ExportPatientData',
      ($0.ExportPatientDataRequest value) => value.writeToBuffer(),
      $0.ExportPatientDataResponse.fromBuffer);
  static final _$deletePatientData =
      $grpc.ClientMethod<$0.DeletePatientDataRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/DeletePatientData',
          ($0.DeletePatientDataRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
}

@$pb.GrpcServiceName('clinical.v1.ClinicalService')
abstract class ClinicalServiceBase extends $grpc.Service {
  $core.String get $name => 'clinical.v1.ClinicalService';

  ClinicalServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreatePatientFileRequest, $0.PatientFile>(
        'CreatePatientFile',
        createPatientFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreatePatientFileRequest.fromBuffer(value),
        ($0.PatientFile value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPatientFileRequest, $0.PatientFile>(
        'GetPatientFile',
        getPatientFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetPatientFileRequest.fromBuffer(value),
        ($0.PatientFile value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListPatientFilesRequest,
            $0.ListPatientFilesResponse>(
        'ListPatientFiles',
        listPatientFiles_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListPatientFilesRequest.fromBuffer(value),
        ($0.ListPatientFilesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdatePatientFileRequest, $0.PatientFile>(
        'UpdatePatientFile',
        updatePatientFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdatePatientFileRequest.fromBuffer(value),
        ($0.PatientFile value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeletePatientFileRequest, $1.Empty>(
        'DeletePatientFile',
        deletePatientFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeletePatientFileRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdatePatientUserRequest, $0.PatientFile>(
        'UpdatePatientUser',
        updatePatientUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdatePatientUserRequest.fromBuffer(value),
        ($0.PatientFile value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeletePatientUserRequest, $1.Empty>(
        'DeletePatientUser',
        deletePatientUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeletePatientUserRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreatePatientNoteRequest, $0.PatientNote>(
        'CreatePatientNote',
        createPatientNote_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreatePatientNoteRequest.fromBuffer(value),
        ($0.PatientNote value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListPatientNotesRequest,
            $0.ListPatientNotesResponse>(
        'ListPatientNotes',
        listPatientNotes_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListPatientNotesRequest.fromBuffer(value),
        ($0.ListPatientNotesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdatePatientNoteRequest, $0.PatientNote>(
        'UpdatePatientNote',
        updatePatientNote_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdatePatientNoteRequest.fromBuffer(value),
        ($0.PatientNote value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeletePatientNoteRequest, $1.Empty>(
        'DeletePatientNote',
        deletePatientNote_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeletePatientNoteRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetActionPlanDraftRequest, $0.ActionPlanDraft>(
            'GetActionPlanDraft',
            getActionPlanDraft_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetActionPlanDraftRequest.fromBuffer(value),
            ($0.ActionPlanDraft value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SavePatientNoteRequest,
            $0.SavePatientNoteResponse>(
        'SavePatientNote',
        savePatientNote_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SavePatientNoteRequest.fromBuffer(value),
        ($0.SavePatientNoteResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.ListModalitiesResponse>(
        'ListModalities',
        listModalities_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.ListModalitiesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.HealthCheckResponse>(
        'HealthCheck',
        healthCheck_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.HealthCheckResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $2.Subscription>(
        'GetMyBillingState',
        getMyBillingState_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($2.Subscription value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateSpeakerLabelsRequest,
            $0.UpdateSpeakerLabelsResponse>(
        'UpdateSpeakerLabels',
        updateSpeakerLabels_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateSpeakerLabelsRequest.fromBuffer(value),
        ($0.UpdateSpeakerLabelsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListSessionsRequest, $0.ListSessionsResponse>(
            'ListSessions',
            listSessions_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListSessionsRequest.fromBuffer(value),
            ($0.ListSessionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetSessionDetailsRequest,
            $0.GetSessionDetailsResponse>(
        'GetSessionDetails',
        getSessionDetails_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetSessionDetailsRequest.fromBuffer(value),
        ($0.GetSessionDetailsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateSessionRequest, $0.Session>(
        'UpdateSession',
        updateSession_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateSessionRequest.fromBuffer(value),
        ($0.Session value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteSessionRequest, $1.Empty>(
        'DeleteSession',
        deleteSession_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteSessionRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CancelSessionRequest, $1.Empty>(
        'CancelSession',
        cancelSession_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CancelSessionRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.MarkReportViewedRequest, $1.Empty>(
        'MarkReportViewed',
        markReportViewed_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.MarkReportViewedRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetAvatarConfigRequest, $1.Empty>(
        'SetAvatarConfig',
        setAvatarConfig_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SetAvatarConfigRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RateReportRequest, $0.RateReportResponse>(
        'RateReport',
        rateReport_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RateReportRequest.fromBuffer(value),
        ($0.RateReportResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetReportRatingRequest, $0.ReportRating>(
        'GetReportRating',
        getReportRating_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetReportRatingRequest.fromBuffer(value),
        ($0.ReportRating value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetActiveSuggestionRequest,
            $0.PreferenceSuggestion>(
        'GetActiveSuggestion',
        getActiveSuggestion_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetActiveSuggestionRequest.fromBuffer(value),
        ($0.PreferenceSuggestion value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LogPreferenceSuggestionRequest, $1.Empty>(
        'LogPreferenceSuggestion',
        logPreferenceSuggestion_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.LogPreferenceSuggestionRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.TrackEventsRequest, $0.TrackEventsResponse>(
            'TrackEvents',
            trackEvents_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.TrackEventsRequest.fromBuffer(value),
            ($0.TrackEventsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminListSessionsRequest,
            $0.AdminListSessionsResponse>(
        'AdminListSessions',
        adminListSessions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminListSessionsRequest.fromBuffer(value),
        ($0.AdminListSessionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetAdminAnalyticsRequest,
            $0.GetAdminAnalyticsResponse>(
        'GetAdminAnalytics',
        getAdminAnalytics_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetAdminAnalyticsRequest.fromBuffer(value),
        ($0.GetAdminAnalyticsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$1.Empty, $0.AdminListModalityPromptsResponse>(
            'AdminListModalityPrompts',
            adminListModalityPrompts_Pre,
            false,
            false,
            ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
            ($0.AdminListModalityPromptsResponse value) =>
                value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminGetModalityPromptHistoryRequest,
            $0.AdminGetModalityPromptHistoryResponse>(
        'AdminGetModalityPromptHistory',
        adminGetModalityPromptHistory_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminGetModalityPromptHistoryRequest.fromBuffer(value),
        ($0.AdminGetModalityPromptHistoryResponse value) =>
            value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminUpdateModalityPromptRequest,
            $0.AdminUpdateModalityPromptResponse>(
        'AdminUpdateModalityPrompt',
        adminUpdateModalityPrompt_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminUpdateModalityPromptRequest.fromBuffer(value),
        ($0.AdminUpdateModalityPromptResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetOrgTherapistMetricsRequest,
            $0.OrgTherapistMetricsResponse>(
        'GetOrgTherapistMetrics',
        getOrgTherapistMetrics_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetOrgTherapistMetricsRequest.fromBuffer(value),
        ($0.OrgTherapistMetricsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetOrgAnalyticsRequest,
            $0.GetOrgAnalyticsResponse>(
        'GetOrgAnalytics',
        getOrgAnalytics_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetOrgAnalyticsRequest.fromBuffer(value),
        ($0.GetOrgAnalyticsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.ClientOverview>(
        'ClientGetMyOverview',
        clientGetMyOverview_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.ClientOverview value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClientListSessionsRequest,
            $0.ClientListSessionsResponse>(
        'ClientListSessions',
        clientListSessions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClientListSessionsRequest.fromBuffer(value),
        ($0.ClientListSessionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClientGetTranscriptRequest,
            $0.ClientGetTranscriptResponse>(
        'ClientGetTranscript',
        clientGetTranscript_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClientGetTranscriptRequest.fromBuffer(value),
        ($0.ClientGetTranscriptResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClientListNotesRequest,
            $0.ClientListNotesResponse>(
        'ClientListNotes',
        clientListNotes_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClientListNotesRequest.fromBuffer(value),
        ($0.ClientListNotesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClientCreateNoteRequest, $0.ClientNote>(
        'ClientCreateNote',
        clientCreateNote_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClientCreateNoteRequest.fromBuffer(value),
        ($0.ClientNote value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClientSendNoteRequest, $0.ClientNote>(
        'ClientSendNote',
        clientSendNote_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClientSendNoteRequest.fromBuffer(value),
        ($0.ClientNote value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClientMarkNoteReadRequest, $1.Empty>(
        'ClientMarkNoteRead',
        clientMarkNoteRead_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClientMarkNoteReadRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClientDeleteNoteRequest, $1.Empty>(
        'ClientDeleteNote',
        clientDeleteNote_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClientDeleteNoteRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ClientHideItemRequest, $1.Empty>(
        'ClientHideItem',
        clientHideItem_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ClientHideItemRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ShareSessionWithClientRequest, $1.Empty>(
        'ShareSessionWithClient',
        shareSessionWithClient_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ShareSessionWithClientRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ShareNoteWithClientRequest, $1.Empty>(
        'ShareNoteWithClient',
        shareNoteWithClient_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ShareNoteWithClientRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ExportPatientDataRequest,
            $0.ExportPatientDataResponse>(
        'ExportPatientData',
        exportPatientData_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ExportPatientDataRequest.fromBuffer(value),
        ($0.ExportPatientDataResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeletePatientDataRequest, $1.Empty>(
        'DeletePatientData',
        deletePatientData_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeletePatientDataRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
  }

  $async.Future<$0.PatientFile> createPatientFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreatePatientFileRequest> $request) async {
    return createPatientFile($call, await $request);
  }

  $async.Future<$0.PatientFile> createPatientFile(
      $grpc.ServiceCall call, $0.CreatePatientFileRequest request);

  $async.Future<$0.PatientFile> getPatientFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetPatientFileRequest> $request) async {
    return getPatientFile($call, await $request);
  }

  $async.Future<$0.PatientFile> getPatientFile(
      $grpc.ServiceCall call, $0.GetPatientFileRequest request);

  $async.Future<$0.ListPatientFilesResponse> listPatientFiles_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListPatientFilesRequest> $request) async {
    return listPatientFiles($call, await $request);
  }

  $async.Future<$0.ListPatientFilesResponse> listPatientFiles(
      $grpc.ServiceCall call, $0.ListPatientFilesRequest request);

  $async.Future<$0.PatientFile> updatePatientFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdatePatientFileRequest> $request) async {
    return updatePatientFile($call, await $request);
  }

  $async.Future<$0.PatientFile> updatePatientFile(
      $grpc.ServiceCall call, $0.UpdatePatientFileRequest request);

  $async.Future<$1.Empty> deletePatientFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeletePatientFileRequest> $request) async {
    return deletePatientFile($call, await $request);
  }

  $async.Future<$1.Empty> deletePatientFile(
      $grpc.ServiceCall call, $0.DeletePatientFileRequest request);

  $async.Future<$0.PatientFile> updatePatientUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdatePatientUserRequest> $request) async {
    return updatePatientUser($call, await $request);
  }

  $async.Future<$0.PatientFile> updatePatientUser(
      $grpc.ServiceCall call, $0.UpdatePatientUserRequest request);

  $async.Future<$1.Empty> deletePatientUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeletePatientUserRequest> $request) async {
    return deletePatientUser($call, await $request);
  }

  $async.Future<$1.Empty> deletePatientUser(
      $grpc.ServiceCall call, $0.DeletePatientUserRequest request);

  $async.Future<$0.PatientNote> createPatientNote_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreatePatientNoteRequest> $request) async {
    return createPatientNote($call, await $request);
  }

  $async.Future<$0.PatientNote> createPatientNote(
      $grpc.ServiceCall call, $0.CreatePatientNoteRequest request);

  $async.Future<$0.ListPatientNotesResponse> listPatientNotes_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListPatientNotesRequest> $request) async {
    return listPatientNotes($call, await $request);
  }

  $async.Future<$0.ListPatientNotesResponse> listPatientNotes(
      $grpc.ServiceCall call, $0.ListPatientNotesRequest request);

  $async.Future<$0.PatientNote> updatePatientNote_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdatePatientNoteRequest> $request) async {
    return updatePatientNote($call, await $request);
  }

  $async.Future<$0.PatientNote> updatePatientNote(
      $grpc.ServiceCall call, $0.UpdatePatientNoteRequest request);

  $async.Future<$1.Empty> deletePatientNote_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeletePatientNoteRequest> $request) async {
    return deletePatientNote($call, await $request);
  }

  $async.Future<$1.Empty> deletePatientNote(
      $grpc.ServiceCall call, $0.DeletePatientNoteRequest request);

  $async.Future<$0.ActionPlanDraft> getActionPlanDraft_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetActionPlanDraftRequest> $request) async {
    return getActionPlanDraft($call, await $request);
  }

  $async.Future<$0.ActionPlanDraft> getActionPlanDraft(
      $grpc.ServiceCall call, $0.GetActionPlanDraftRequest request);

  $async.Future<$0.SavePatientNoteResponse> savePatientNote_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SavePatientNoteRequest> $request) async {
    return savePatientNote($call, await $request);
  }

  $async.Future<$0.SavePatientNoteResponse> savePatientNote(
      $grpc.ServiceCall call, $0.SavePatientNoteRequest request);

  $async.Future<$0.ListModalitiesResponse> listModalities_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return listModalities($call, await $request);
  }

  $async.Future<$0.ListModalitiesResponse> listModalities(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.HealthCheckResponse> healthCheck_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return healthCheck($call, await $request);
  }

  $async.Future<$0.HealthCheckResponse> healthCheck(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$2.Subscription> getMyBillingState_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getMyBillingState($call, await $request);
  }

  $async.Future<$2.Subscription> getMyBillingState(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.UpdateSpeakerLabelsResponse> updateSpeakerLabels_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateSpeakerLabelsRequest> $request) async {
    return updateSpeakerLabels($call, await $request);
  }

  $async.Future<$0.UpdateSpeakerLabelsResponse> updateSpeakerLabels(
      $grpc.ServiceCall call, $0.UpdateSpeakerLabelsRequest request);

  $async.Future<$0.ListSessionsResponse> listSessions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListSessionsRequest> $request) async {
    return listSessions($call, await $request);
  }

  $async.Future<$0.ListSessionsResponse> listSessions(
      $grpc.ServiceCall call, $0.ListSessionsRequest request);

  $async.Future<$0.GetSessionDetailsResponse> getSessionDetails_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetSessionDetailsRequest> $request) async {
    return getSessionDetails($call, await $request);
  }

  $async.Future<$0.GetSessionDetailsResponse> getSessionDetails(
      $grpc.ServiceCall call, $0.GetSessionDetailsRequest request);

  $async.Future<$0.Session> updateSession_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateSessionRequest> $request) async {
    return updateSession($call, await $request);
  }

  $async.Future<$0.Session> updateSession(
      $grpc.ServiceCall call, $0.UpdateSessionRequest request);

  $async.Future<$1.Empty> deleteSession_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteSessionRequest> $request) async {
    return deleteSession($call, await $request);
  }

  $async.Future<$1.Empty> deleteSession(
      $grpc.ServiceCall call, $0.DeleteSessionRequest request);

  $async.Future<$1.Empty> cancelSession_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CancelSessionRequest> $request) async {
    return cancelSession($call, await $request);
  }

  $async.Future<$1.Empty> cancelSession(
      $grpc.ServiceCall call, $0.CancelSessionRequest request);

  $async.Future<$1.Empty> markReportViewed_Pre($grpc.ServiceCall $call,
      $async.Future<$0.MarkReportViewedRequest> $request) async {
    return markReportViewed($call, await $request);
  }

  $async.Future<$1.Empty> markReportViewed(
      $grpc.ServiceCall call, $0.MarkReportViewedRequest request);

  $async.Future<$1.Empty> setAvatarConfig_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SetAvatarConfigRequest> $request) async {
    return setAvatarConfig($call, await $request);
  }

  $async.Future<$1.Empty> setAvatarConfig(
      $grpc.ServiceCall call, $0.SetAvatarConfigRequest request);

  $async.Future<$0.RateReportResponse> rateReport_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RateReportRequest> $request) async {
    return rateReport($call, await $request);
  }

  $async.Future<$0.RateReportResponse> rateReport(
      $grpc.ServiceCall call, $0.RateReportRequest request);

  $async.Future<$0.ReportRating> getReportRating_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetReportRatingRequest> $request) async {
    return getReportRating($call, await $request);
  }

  $async.Future<$0.ReportRating> getReportRating(
      $grpc.ServiceCall call, $0.GetReportRatingRequest request);

  $async.Future<$0.PreferenceSuggestion> getActiveSuggestion_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetActiveSuggestionRequest> $request) async {
    return getActiveSuggestion($call, await $request);
  }

  $async.Future<$0.PreferenceSuggestion> getActiveSuggestion(
      $grpc.ServiceCall call, $0.GetActiveSuggestionRequest request);

  $async.Future<$1.Empty> logPreferenceSuggestion_Pre($grpc.ServiceCall $call,
      $async.Future<$0.LogPreferenceSuggestionRequest> $request) async {
    return logPreferenceSuggestion($call, await $request);
  }

  $async.Future<$1.Empty> logPreferenceSuggestion(
      $grpc.ServiceCall call, $0.LogPreferenceSuggestionRequest request);

  $async.Future<$0.TrackEventsResponse> trackEvents_Pre($grpc.ServiceCall $call,
      $async.Future<$0.TrackEventsRequest> $request) async {
    return trackEvents($call, await $request);
  }

  $async.Future<$0.TrackEventsResponse> trackEvents(
      $grpc.ServiceCall call, $0.TrackEventsRequest request);

  $async.Future<$0.AdminListSessionsResponse> adminListSessions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminListSessionsRequest> $request) async {
    return adminListSessions($call, await $request);
  }

  $async.Future<$0.AdminListSessionsResponse> adminListSessions(
      $grpc.ServiceCall call, $0.AdminListSessionsRequest request);

  $async.Future<$0.GetAdminAnalyticsResponse> getAdminAnalytics_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetAdminAnalyticsRequest> $request) async {
    return getAdminAnalytics($call, await $request);
  }

  $async.Future<$0.GetAdminAnalyticsResponse> getAdminAnalytics(
      $grpc.ServiceCall call, $0.GetAdminAnalyticsRequest request);

  $async.Future<$0.AdminListModalityPromptsResponse>
      adminListModalityPrompts_Pre(
          $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return adminListModalityPrompts($call, await $request);
  }

  $async.Future<$0.AdminListModalityPromptsResponse> adminListModalityPrompts(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.AdminGetModalityPromptHistoryResponse>
      adminGetModalityPromptHistory_Pre(
          $grpc.ServiceCall $call,
          $async.Future<$0.AdminGetModalityPromptHistoryRequest>
              $request) async {
    return adminGetModalityPromptHistory($call, await $request);
  }

  $async.Future<$0.AdminGetModalityPromptHistoryResponse>
      adminGetModalityPromptHistory($grpc.ServiceCall call,
          $0.AdminGetModalityPromptHistoryRequest request);

  $async.Future<$0.AdminUpdateModalityPromptResponse>
      adminUpdateModalityPrompt_Pre($grpc.ServiceCall $call,
          $async.Future<$0.AdminUpdateModalityPromptRequest> $request) async {
    return adminUpdateModalityPrompt($call, await $request);
  }

  $async.Future<$0.AdminUpdateModalityPromptResponse> adminUpdateModalityPrompt(
      $grpc.ServiceCall call, $0.AdminUpdateModalityPromptRequest request);

  $async.Future<$0.OrgTherapistMetricsResponse> getOrgTherapistMetrics_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetOrgTherapistMetricsRequest> $request) async {
    return getOrgTherapistMetrics($call, await $request);
  }

  $async.Future<$0.OrgTherapistMetricsResponse> getOrgTherapistMetrics(
      $grpc.ServiceCall call, $0.GetOrgTherapistMetricsRequest request);

  $async.Future<$0.GetOrgAnalyticsResponse> getOrgAnalytics_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetOrgAnalyticsRequest> $request) async {
    return getOrgAnalytics($call, await $request);
  }

  $async.Future<$0.GetOrgAnalyticsResponse> getOrgAnalytics(
      $grpc.ServiceCall call, $0.GetOrgAnalyticsRequest request);

  $async.Future<$0.ClientOverview> clientGetMyOverview_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return clientGetMyOverview($call, await $request);
  }

  $async.Future<$0.ClientOverview> clientGetMyOverview(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.ClientListSessionsResponse> clientListSessions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ClientListSessionsRequest> $request) async {
    return clientListSessions($call, await $request);
  }

  $async.Future<$0.ClientListSessionsResponse> clientListSessions(
      $grpc.ServiceCall call, $0.ClientListSessionsRequest request);

  $async.Future<$0.ClientGetTranscriptResponse> clientGetTranscript_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ClientGetTranscriptRequest> $request) async {
    return clientGetTranscript($call, await $request);
  }

  $async.Future<$0.ClientGetTranscriptResponse> clientGetTranscript(
      $grpc.ServiceCall call, $0.ClientGetTranscriptRequest request);

  $async.Future<$0.ClientListNotesResponse> clientListNotes_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ClientListNotesRequest> $request) async {
    return clientListNotes($call, await $request);
  }

  $async.Future<$0.ClientListNotesResponse> clientListNotes(
      $grpc.ServiceCall call, $0.ClientListNotesRequest request);

  $async.Future<$0.ClientNote> clientCreateNote_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ClientCreateNoteRequest> $request) async {
    return clientCreateNote($call, await $request);
  }

  $async.Future<$0.ClientNote> clientCreateNote(
      $grpc.ServiceCall call, $0.ClientCreateNoteRequest request);

  $async.Future<$0.ClientNote> clientSendNote_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ClientSendNoteRequest> $request) async {
    return clientSendNote($call, await $request);
  }

  $async.Future<$0.ClientNote> clientSendNote(
      $grpc.ServiceCall call, $0.ClientSendNoteRequest request);

  $async.Future<$1.Empty> clientMarkNoteRead_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ClientMarkNoteReadRequest> $request) async {
    return clientMarkNoteRead($call, await $request);
  }

  $async.Future<$1.Empty> clientMarkNoteRead(
      $grpc.ServiceCall call, $0.ClientMarkNoteReadRequest request);

  $async.Future<$1.Empty> clientDeleteNote_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ClientDeleteNoteRequest> $request) async {
    return clientDeleteNote($call, await $request);
  }

  $async.Future<$1.Empty> clientDeleteNote(
      $grpc.ServiceCall call, $0.ClientDeleteNoteRequest request);

  $async.Future<$1.Empty> clientHideItem_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ClientHideItemRequest> $request) async {
    return clientHideItem($call, await $request);
  }

  $async.Future<$1.Empty> clientHideItem(
      $grpc.ServiceCall call, $0.ClientHideItemRequest request);

  $async.Future<$1.Empty> shareSessionWithClient_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ShareSessionWithClientRequest> $request) async {
    return shareSessionWithClient($call, await $request);
  }

  $async.Future<$1.Empty> shareSessionWithClient(
      $grpc.ServiceCall call, $0.ShareSessionWithClientRequest request);

  $async.Future<$1.Empty> shareNoteWithClient_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ShareNoteWithClientRequest> $request) async {
    return shareNoteWithClient($call, await $request);
  }

  $async.Future<$1.Empty> shareNoteWithClient(
      $grpc.ServiceCall call, $0.ShareNoteWithClientRequest request);

  $async.Future<$0.ExportPatientDataResponse> exportPatientData_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ExportPatientDataRequest> $request) async {
    return exportPatientData($call, await $request);
  }

  $async.Future<$0.ExportPatientDataResponse> exportPatientData(
      $grpc.ServiceCall call, $0.ExportPatientDataRequest request);

  $async.Future<$1.Empty> deletePatientData_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeletePatientDataRequest> $request) async {
    return deletePatientData($call, await $request);
  }

  $async.Future<$1.Empty> deletePatientData(
      $grpc.ServiceCall call, $0.DeletePatientDataRequest request);
}
