// This is a generated file - do not edit.
//
// Generated from identity/v1/identity.proto.

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

import 'identity.pb.dart' as $0;

export 'identity.pb.dart';

@$pb.GrpcServiceName('identity.v1.IdentityService')
class IdentityServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  IdentityServiceClient(super.channel, {super.options, super.interceptors});

  /// Validates Firebase JWT and returns user context
  $grpc.ResponseFuture<$0.UserContext> validateToken(
    $0.ValidateTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$validateToken, request, options: options);
  }

  /// Returns user profile by ID
  $grpc.ResponseFuture<$0.User> getUser(
    $0.GetUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUser, request, options: options);
  }

  /// Returns user profile by Firebase UID (after login)
  $grpc.ResponseFuture<$0.User> getUserByFirebaseUID(
    $0.GetUserByFirebaseUIDRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUserByFirebaseUID, request, options: options);
  }

  /// Creates user on first login (called from Firebase Auth trigger).
  /// For role=THERAPIST, identity-svc auto-provisions a personal
  /// organisation + Trial subscription (existing flow from commit 0a25ac7).
  $grpc.ResponseFuture<$0.User> createUser(
    $0.CreateUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createUser, request, options: options);
  }

  /// Updates own profile. Web sends the full payload (every editable
  /// column per docs/18 §13.4); iOS sends only the subset it knows.
  /// Handler MUST do selective UPDATE — skip fields whose presence
  /// wrapper is unset — so the iOS partial submit doesn't blank
  /// columns it never set. See docs/18 R4/D2.
  $grpc.ResponseFuture<$0.User> updateProfile(
    $0.UpdateProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateProfile, request, options: options);
  }

  /// Caller-scoped read of own profile. Returns the User row matching
  /// the authenticated firebase_uid. Web cold-start hydration uses
  /// this instead of passing user_id.
  $grpc.ResponseFuture<$0.User> getMyProfile(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMyProfile, request, options: options);
  }

  /// RBAC: check permission on resource
  $grpc.ResponseFuture<$0.PermissionDecision> checkPermission(
    $0.CheckPermissionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$checkPermission, request, options: options);
  }

  /// ─── Web app: org self-serve + invite flow (docs/18 R4, §9) ──
  ///
  /// RegisterOrganization is the public self-serve endpoint. Creates
  /// (in one PG tx) the organisation + headquarters Address + a
  /// single User with role=ORG_ADMIN + a Trial subscription. The
  /// founder is admin-only; to also record sessions they invite
  /// themselves under a second email (single-role MVP).
  $grpc.ResponseFuture<$0.RegisterOrganizationResponse> registerOrganization(
    $0.RegisterOrganizationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$registerOrganization, request, options: options);
  }

  /// ORG_ADMIN scope ─ all gated on caller's role; org_id resolved
  /// from the auth context, never trusted from the request.
  $grpc.ResponseFuture<$0.Organization> getMyOrganization(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMyOrganization, request, options: options);
  }

  $grpc.ResponseFuture<$0.Organization> updateMyOrganization(
    $0.UpdateMyOrganizationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateMyOrganization, request, options: options);
  }

  $grpc.ResponseFuture<$0.Invitation> inviteTherapist(
    $0.InviteTherapistRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$inviteTherapist, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListTherapistsResponse> listTherapistsInMyOrg(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listTherapistsInMyOrg, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> removeTherapist(
    $0.RemoveTherapistRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removeTherapist, request, options: options);
  }

  /// Invitee scope — public endpoint, validates the magic-link token.
  /// Called from the /accept-invite page after Firebase
  /// createUserWithEmailAndPassword succeeds. Creates the THERAPIST
  /// User row and attaches it to the inviting org.
  $grpc.ResponseFuture<$0.AcceptInvitationResponse> acceptInvitation(
    $0.AcceptInvitationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$acceptInvitation, request, options: options);
  }

  /// SUPERWIZOR_ADMIN scope ─ internal team. Every mutation writes
  /// audit_events with actor_type=SUPERWIZOR_ADMIN + required reason
  /// (>=10 chars enforced at handler level).
  $grpc.ResponseFuture<$0.AdminListOrganizationsResponse>
      adminListOrganizations(
    $0.AdminListOrganizationsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminListOrganizations, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.OrganizationDetails> adminGetOrganization(
    $0.AdminGetOrganizationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminGetOrganization, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> adminSetOrganizationStatus(
    $0.AdminSetOrganizationStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminSetOrganizationStatus, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.Organization> adminUpdateOrganization(
    $0.AdminUpdateOrganizationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminUpdateOrganization, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.AdminListUsersResponse> adminListUsers(
    $0.AdminListUsersRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminListUsers, request, options: options);
  }

  $grpc.ResponseFuture<$0.User> adminGetUser(
    $0.AdminGetUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminGetUser, request, options: options);
  }

  $grpc.ResponseFuture<$0.User> adminUpdateUser(
    $0.AdminUpdateUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminUpdateUser, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> adminDeleteUser(
    $0.AdminDeleteUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminDeleteUser, request, options: options);
  }

  /// Global cross-org audit history (docs/18 §8.2). Cursor-paginated;
  /// optional filters AND together. Used by the /admin/audit page.
  $grpc.ResponseFuture<$0.AdminListAuditEventsResponse> adminListAuditEvents(
    $0.AdminListAuditEventsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminListAuditEvents, request, options: options);
  }

  /// ─── Report customization (docs/10_REPORT_CUSTOMIZATION.md) ───
  /// Returns the therapist's report style preferences. The active
  /// suggestion banner (if any) is fetched separately from
  /// clinical-svc.GetActiveSuggestion — identity-svc has no
  /// dependency on clinical data tables (it's the bottom of the
  /// service dep tree).
  $grpc.ResponseFuture<$0.ReportPreferences> getReportPreferences(
    $0.GetReportPreferencesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getReportPreferences, request, options: options);
  }

  /// Updates the therapist's preferences. Idempotent: re-sending the
  /// same payload is a no-op past the first write.
  $grpc.ResponseFuture<$0.ReportPreferences> updateReportPreferences(
    $0.UpdateReportPreferencesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateReportPreferences, request,
        options: options);
  }

  /// ─── Cross-origin SSO (marketing-site → Flutter app) ────────
  ///
  /// Mints a short-lived Firebase custom token for the authenticated
  /// caller, scoped to the caller's own Firebase UID. The marketing
  /// site uses this to hand off an active session to the Flutter web
  /// app (different origin → separate Firebase Auth IndexedDB), so
  /// the user doesn't have to log in twice.
  ///
  /// Tokens expire 1h after issuance per Firebase Admin SDK defaults
  /// and are single-use in practice (the receiving origin redeems
  /// them via signInWithCustomToken, after which they're spent).
  /// The handler does not accept a uid in the request — it always
  /// mints for the caller. No org/role escalation surface.
  $grpc.ResponseFuture<$0.AppLoginToken> mintAppLoginToken(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$mintAppLoginToken, request, options: options);
  }

  /// Health check
  $grpc.ResponseFuture<$0.HealthCheckResponse> healthCheck(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$healthCheck, request, options: options);
  }

  /// ─── RODO/GDPR Consent Logging ───
  /// Records a user consent choice (TOS, MARKETING, RECORDING, etc.)
  /// for auditing compliance.
  $grpc.ResponseFuture<$0.RecordConsentResponse> recordConsent(
    $0.RecordConsentRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$recordConsent, request, options: options);
  }

  /// Checks if an email address is already registered in our system
  $grpc.ResponseFuture<$0.CheckEmailExistsResponse> checkEmailExists(
    $0.CheckEmailExistsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$checkEmailExists, request, options: options);
  }

  // method descriptors

  static final _$validateToken =
      $grpc.ClientMethod<$0.ValidateTokenRequest, $0.UserContext>(
          '/identity.v1.IdentityService/ValidateToken',
          ($0.ValidateTokenRequest value) => value.writeToBuffer(),
          $0.UserContext.fromBuffer);
  static final _$getUser = $grpc.ClientMethod<$0.GetUserRequest, $0.User>(
      '/identity.v1.IdentityService/GetUser',
      ($0.GetUserRequest value) => value.writeToBuffer(),
      $0.User.fromBuffer);
  static final _$getUserByFirebaseUID =
      $grpc.ClientMethod<$0.GetUserByFirebaseUIDRequest, $0.User>(
          '/identity.v1.IdentityService/GetUserByFirebaseUID',
          ($0.GetUserByFirebaseUIDRequest value) => value.writeToBuffer(),
          $0.User.fromBuffer);
  static final _$createUser = $grpc.ClientMethod<$0.CreateUserRequest, $0.User>(
      '/identity.v1.IdentityService/CreateUser',
      ($0.CreateUserRequest value) => value.writeToBuffer(),
      $0.User.fromBuffer);
  static final _$updateProfile =
      $grpc.ClientMethod<$0.UpdateProfileRequest, $0.User>(
          '/identity.v1.IdentityService/UpdateProfile',
          ($0.UpdateProfileRequest value) => value.writeToBuffer(),
          $0.User.fromBuffer);
  static final _$getMyProfile = $grpc.ClientMethod<$1.Empty, $0.User>(
      '/identity.v1.IdentityService/GetMyProfile',
      ($1.Empty value) => value.writeToBuffer(),
      $0.User.fromBuffer);
  static final _$checkPermission =
      $grpc.ClientMethod<$0.CheckPermissionRequest, $0.PermissionDecision>(
          '/identity.v1.IdentityService/CheckPermission',
          ($0.CheckPermissionRequest value) => value.writeToBuffer(),
          $0.PermissionDecision.fromBuffer);
  static final _$registerOrganization = $grpc.ClientMethod<
          $0.RegisterOrganizationRequest, $0.RegisterOrganizationResponse>(
      '/identity.v1.IdentityService/RegisterOrganization',
      ($0.RegisterOrganizationRequest value) => value.writeToBuffer(),
      $0.RegisterOrganizationResponse.fromBuffer);
  static final _$getMyOrganization =
      $grpc.ClientMethod<$1.Empty, $0.Organization>(
          '/identity.v1.IdentityService/GetMyOrganization',
          ($1.Empty value) => value.writeToBuffer(),
          $0.Organization.fromBuffer);
  static final _$updateMyOrganization =
      $grpc.ClientMethod<$0.UpdateMyOrganizationRequest, $0.Organization>(
          '/identity.v1.IdentityService/UpdateMyOrganization',
          ($0.UpdateMyOrganizationRequest value) => value.writeToBuffer(),
          $0.Organization.fromBuffer);
  static final _$inviteTherapist =
      $grpc.ClientMethod<$0.InviteTherapistRequest, $0.Invitation>(
          '/identity.v1.IdentityService/InviteTherapist',
          ($0.InviteTherapistRequest value) => value.writeToBuffer(),
          $0.Invitation.fromBuffer);
  static final _$listTherapistsInMyOrg =
      $grpc.ClientMethod<$1.Empty, $0.ListTherapistsResponse>(
          '/identity.v1.IdentityService/ListTherapistsInMyOrg',
          ($1.Empty value) => value.writeToBuffer(),
          $0.ListTherapistsResponse.fromBuffer);
  static final _$removeTherapist =
      $grpc.ClientMethod<$0.RemoveTherapistRequest, $1.Empty>(
          '/identity.v1.IdentityService/RemoveTherapist',
          ($0.RemoveTherapistRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$acceptInvitation = $grpc.ClientMethod<
          $0.AcceptInvitationRequest, $0.AcceptInvitationResponse>(
      '/identity.v1.IdentityService/AcceptInvitation',
      ($0.AcceptInvitationRequest value) => value.writeToBuffer(),
      $0.AcceptInvitationResponse.fromBuffer);
  static final _$adminListOrganizations = $grpc.ClientMethod<
          $0.AdminListOrganizationsRequest, $0.AdminListOrganizationsResponse>(
      '/identity.v1.IdentityService/AdminListOrganizations',
      ($0.AdminListOrganizationsRequest value) => value.writeToBuffer(),
      $0.AdminListOrganizationsResponse.fromBuffer);
  static final _$adminGetOrganization = $grpc.ClientMethod<
          $0.AdminGetOrganizationRequest, $0.OrganizationDetails>(
      '/identity.v1.IdentityService/AdminGetOrganization',
      ($0.AdminGetOrganizationRequest value) => value.writeToBuffer(),
      $0.OrganizationDetails.fromBuffer);
  static final _$adminSetOrganizationStatus =
      $grpc.ClientMethod<$0.AdminSetOrganizationStatusRequest, $1.Empty>(
          '/identity.v1.IdentityService/AdminSetOrganizationStatus',
          ($0.AdminSetOrganizationStatusRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$adminUpdateOrganization =
      $grpc.ClientMethod<$0.AdminUpdateOrganizationRequest, $0.Organization>(
          '/identity.v1.IdentityService/AdminUpdateOrganization',
          ($0.AdminUpdateOrganizationRequest value) => value.writeToBuffer(),
          $0.Organization.fromBuffer);
  static final _$adminListUsers =
      $grpc.ClientMethod<$0.AdminListUsersRequest, $0.AdminListUsersResponse>(
          '/identity.v1.IdentityService/AdminListUsers',
          ($0.AdminListUsersRequest value) => value.writeToBuffer(),
          $0.AdminListUsersResponse.fromBuffer);
  static final _$adminGetUser =
      $grpc.ClientMethod<$0.AdminGetUserRequest, $0.User>(
          '/identity.v1.IdentityService/AdminGetUser',
          ($0.AdminGetUserRequest value) => value.writeToBuffer(),
          $0.User.fromBuffer);
  static final _$adminUpdateUser =
      $grpc.ClientMethod<$0.AdminUpdateUserRequest, $0.User>(
          '/identity.v1.IdentityService/AdminUpdateUser',
          ($0.AdminUpdateUserRequest value) => value.writeToBuffer(),
          $0.User.fromBuffer);
  static final _$adminDeleteUser =
      $grpc.ClientMethod<$0.AdminDeleteUserRequest, $1.Empty>(
          '/identity.v1.IdentityService/AdminDeleteUser',
          ($0.AdminDeleteUserRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$adminListAuditEvents = $grpc.ClientMethod<
          $0.AdminListAuditEventsRequest, $0.AdminListAuditEventsResponse>(
      '/identity.v1.IdentityService/AdminListAuditEvents',
      ($0.AdminListAuditEventsRequest value) => value.writeToBuffer(),
      $0.AdminListAuditEventsResponse.fromBuffer);
  static final _$getReportPreferences =
      $grpc.ClientMethod<$0.GetReportPreferencesRequest, $0.ReportPreferences>(
          '/identity.v1.IdentityService/GetReportPreferences',
          ($0.GetReportPreferencesRequest value) => value.writeToBuffer(),
          $0.ReportPreferences.fromBuffer);
  static final _$updateReportPreferences = $grpc.ClientMethod<
          $0.UpdateReportPreferencesRequest, $0.ReportPreferences>(
      '/identity.v1.IdentityService/UpdateReportPreferences',
      ($0.UpdateReportPreferencesRequest value) => value.writeToBuffer(),
      $0.ReportPreferences.fromBuffer);
  static final _$mintAppLoginToken =
      $grpc.ClientMethod<$1.Empty, $0.AppLoginToken>(
          '/identity.v1.IdentityService/MintAppLoginToken',
          ($1.Empty value) => value.writeToBuffer(),
          $0.AppLoginToken.fromBuffer);
  static final _$healthCheck =
      $grpc.ClientMethod<$1.Empty, $0.HealthCheckResponse>(
          '/identity.v1.IdentityService/HealthCheck',
          ($1.Empty value) => value.writeToBuffer(),
          $0.HealthCheckResponse.fromBuffer);
  static final _$recordConsent =
      $grpc.ClientMethod<$0.RecordConsentRequest, $0.RecordConsentResponse>(
          '/identity.v1.IdentityService/RecordConsent',
          ($0.RecordConsentRequest value) => value.writeToBuffer(),
          $0.RecordConsentResponse.fromBuffer);
  static final _$checkEmailExists = $grpc.ClientMethod<
          $0.CheckEmailExistsRequest, $0.CheckEmailExistsResponse>(
      '/identity.v1.IdentityService/CheckEmailExists',
      ($0.CheckEmailExistsRequest value) => value.writeToBuffer(),
      $0.CheckEmailExistsResponse.fromBuffer);
}

@$pb.GrpcServiceName('identity.v1.IdentityService')
abstract class IdentityServiceBase extends $grpc.Service {
  $core.String get $name => 'identity.v1.IdentityService';

  IdentityServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ValidateTokenRequest, $0.UserContext>(
        'ValidateToken',
        validateToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ValidateTokenRequest.fromBuffer(value),
        ($0.UserContext value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetUserRequest, $0.User>(
        'GetUser',
        getUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetUserRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetUserByFirebaseUIDRequest, $0.User>(
        'GetUserByFirebaseUID',
        getUserByFirebaseUID_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetUserByFirebaseUIDRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateUserRequest, $0.User>(
        'CreateUser',
        createUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateUserRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateProfileRequest, $0.User>(
        'UpdateProfile',
        updateProfile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateProfileRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.User>(
        'GetMyProfile',
        getMyProfile_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.CheckPermissionRequest, $0.PermissionDecision>(
            'CheckPermission',
            checkPermission_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CheckPermissionRequest.fromBuffer(value),
            ($0.PermissionDecision value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RegisterOrganizationRequest,
            $0.RegisterOrganizationResponse>(
        'RegisterOrganization',
        registerOrganization_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RegisterOrganizationRequest.fromBuffer(value),
        ($0.RegisterOrganizationResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.Organization>(
        'GetMyOrganization',
        getMyOrganization_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.Organization value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdateMyOrganizationRequest, $0.Organization>(
            'UpdateMyOrganization',
            updateMyOrganization_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdateMyOrganizationRequest.fromBuffer(value),
            ($0.Organization value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.InviteTherapistRequest, $0.Invitation>(
        'InviteTherapist',
        inviteTherapist_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.InviteTherapistRequest.fromBuffer(value),
        ($0.Invitation value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.ListTherapistsResponse>(
        'ListTherapistsInMyOrg',
        listTherapistsInMyOrg_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.ListTherapistsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RemoveTherapistRequest, $1.Empty>(
        'RemoveTherapist',
        removeTherapist_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RemoveTherapistRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AcceptInvitationRequest,
            $0.AcceptInvitationResponse>(
        'AcceptInvitation',
        acceptInvitation_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AcceptInvitationRequest.fromBuffer(value),
        ($0.AcceptInvitationResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminListOrganizationsRequest,
            $0.AdminListOrganizationsResponse>(
        'AdminListOrganizations',
        adminListOrganizations_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminListOrganizationsRequest.fromBuffer(value),
        ($0.AdminListOrganizationsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminGetOrganizationRequest,
            $0.OrganizationDetails>(
        'AdminGetOrganization',
        adminGetOrganization_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminGetOrganizationRequest.fromBuffer(value),
        ($0.OrganizationDetails value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.AdminSetOrganizationStatusRequest, $1.Empty>(
            'AdminSetOrganizationStatus',
            adminSetOrganizationStatus_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.AdminSetOrganizationStatusRequest.fromBuffer(value),
            ($1.Empty value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.AdminUpdateOrganizationRequest, $0.Organization>(
            'AdminUpdateOrganization',
            adminUpdateOrganization_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.AdminUpdateOrganizationRequest.fromBuffer(value),
            ($0.Organization value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminListUsersRequest,
            $0.AdminListUsersResponse>(
        'AdminListUsers',
        adminListUsers_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminListUsersRequest.fromBuffer(value),
        ($0.AdminListUsersResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminGetUserRequest, $0.User>(
        'AdminGetUser',
        adminGetUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminGetUserRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminUpdateUserRequest, $0.User>(
        'AdminUpdateUser',
        adminUpdateUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminUpdateUserRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminDeleteUserRequest, $1.Empty>(
        'AdminDeleteUser',
        adminDeleteUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminDeleteUserRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminListAuditEventsRequest,
            $0.AdminListAuditEventsResponse>(
        'AdminListAuditEvents',
        adminListAuditEvents_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminListAuditEventsRequest.fromBuffer(value),
        ($0.AdminListAuditEventsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetReportPreferencesRequest,
            $0.ReportPreferences>(
        'GetReportPreferences',
        getReportPreferences_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetReportPreferencesRequest.fromBuffer(value),
        ($0.ReportPreferences value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateReportPreferencesRequest,
            $0.ReportPreferences>(
        'UpdateReportPreferences',
        updateReportPreferences_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateReportPreferencesRequest.fromBuffer(value),
        ($0.ReportPreferences value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.AppLoginToken>(
        'MintAppLoginToken',
        mintAppLoginToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.AppLoginToken value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.HealthCheckResponse>(
        'HealthCheck',
        healthCheck_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.HealthCheckResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RecordConsentRequest, $0.RecordConsentResponse>(
            'RecordConsent',
            recordConsent_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RecordConsentRequest.fromBuffer(value),
            ($0.RecordConsentResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CheckEmailExistsRequest,
            $0.CheckEmailExistsResponse>(
        'CheckEmailExists',
        checkEmailExists_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CheckEmailExistsRequest.fromBuffer(value),
        ($0.CheckEmailExistsResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.UserContext> validateToken_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ValidateTokenRequest> $request) async {
    return validateToken($call, await $request);
  }

  $async.Future<$0.UserContext> validateToken(
      $grpc.ServiceCall call, $0.ValidateTokenRequest request);

  $async.Future<$0.User> getUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetUserRequest> $request) async {
    return getUser($call, await $request);
  }

  $async.Future<$0.User> getUser(
      $grpc.ServiceCall call, $0.GetUserRequest request);

  $async.Future<$0.User> getUserByFirebaseUID_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetUserByFirebaseUIDRequest> $request) async {
    return getUserByFirebaseUID($call, await $request);
  }

  $async.Future<$0.User> getUserByFirebaseUID(
      $grpc.ServiceCall call, $0.GetUserByFirebaseUIDRequest request);

  $async.Future<$0.User> createUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateUserRequest> $request) async {
    return createUser($call, await $request);
  }

  $async.Future<$0.User> createUser(
      $grpc.ServiceCall call, $0.CreateUserRequest request);

  $async.Future<$0.User> updateProfile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateProfileRequest> $request) async {
    return updateProfile($call, await $request);
  }

  $async.Future<$0.User> updateProfile(
      $grpc.ServiceCall call, $0.UpdateProfileRequest request);

  $async.Future<$0.User> getMyProfile_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getMyProfile($call, await $request);
  }

  $async.Future<$0.User> getMyProfile($grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.PermissionDecision> checkPermission_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CheckPermissionRequest> $request) async {
    return checkPermission($call, await $request);
  }

  $async.Future<$0.PermissionDecision> checkPermission(
      $grpc.ServiceCall call, $0.CheckPermissionRequest request);

  $async.Future<$0.RegisterOrganizationResponse> registerOrganization_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RegisterOrganizationRequest> $request) async {
    return registerOrganization($call, await $request);
  }

  $async.Future<$0.RegisterOrganizationResponse> registerOrganization(
      $grpc.ServiceCall call, $0.RegisterOrganizationRequest request);

  $async.Future<$0.Organization> getMyOrganization_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getMyOrganization($call, await $request);
  }

  $async.Future<$0.Organization> getMyOrganization(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Organization> updateMyOrganization_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateMyOrganizationRequest> $request) async {
    return updateMyOrganization($call, await $request);
  }

  $async.Future<$0.Organization> updateMyOrganization(
      $grpc.ServiceCall call, $0.UpdateMyOrganizationRequest request);

  $async.Future<$0.Invitation> inviteTherapist_Pre($grpc.ServiceCall $call,
      $async.Future<$0.InviteTherapistRequest> $request) async {
    return inviteTherapist($call, await $request);
  }

  $async.Future<$0.Invitation> inviteTherapist(
      $grpc.ServiceCall call, $0.InviteTherapistRequest request);

  $async.Future<$0.ListTherapistsResponse> listTherapistsInMyOrg_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return listTherapistsInMyOrg($call, await $request);
  }

  $async.Future<$0.ListTherapistsResponse> listTherapistsInMyOrg(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$1.Empty> removeTherapist_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RemoveTherapistRequest> $request) async {
    return removeTherapist($call, await $request);
  }

  $async.Future<$1.Empty> removeTherapist(
      $grpc.ServiceCall call, $0.RemoveTherapistRequest request);

  $async.Future<$0.AcceptInvitationResponse> acceptInvitation_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AcceptInvitationRequest> $request) async {
    return acceptInvitation($call, await $request);
  }

  $async.Future<$0.AcceptInvitationResponse> acceptInvitation(
      $grpc.ServiceCall call, $0.AcceptInvitationRequest request);

  $async.Future<$0.AdminListOrganizationsResponse> adminListOrganizations_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminListOrganizationsRequest> $request) async {
    return adminListOrganizations($call, await $request);
  }

  $async.Future<$0.AdminListOrganizationsResponse> adminListOrganizations(
      $grpc.ServiceCall call, $0.AdminListOrganizationsRequest request);

  $async.Future<$0.OrganizationDetails> adminGetOrganization_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminGetOrganizationRequest> $request) async {
    return adminGetOrganization($call, await $request);
  }

  $async.Future<$0.OrganizationDetails> adminGetOrganization(
      $grpc.ServiceCall call, $0.AdminGetOrganizationRequest request);

  $async.Future<$1.Empty> adminSetOrganizationStatus_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminSetOrganizationStatusRequest> $request) async {
    return adminSetOrganizationStatus($call, await $request);
  }

  $async.Future<$1.Empty> adminSetOrganizationStatus(
      $grpc.ServiceCall call, $0.AdminSetOrganizationStatusRequest request);

  $async.Future<$0.Organization> adminUpdateOrganization_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminUpdateOrganizationRequest> $request) async {
    return adminUpdateOrganization($call, await $request);
  }

  $async.Future<$0.Organization> adminUpdateOrganization(
      $grpc.ServiceCall call, $0.AdminUpdateOrganizationRequest request);

  $async.Future<$0.AdminListUsersResponse> adminListUsers_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminListUsersRequest> $request) async {
    return adminListUsers($call, await $request);
  }

  $async.Future<$0.AdminListUsersResponse> adminListUsers(
      $grpc.ServiceCall call, $0.AdminListUsersRequest request);

  $async.Future<$0.User> adminGetUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AdminGetUserRequest> $request) async {
    return adminGetUser($call, await $request);
  }

  $async.Future<$0.User> adminGetUser(
      $grpc.ServiceCall call, $0.AdminGetUserRequest request);

  $async.Future<$0.User> adminUpdateUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AdminUpdateUserRequest> $request) async {
    return adminUpdateUser($call, await $request);
  }

  $async.Future<$0.User> adminUpdateUser(
      $grpc.ServiceCall call, $0.AdminUpdateUserRequest request);

  $async.Future<$1.Empty> adminDeleteUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AdminDeleteUserRequest> $request) async {
    return adminDeleteUser($call, await $request);
  }

  $async.Future<$1.Empty> adminDeleteUser(
      $grpc.ServiceCall call, $0.AdminDeleteUserRequest request);

  $async.Future<$0.AdminListAuditEventsResponse> adminListAuditEvents_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminListAuditEventsRequest> $request) async {
    return adminListAuditEvents($call, await $request);
  }

  $async.Future<$0.AdminListAuditEventsResponse> adminListAuditEvents(
      $grpc.ServiceCall call, $0.AdminListAuditEventsRequest request);

  $async.Future<$0.ReportPreferences> getReportPreferences_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetReportPreferencesRequest> $request) async {
    return getReportPreferences($call, await $request);
  }

  $async.Future<$0.ReportPreferences> getReportPreferences(
      $grpc.ServiceCall call, $0.GetReportPreferencesRequest request);

  $async.Future<$0.ReportPreferences> updateReportPreferences_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateReportPreferencesRequest> $request) async {
    return updateReportPreferences($call, await $request);
  }

  $async.Future<$0.ReportPreferences> updateReportPreferences(
      $grpc.ServiceCall call, $0.UpdateReportPreferencesRequest request);

  $async.Future<$0.AppLoginToken> mintAppLoginToken_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return mintAppLoginToken($call, await $request);
  }

  $async.Future<$0.AppLoginToken> mintAppLoginToken(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.HealthCheckResponse> healthCheck_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return healthCheck($call, await $request);
  }

  $async.Future<$0.HealthCheckResponse> healthCheck(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.RecordConsentResponse> recordConsent_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RecordConsentRequest> $request) async {
    return recordConsent($call, await $request);
  }

  $async.Future<$0.RecordConsentResponse> recordConsent(
      $grpc.ServiceCall call, $0.RecordConsentRequest request);

  $async.Future<$0.CheckEmailExistsResponse> checkEmailExists_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CheckEmailExistsRequest> $request) async {
    return checkEmailExists($call, await $request);
  }

  $async.Future<$0.CheckEmailExistsResponse> checkEmailExists(
      $grpc.ServiceCall call, $0.CheckEmailExistsRequest request);
}
