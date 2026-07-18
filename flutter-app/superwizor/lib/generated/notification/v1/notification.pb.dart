// This is a generated file - do not edit.
//
// Generated from notification/v1/notification.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'notification.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'notification.pbenum.dart';

class SendClientPanelEventRequest extends $pb.GeneratedMessage {
  factory SendClientPanelEventRequest({
    $core.String? recipientEmail,
    $core.String? event,
    $core.String? itemKind,
    $core.String? locale,
    $core.String? panelUrl,
    $core.String? recipientUserId,
    $core.String? patientFileId,
  }) {
    final result = create();
    if (recipientEmail != null) result.recipientEmail = recipientEmail;
    if (event != null) result.event = event;
    if (itemKind != null) result.itemKind = itemKind;
    if (locale != null) result.locale = locale;
    if (panelUrl != null) result.panelUrl = panelUrl;
    if (recipientUserId != null) result.recipientUserId = recipientUserId;
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  SendClientPanelEventRequest._();

  factory SendClientPanelEventRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendClientPanelEventRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendClientPanelEventRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'recipientEmail')
    ..aOS(2, _omitFieldNames ? '' : 'event')
    ..aOS(3, _omitFieldNames ? '' : 'itemKind')
    ..aOS(4, _omitFieldNames ? '' : 'locale')
    ..aOS(5, _omitFieldNames ? '' : 'panelUrl')
    ..aOS(6, _omitFieldNames ? '' : 'recipientUserId')
    ..aOS(7, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendClientPanelEventRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendClientPanelEventRequest copyWith(
          void Function(SendClientPanelEventRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SendClientPanelEventRequest))
          as SendClientPanelEventRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendClientPanelEventRequest create() =>
      SendClientPanelEventRequest._();
  @$core.override
  SendClientPanelEventRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendClientPanelEventRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendClientPanelEventRequest>(create);
  static SendClientPanelEventRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get recipientEmail => $_getSZ(0);
  @$pb.TagNumber(1)
  set recipientEmail($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRecipientEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearRecipientEmail() => $_clearField(1);

  /// ITEM_SHARED           → to the client ("new item in your panel")
  /// CLIENT_NOTE_RECEIVED  → to the therapist ("a client wrote a note")
  @$pb.TagNumber(2)
  $core.String get event => $_getSZ(1);
  @$pb.TagNumber(2)
  set event($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEvent() => $_has(1);
  @$pb.TagNumber(2)
  void clearEvent() => $_clearField(2);

  /// For ITEM_SHARED: SESSION | NOTE. Ignored otherwise.
  @$pb.TagNumber(3)
  $core.String get itemKind => $_getSZ(2);
  @$pb.TagNumber(3)
  set itemKind($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasItemKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearItemKind() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get locale => $_getSZ(3);
  @$pb.TagNumber(4)
  set locale($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLocale() => $_has(3);
  @$pb.TagNumber(4)
  void clearLocale() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get panelUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set panelUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPanelUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearPanelUrl() => $_clearField(5);

  /// CLIENT_NOTE_RECEIVED only: the therapist's users.id and the
  /// kartoteka id. Present → notification-svc ALSO fires a PHI-free FCM
  /// data push (notification_type=client_note_received, patient_file_id
  /// in data) so the therapist app refreshes the notes list live. Empty
  /// → e-mail only (backward compatible).
  @$pb.TagNumber(6)
  $core.String get recipientUserId => $_getSZ(5);
  @$pb.TagNumber(6)
  set recipientUserId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRecipientUserId() => $_has(5);
  @$pb.TagNumber(6)
  void clearRecipientUserId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get patientFileId => $_getSZ(6);
  @$pb.TagNumber(7)
  set patientFileId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPatientFileId() => $_has(6);
  @$pb.TagNumber(7)
  void clearPatientFileId() => $_clearField(7);
}

class SendContactEmailRequest extends $pb.GeneratedMessage {
  factory SendContactEmailRequest({
    $core.String? name,
    $core.String? email,
    $core.String? subject,
    $core.String? message,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (email != null) result.email = email;
    if (subject != null) result.subject = subject;
    if (message != null) result.message = message;
    return result;
  }

  SendContactEmailRequest._();

  factory SendContactEmailRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendContactEmailRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendContactEmailRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOS(3, _omitFieldNames ? '' : 'subject')
    ..aOS(4, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendContactEmailRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendContactEmailRequest copyWith(
          void Function(SendContactEmailRequest) updates) =>
      super.copyWith((message) => updates(message as SendContactEmailRequest))
          as SendContactEmailRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendContactEmailRequest create() => SendContactEmailRequest._();
  @$core.override
  SendContactEmailRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendContactEmailRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendContactEmailRequest>(create);
  static SendContactEmailRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get subject => $_getSZ(2);
  @$pb.TagNumber(3)
  set subject($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get message => $_getSZ(3);
  @$pb.TagNumber(4)
  set message($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearMessage() => $_clearField(4);
}

class SendActionPlanEmailRequest extends $pb.GeneratedMessage {
  factory SendActionPlanEmailRequest({
    $core.String? toEmail,
    $core.String? therapistDisplayName,
    $core.String? actionPlanText,
    $core.String? sessionDate,
    $core.String? locale,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (toEmail != null) result.toEmail = toEmail;
    if (therapistDisplayName != null)
      result.therapistDisplayName = therapistDisplayName;
    if (actionPlanText != null) result.actionPlanText = actionPlanText;
    if (sessionDate != null) result.sessionDate = sessionDate;
    if (locale != null) result.locale = locale;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  SendActionPlanEmailRequest._();

  factory SendActionPlanEmailRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendActionPlanEmailRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendActionPlanEmailRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'toEmail')
    ..aOS(2, _omitFieldNames ? '' : 'therapistDisplayName')
    ..aOS(3, _omitFieldNames ? '' : 'actionPlanText')
    ..aOS(4, _omitFieldNames ? '' : 'sessionDate')
    ..aOS(5, _omitFieldNames ? '' : 'locale')
    ..aOS(6, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendActionPlanEmailRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendActionPlanEmailRequest copyWith(
          void Function(SendActionPlanEmailRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SendActionPlanEmailRequest))
          as SendActionPlanEmailRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendActionPlanEmailRequest create() => SendActionPlanEmailRequest._();
  @$core.override
  SendActionPlanEmailRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendActionPlanEmailRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendActionPlanEmailRequest>(create);
  static SendActionPlanEmailRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get toEmail => $_getSZ(0);
  @$pb.TagNumber(1)
  set toEmail($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearToEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get therapistDisplayName => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistDisplayName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistDisplayName() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistDisplayName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get actionPlanText => $_getSZ(2);
  @$pb.TagNumber(3)
  set actionPlanText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActionPlanText() => $_has(2);
  @$pb.TagNumber(3)
  void clearActionPlanText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sessionDate => $_getSZ(3);
  @$pb.TagNumber(4)
  set sessionDate($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionDate() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionDate() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get locale => $_getSZ(4);
  @$pb.TagNumber(5)
  set locale($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLocale() => $_has(4);
  @$pb.TagNumber(5)
  void clearLocale() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get idempotencyKey => $_getSZ(5);
  @$pb.TagNumber(6)
  set idempotencyKey($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIdempotencyKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearIdempotencyKey() => $_clearField(6);
}

class SendActionPlanEmailResponse extends $pb.GeneratedMessage {
  factory SendActionPlanEmailResponse({
    $core.String? deliveryId,
  }) {
    final result = create();
    if (deliveryId != null) result.deliveryId = deliveryId;
    return result;
  }

  SendActionPlanEmailResponse._();

  factory SendActionPlanEmailResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendActionPlanEmailResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendActionPlanEmailResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deliveryId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendActionPlanEmailResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendActionPlanEmailResponse copyWith(
          void Function(SendActionPlanEmailResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SendActionPlanEmailResponse))
          as SendActionPlanEmailResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendActionPlanEmailResponse create() =>
      SendActionPlanEmailResponse._();
  @$core.override
  SendActionPlanEmailResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendActionPlanEmailResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendActionPlanEmailResponse>(create);
  static SendActionPlanEmailResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deliveryId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deliveryId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeliveryId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeliveryId() => $_clearField(1);
}

class SendInvitationEmailRequest extends $pb.GeneratedMessage {
  factory SendInvitationEmailRequest({
    $core.String? recipientEmail,
    $core.String? organizationName,
    $core.String? inviterFirstName,
    $core.String? acceptUrl,
    $core.String? expiresAtIso,
    $core.String? locale,
    $core.String? invitedRole,
  }) {
    final result = create();
    if (recipientEmail != null) result.recipientEmail = recipientEmail;
    if (organizationName != null) result.organizationName = organizationName;
    if (inviterFirstName != null) result.inviterFirstName = inviterFirstName;
    if (acceptUrl != null) result.acceptUrl = acceptUrl;
    if (expiresAtIso != null) result.expiresAtIso = expiresAtIso;
    if (locale != null) result.locale = locale;
    if (invitedRole != null) result.invitedRole = invitedRole;
    return result;
  }

  SendInvitationEmailRequest._();

  factory SendInvitationEmailRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendInvitationEmailRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendInvitationEmailRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'recipientEmail')
    ..aOS(2, _omitFieldNames ? '' : 'organizationName')
    ..aOS(3, _omitFieldNames ? '' : 'inviterFirstName')
    ..aOS(4, _omitFieldNames ? '' : 'acceptUrl')
    ..aOS(5, _omitFieldNames ? '' : 'expiresAtIso')
    ..aOS(6, _omitFieldNames ? '' : 'locale')
    ..aOS(7, _omitFieldNames ? '' : 'invitedRole')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendInvitationEmailRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendInvitationEmailRequest copyWith(
          void Function(SendInvitationEmailRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SendInvitationEmailRequest))
          as SendInvitationEmailRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendInvitationEmailRequest create() => SendInvitationEmailRequest._();
  @$core.override
  SendInvitationEmailRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendInvitationEmailRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendInvitationEmailRequest>(create);
  static SendInvitationEmailRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get recipientEmail => $_getSZ(0);
  @$pb.TagNumber(1)
  set recipientEmail($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRecipientEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearRecipientEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get organizationName => $_getSZ(1);
  @$pb.TagNumber(2)
  set organizationName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOrganizationName() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrganizationName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get inviterFirstName => $_getSZ(2);
  @$pb.TagNumber(3)
  set inviterFirstName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInviterFirstName() => $_has(2);
  @$pb.TagNumber(3)
  void clearInviterFirstName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get acceptUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set acceptUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAcceptUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearAcceptUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get expiresAtIso => $_getSZ(4);
  @$pb.TagNumber(5)
  set expiresAtIso($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExpiresAtIso() => $_has(4);
  @$pb.TagNumber(5)
  void clearExpiresAtIso() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get locale => $_getSZ(5);
  @$pb.TagNumber(6)
  set locale($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLocale() => $_has(5);
  @$pb.TagNumber(6)
  void clearLocale() => $_clearField(6);

  /// Template selector (docs/38): "ORG_ADMIN" → org_manager_invite
  /// (manager onboarding, sent by AdminCreateOrganization); anything
  /// else (incl. empty for old callers) → the therapist invitation.
  @$pb.TagNumber(7)
  $core.String get invitedRole => $_getSZ(6);
  @$pb.TagNumber(7)
  set invitedRole($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasInvitedRole() => $_has(6);
  @$pb.TagNumber(7)
  void clearInvitedRole() => $_clearField(7);
}

class SendEmailVerificationRequest extends $pb.GeneratedMessage {
  factory SendEmailVerificationRequest({
    $core.String? recipientEmail,
    $core.String? firstName,
    $core.String? verifyUrl,
    $core.String? expiresAtIso,
    $core.String? locale,
  }) {
    final result = create();
    if (recipientEmail != null) result.recipientEmail = recipientEmail;
    if (firstName != null) result.firstName = firstName;
    if (verifyUrl != null) result.verifyUrl = verifyUrl;
    if (expiresAtIso != null) result.expiresAtIso = expiresAtIso;
    if (locale != null) result.locale = locale;
    return result;
  }

  SendEmailVerificationRequest._();

  factory SendEmailVerificationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendEmailVerificationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendEmailVerificationRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'recipientEmail')
    ..aOS(2, _omitFieldNames ? '' : 'firstName')
    ..aOS(3, _omitFieldNames ? '' : 'verifyUrl')
    ..aOS(4, _omitFieldNames ? '' : 'expiresAtIso')
    ..aOS(5, _omitFieldNames ? '' : 'locale')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendEmailVerificationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendEmailVerificationRequest copyWith(
          void Function(SendEmailVerificationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SendEmailVerificationRequest))
          as SendEmailVerificationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendEmailVerificationRequest create() =>
      SendEmailVerificationRequest._();
  @$core.override
  SendEmailVerificationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendEmailVerificationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendEmailVerificationRequest>(create);
  static SendEmailVerificationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get recipientEmail => $_getSZ(0);
  @$pb.TagNumber(1)
  set recipientEmail($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRecipientEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearRecipientEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get firstName => $_getSZ(1);
  @$pb.TagNumber(2)
  set firstName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirstName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirstName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get verifyUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set verifyUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVerifyUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearVerifyUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get expiresAtIso => $_getSZ(3);
  @$pb.TagNumber(4)
  set expiresAtIso($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExpiresAtIso() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiresAtIso() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get locale => $_getSZ(4);
  @$pb.TagNumber(5)
  set locale($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLocale() => $_has(4);
  @$pb.TagNumber(5)
  void clearLocale() => $_clearField(5);
}

class SendQuotaWarningRequest extends $pb.GeneratedMessage {
  factory SendQuotaWarningRequest({
    $core.String? recipientEmail,
    $core.String? firstName,
    $core.String? organizationName,
    $core.int? usagePercent,
    $core.int? tokensRemaining,
    $core.String? planTier,
    $core.String? planCycle,
    $core.String? periodEndIso,
    $core.String? billingUrl,
    $core.String? locale,
  }) {
    final result = create();
    if (recipientEmail != null) result.recipientEmail = recipientEmail;
    if (firstName != null) result.firstName = firstName;
    if (organizationName != null) result.organizationName = organizationName;
    if (usagePercent != null) result.usagePercent = usagePercent;
    if (tokensRemaining != null) result.tokensRemaining = tokensRemaining;
    if (planTier != null) result.planTier = planTier;
    if (planCycle != null) result.planCycle = planCycle;
    if (periodEndIso != null) result.periodEndIso = periodEndIso;
    if (billingUrl != null) result.billingUrl = billingUrl;
    if (locale != null) result.locale = locale;
    return result;
  }

  SendQuotaWarningRequest._();

  factory SendQuotaWarningRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendQuotaWarningRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendQuotaWarningRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'recipientEmail')
    ..aOS(2, _omitFieldNames ? '' : 'firstName')
    ..aOS(3, _omitFieldNames ? '' : 'organizationName')
    ..aI(4, _omitFieldNames ? '' : 'usagePercent')
    ..aI(5, _omitFieldNames ? '' : 'tokensRemaining')
    ..aOS(6, _omitFieldNames ? '' : 'planTier')
    ..aOS(7, _omitFieldNames ? '' : 'planCycle')
    ..aOS(8, _omitFieldNames ? '' : 'periodEndIso')
    ..aOS(9, _omitFieldNames ? '' : 'billingUrl')
    ..aOS(10, _omitFieldNames ? '' : 'locale')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendQuotaWarningRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendQuotaWarningRequest copyWith(
          void Function(SendQuotaWarningRequest) updates) =>
      super.copyWith((message) => updates(message as SendQuotaWarningRequest))
          as SendQuotaWarningRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendQuotaWarningRequest create() => SendQuotaWarningRequest._();
  @$core.override
  SendQuotaWarningRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendQuotaWarningRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendQuotaWarningRequest>(create);
  static SendQuotaWarningRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get recipientEmail => $_getSZ(0);
  @$pb.TagNumber(1)
  set recipientEmail($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRecipientEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearRecipientEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get firstName => $_getSZ(1);
  @$pb.TagNumber(2)
  set firstName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirstName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirstName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get organizationName => $_getSZ(2);
  @$pb.TagNumber(3)
  set organizationName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOrganizationName() => $_has(2);
  @$pb.TagNumber(3)
  void clearOrganizationName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get usagePercent => $_getIZ(3);
  @$pb.TagNumber(4)
  set usagePercent($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUsagePercent() => $_has(3);
  @$pb.TagNumber(4)
  void clearUsagePercent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get tokensRemaining => $_getIZ(4);
  @$pb.TagNumber(5)
  set tokensRemaining($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTokensRemaining() => $_has(4);
  @$pb.TagNumber(5)
  void clearTokensRemaining() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get planTier => $_getSZ(5);
  @$pb.TagNumber(6)
  set planTier($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPlanTier() => $_has(5);
  @$pb.TagNumber(6)
  void clearPlanTier() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get planCycle => $_getSZ(6);
  @$pb.TagNumber(7)
  set planCycle($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPlanCycle() => $_has(6);
  @$pb.TagNumber(7)
  void clearPlanCycle() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get periodEndIso => $_getSZ(7);
  @$pb.TagNumber(8)
  set periodEndIso($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPeriodEndIso() => $_has(7);
  @$pb.TagNumber(8)
  void clearPeriodEndIso() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get billingUrl => $_getSZ(8);
  @$pb.TagNumber(9)
  set billingUrl($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasBillingUrl() => $_has(8);
  @$pb.TagNumber(9)
  void clearBillingUrl() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get locale => $_getSZ(9);
  @$pb.TagNumber(10)
  set locale($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLocale() => $_has(9);
  @$pb.TagNumber(10)
  void clearLocale() => $_clearField(10);
}

/// RegisterFCMToken upserts an FCM token for the authenticated user.
///
/// user_id is resolved from the Firebase ID token in gRPC metadata server-side;
/// it is NEVER trusted from the client.
///
/// Idempotent: re-registering an active (user_id, token) pair updates
/// last_used_at + app_version + device_model + locale and returns
/// already_registered=true. Token rotation handled by Firebase SDK on the
/// client; on rotation the client calls this with the new token.
class RegisterFCMTokenRequest extends $pb.GeneratedMessage {
  factory RegisterFCMTokenRequest({
    $core.String? token,
    Platform? platform,
    $core.String? appVersion,
    $core.String? deviceModel,
    $core.String? locale,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (platform != null) result.platform = platform;
    if (appVersion != null) result.appVersion = appVersion;
    if (deviceModel != null) result.deviceModel = deviceModel;
    if (locale != null) result.locale = locale;
    return result;
  }

  RegisterFCMTokenRequest._();

  factory RegisterFCMTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterFCMTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterFCMTokenRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aE<Platform>(2, _omitFieldNames ? '' : 'platform',
        enumValues: Platform.values)
    ..aOS(3, _omitFieldNames ? '' : 'appVersion')
    ..aOS(4, _omitFieldNames ? '' : 'deviceModel')
    ..aOS(5, _omitFieldNames ? '' : 'locale')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFCMTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFCMTokenRequest copyWith(
          void Function(RegisterFCMTokenRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterFCMTokenRequest))
          as RegisterFCMTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterFCMTokenRequest create() => RegisterFCMTokenRequest._();
  @$core.override
  RegisterFCMTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterFCMTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterFCMTokenRequest>(create);
  static RegisterFCMTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  Platform get platform => $_getN(1);
  @$pb.TagNumber(2)
  set platform(Platform value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPlatform() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlatform() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get appVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set appVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAppVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearAppVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get deviceModel => $_getSZ(3);
  @$pb.TagNumber(4)
  set deviceModel($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeviceModel() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceModel() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get locale => $_getSZ(4);
  @$pb.TagNumber(5)
  set locale($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLocale() => $_has(4);
  @$pb.TagNumber(5)
  void clearLocale() => $_clearField(5);
}

class RegisterFCMTokenResponse extends $pb.GeneratedMessage {
  factory RegisterFCMTokenResponse({
    $core.String? tokenId,
    $core.bool? alreadyRegistered,
  }) {
    final result = create();
    if (tokenId != null) result.tokenId = tokenId;
    if (alreadyRegistered != null) result.alreadyRegistered = alreadyRegistered;
    return result;
  }

  RegisterFCMTokenResponse._();

  factory RegisterFCMTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterFCMTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterFCMTokenResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'tokenId')
    ..aOB(2, _omitFieldNames ? '' : 'alreadyRegistered')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFCMTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFCMTokenResponse copyWith(
          void Function(RegisterFCMTokenResponse) updates) =>
      super.copyWith((message) => updates(message as RegisterFCMTokenResponse))
          as RegisterFCMTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterFCMTokenResponse create() => RegisterFCMTokenResponse._();
  @$core.override
  RegisterFCMTokenResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterFCMTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterFCMTokenResponse>(create);
  static RegisterFCMTokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get tokenId => $_getSZ(0);
  @$pb.TagNumber(1)
  set tokenId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTokenId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTokenId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get alreadyRegistered => $_getBF(1);
  @$pb.TagNumber(2)
  set alreadyRegistered($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAlreadyRegistered() => $_has(1);
  @$pb.TagNumber(2)
  void clearAlreadyRegistered() => $_clearField(2);
}

/// RemoveFCMToken soft-deletes a token (sets invalidated_at). Called on user
/// logout from a device. Idempotent: removing an already-removed token is a
/// no-op success.
class RemoveFCMTokenRequest extends $pb.GeneratedMessage {
  factory RemoveFCMTokenRequest({
    $core.String? token,
  }) {
    final result = create();
    if (token != null) result.token = token;
    return result;
  }

  RemoveFCMTokenRequest._();

  factory RemoveFCMTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveFCMTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveFCMTokenRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveFCMTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveFCMTokenRequest copyWith(
          void Function(RemoveFCMTokenRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveFCMTokenRequest))
          as RemoveFCMTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveFCMTokenRequest create() => RemoveFCMTokenRequest._();
  @$core.override
  RemoveFCMTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveFCMTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveFCMTokenRequest>(create);
  static RemoveFCMTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);
}

class GetUnreadCountResponse extends $pb.GeneratedMessage {
  factory GetUnreadCountResponse({
    $core.int? count,
  }) {
    final result = create();
    if (count != null) result.count = count;
    return result;
  }

  GetUnreadCountResponse._();

  factory GetUnreadCountResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetUnreadCountResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetUnreadCountResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUnreadCountResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUnreadCountResponse copyWith(
          void Function(GetUnreadCountResponse) updates) =>
      super.copyWith((message) => updates(message as GetUnreadCountResponse))
          as GetUnreadCountResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetUnreadCountResponse create() => GetUnreadCountResponse._();
  @$core.override
  GetUnreadCountResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetUnreadCountResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetUnreadCountResponse>(create);
  static GetUnreadCountResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get count => $_getIZ(0);
  @$pb.TagNumber(1)
  set count($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearCount() => $_clearField(1);
}

class HealthCheckResponse extends $pb.GeneratedMessage {
  factory HealthCheckResponse({
    $core.bool? ok,
    $core.String? version,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    if (version != null) result.version = version;
    return result;
  }

  HealthCheckResponse._();

  factory HealthCheckResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HealthCheckResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HealthCheckResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse copyWith(void Function(HealthCheckResponse) updates) =>
      super.copyWith((message) => updates(message as HealthCheckResponse))
          as HealthCheckResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse create() => HealthCheckResponse._();
  @$core.override
  HealthCheckResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HealthCheckResponse>(create);
  static HealthCheckResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
