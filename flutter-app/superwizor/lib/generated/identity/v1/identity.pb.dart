// This is a generated file - do not edit.
//
// Generated from identity/v1/identity.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $2;

import 'identity.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'identity.pbenum.dart';

class DeleteMyAccountRequest extends $pb.GeneratedMessage {
  factory DeleteMyAccountRequest({
    $core.String? confirmation,
    $core.String? reason,
    $core.bool? acknowledgedSubscription,
  }) {
    final result = create();
    if (confirmation != null) result.confirmation = confirmation;
    if (reason != null) result.reason = reason;
    if (acknowledgedSubscription != null)
      result.acknowledgedSubscription = acknowledgedSubscription;
    return result;
  }

  DeleteMyAccountRequest._();

  factory DeleteMyAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteMyAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteMyAccountRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'confirmation')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..aOB(3, _omitFieldNames ? '' : 'acknowledgedSubscription')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteMyAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteMyAccountRequest copyWith(
          void Function(DeleteMyAccountRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteMyAccountRequest))
          as DeleteMyAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteMyAccountRequest create() => DeleteMyAccountRequest._();
  @$core.override
  DeleteMyAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteMyAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteMyAccountRequest>(create);
  static DeleteMyAccountRequest? _defaultInstance;

  /// Tekst potwierdzenia wpisany przez użytkownika ("USUWAM" / "DELETE").
  /// Chroni przed przypadkowym tapnięciem — nie jest hasłem.
  @$pb.TagNumber(1)
  $core.String get confirmation => $_getSZ(0);
  @$pb.TagNumber(1)
  set confirmation($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConfirmation() => $_has(0);
  @$pb.TagNumber(1)
  void clearConfirmation() => $_clearField(1);

  /// Opcjonalny powód rezygnacji. Trafia do audytu, nie do CRM.
  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  /// Potwierdzenie, że użytkownik wie o aktywnej subskrypcji ze sklepu.
  ///
  /// Subskrypcji kupionej w App Store nie umiemy anulować — może to
  /// zrobić tylko właściciel konta Apple. Bez tej flagi RPC odrzuca
  /// żądanie z FAILED_PRECONDITION "STORE_SUBSCRIPTION_ACTIVE", a
  /// aplikacja pokazuje deep link do ustawień subskrypcji (docs/70 E5).
  @$pb.TagNumber(3)
  $core.bool get acknowledgedSubscription => $_getBF(2);
  @$pb.TagNumber(3)
  set acknowledgedSubscription($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAcknowledgedSubscription() => $_has(2);
  @$pb.TagNumber(3)
  void clearAcknowledgedSubscription() => $_clearField(3);
}

class AppLoginToken extends $pb.GeneratedMessage {
  factory AppLoginToken({
    $core.String? token,
  }) {
    final result = create();
    if (token != null) result.token = token;
    return result;
  }

  AppLoginToken._();

  factory AppLoginToken.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AppLoginToken.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppLoginToken',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppLoginToken clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppLoginToken copyWith(void Function(AppLoginToken) updates) =>
      super.copyWith((message) => updates(message as AppLoginToken))
          as AppLoginToken;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AppLoginToken create() => AppLoginToken._();
  @$core.override
  AppLoginToken createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AppLoginToken getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AppLoginToken>(create);
  static AppLoginToken? _defaultInstance;

  /// Firebase custom token (JWT). Pass to firebase_auth's
  /// signInWithCustomToken() on the receiving origin.
  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);
}

class User extends $pb.GeneratedMessage {
  factory User({
    $core.String? id,
    UserRole? role,
    $core.String? organizationId,
    $core.String? firebaseUid,
    $core.String? email,
    $core.String? phoneNumber,
    $core.bool? isEmailVerified,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? professionalTitle,
    $core.String? credentialsNumber,
    $core.String? uiLanguage,
    $core.String? timezone,
    $core.bool? hasAcceptedTos,
    $2.Timestamp? createdAt,
    $core.String? biography,
    $core.String? avatarUrl,
    $core.String? defaultModalityId,
    $core.String? billingAddressId,
    $core.bool? hasMarketingConsent,
    $core.bool? isActive,
    OrganizationType? organizationType,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (role != null) result.role = role;
    if (organizationId != null) result.organizationId = organizationId;
    if (firebaseUid != null) result.firebaseUid = firebaseUid;
    if (email != null) result.email = email;
    if (phoneNumber != null) result.phoneNumber = phoneNumber;
    if (isEmailVerified != null) result.isEmailVerified = isEmailVerified;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (professionalTitle != null) result.professionalTitle = professionalTitle;
    if (credentialsNumber != null) result.credentialsNumber = credentialsNumber;
    if (uiLanguage != null) result.uiLanguage = uiLanguage;
    if (timezone != null) result.timezone = timezone;
    if (hasAcceptedTos != null) result.hasAcceptedTos = hasAcceptedTos;
    if (createdAt != null) result.createdAt = createdAt;
    if (biography != null) result.biography = biography;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (defaultModalityId != null) result.defaultModalityId = defaultModalityId;
    if (billingAddressId != null) result.billingAddressId = billingAddressId;
    if (hasMarketingConsent != null)
      result.hasMarketingConsent = hasMarketingConsent;
    if (isActive != null) result.isActive = isActive;
    if (organizationType != null) result.organizationType = organizationType;
    return result;
  }

  User._();

  factory User.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory User.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'User',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aE<UserRole>(2, _omitFieldNames ? '' : 'role',
        enumValues: UserRole.values)
    ..aOS(3, _omitFieldNames ? '' : 'organizationId')
    ..aOS(4, _omitFieldNames ? '' : 'firebaseUid')
    ..aOS(5, _omitFieldNames ? '' : 'email')
    ..aOS(6, _omitFieldNames ? '' : 'phoneNumber')
    ..aOB(7, _omitFieldNames ? '' : 'isEmailVerified')
    ..aOS(8, _omitFieldNames ? '' : 'firstName')
    ..aOS(9, _omitFieldNames ? '' : 'lastName')
    ..aOS(10, _omitFieldNames ? '' : 'professionalTitle')
    ..aOS(11, _omitFieldNames ? '' : 'credentialsNumber')
    ..aOS(12, _omitFieldNames ? '' : 'uiLanguage')
    ..aOS(13, _omitFieldNames ? '' : 'timezone')
    ..aOB(14, _omitFieldNames ? '' : 'hasAcceptedTos')
    ..aOM<$2.Timestamp>(15, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOS(16, _omitFieldNames ? '' : 'biography')
    ..aOS(17, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(18, _omitFieldNames ? '' : 'defaultModalityId')
    ..aOS(19, _omitFieldNames ? '' : 'billingAddressId')
    ..aOB(20, _omitFieldNames ? '' : 'hasMarketingConsent')
    ..aOB(21, _omitFieldNames ? '' : 'isActive')
    ..aE<OrganizationType>(22, _omitFieldNames ? '' : 'organizationType',
        enumValues: OrganizationType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User copyWith(void Function(User) updates) =>
      super.copyWith((message) => updates(message as User)) as User;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static User create() => User._();
  @$core.override
  User createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static User getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<User>(create);
  static User? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  UserRole get role => $_getN(1);
  @$pb.TagNumber(2)
  set role(UserRole value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRole() => $_has(1);
  @$pb.TagNumber(2)
  void clearRole() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get organizationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set organizationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOrganizationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearOrganizationId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get firebaseUid => $_getSZ(3);
  @$pb.TagNumber(4)
  set firebaseUid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFirebaseUid() => $_has(3);
  @$pb.TagNumber(4)
  void clearFirebaseUid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get email => $_getSZ(4);
  @$pb.TagNumber(5)
  set email($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get phoneNumber => $_getSZ(5);
  @$pb.TagNumber(6)
  set phoneNumber($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPhoneNumber() => $_has(5);
  @$pb.TagNumber(6)
  void clearPhoneNumber() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isEmailVerified => $_getBF(6);
  @$pb.TagNumber(7)
  set isEmailVerified($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsEmailVerified() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsEmailVerified() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get firstName => $_getSZ(7);
  @$pb.TagNumber(8)
  set firstName($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFirstName() => $_has(7);
  @$pb.TagNumber(8)
  void clearFirstName() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get lastName => $_getSZ(8);
  @$pb.TagNumber(9)
  set lastName($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLastName() => $_has(8);
  @$pb.TagNumber(9)
  void clearLastName() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get professionalTitle => $_getSZ(9);
  @$pb.TagNumber(10)
  set professionalTitle($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasProfessionalTitle() => $_has(9);
  @$pb.TagNumber(10)
  void clearProfessionalTitle() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get credentialsNumber => $_getSZ(10);
  @$pb.TagNumber(11)
  set credentialsNumber($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCredentialsNumber() => $_has(10);
  @$pb.TagNumber(11)
  void clearCredentialsNumber() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get uiLanguage => $_getSZ(11);
  @$pb.TagNumber(12)
  set uiLanguage($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasUiLanguage() => $_has(11);
  @$pb.TagNumber(12)
  void clearUiLanguage() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get timezone => $_getSZ(12);
  @$pb.TagNumber(13)
  set timezone($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasTimezone() => $_has(12);
  @$pb.TagNumber(13)
  void clearTimezone() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get hasAcceptedTos => $_getBF(13);
  @$pb.TagNumber(14)
  set hasAcceptedTos($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasHasAcceptedTos() => $_has(13);
  @$pb.TagNumber(14)
  void clearHasAcceptedTos() => $_clearField(14);

  @$pb.TagNumber(15)
  $2.Timestamp get createdAt => $_getN(14);
  @$pb.TagNumber(15)
  set createdAt($2.Timestamp value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasCreatedAt() => $_has(14);
  @$pb.TagNumber(15)
  void clearCreatedAt() => $_clearField(15);
  @$pb.TagNumber(15)
  $2.Timestamp ensureCreatedAt() => $_ensure(14);

  @$pb.TagNumber(16)
  $core.String get biography => $_getSZ(15);
  @$pb.TagNumber(16)
  set biography($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasBiography() => $_has(15);
  @$pb.TagNumber(16)
  void clearBiography() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get avatarUrl => $_getSZ(16);
  @$pb.TagNumber(17)
  set avatarUrl($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasAvatarUrl() => $_has(16);
  @$pb.TagNumber(17)
  void clearAvatarUrl() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.String get defaultModalityId => $_getSZ(17);
  @$pb.TagNumber(18)
  set defaultModalityId($core.String value) => $_setString(17, value);
  @$pb.TagNumber(18)
  $core.bool hasDefaultModalityId() => $_has(17);
  @$pb.TagNumber(18)
  void clearDefaultModalityId() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.String get billingAddressId => $_getSZ(18);
  @$pb.TagNumber(19)
  set billingAddressId($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasBillingAddressId() => $_has(18);
  @$pb.TagNumber(19)
  void clearBillingAddressId() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.bool get hasMarketingConsent => $_getBF(19);
  @$pb.TagNumber(20)
  set hasMarketingConsent($core.bool value) => $_setBool(19, value);
  @$pb.TagNumber(20)
  $core.bool hasHasMarketingConsent() => $_has(19);
  @$pb.TagNumber(20)
  void clearHasMarketingConsent() => $_clearField(20);

  /// FALSE = reversibly deactivated by ORG_ADMIN (SetTherapistStatus).
  /// Sign-in blocked; data untouched. Independent of soft-delete.
  @$pb.TagNumber(21)
  $core.bool get isActive => $_getBF(20);
  @$pb.TagNumber(21)
  set isActive($core.bool value) => $_setBool(20, value);
  @$pb.TagNumber(21)
  $core.bool hasIsActive() => $_has(20);
  @$pb.TagNumber(21)
  void clearIsActive() => $_clearField(21);

  /// Type of the user's organization (docs/38): CLINIC/ENTERPRISE means
  /// a managed B2B org — clients hide self-serve billing surfaces.
  /// Populated by GetMyProfile (needs an org lookup); other RPCs may
  /// leave it UNSPECIFIED.
  @$pb.TagNumber(22)
  OrganizationType get organizationType => $_getN(21);
  @$pb.TagNumber(22)
  set organizationType(OrganizationType value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasOrganizationType() => $_has(21);
  @$pb.TagNumber(22)
  void clearOrganizationType() => $_clearField(22);
}

class UserContext extends $pb.GeneratedMessage {
  factory UserContext({
    $core.String? userId,
    $core.String? firebaseUid,
    UserRole? role,
    $core.String? organizationId,
    $core.String? email,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (firebaseUid != null) result.firebaseUid = firebaseUid;
    if (role != null) result.role = role;
    if (organizationId != null) result.organizationId = organizationId;
    if (email != null) result.email = email;
    return result;
  }

  UserContext._();

  factory UserContext.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserContext.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserContext',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'firebaseUid')
    ..aE<UserRole>(3, _omitFieldNames ? '' : 'role',
        enumValues: UserRole.values)
    ..aOS(4, _omitFieldNames ? '' : 'organizationId')
    ..aOS(5, _omitFieldNames ? '' : 'email')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserContext clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserContext copyWith(void Function(UserContext) updates) =>
      super.copyWith((message) => updates(message as UserContext))
          as UserContext;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserContext create() => UserContext._();
  @$core.override
  UserContext createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserContext getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserContext>(create);
  static UserContext? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get firebaseUid => $_getSZ(1);
  @$pb.TagNumber(2)
  set firebaseUid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirebaseUid() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirebaseUid() => $_clearField(2);

  @$pb.TagNumber(3)
  UserRole get role => $_getN(2);
  @$pb.TagNumber(3)
  set role(UserRole value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRole() => $_has(2);
  @$pb.TagNumber(3)
  void clearRole() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get organizationId => $_getSZ(3);
  @$pb.TagNumber(4)
  set organizationId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOrganizationId() => $_has(3);
  @$pb.TagNumber(4)
  void clearOrganizationId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get email => $_getSZ(4);
  @$pb.TagNumber(5)
  set email($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearEmail() => $_clearField(5);
}

class ValidateTokenRequest extends $pb.GeneratedMessage {
  factory ValidateTokenRequest({
    $core.String? firebaseIdToken,
  }) {
    final result = create();
    if (firebaseIdToken != null) result.firebaseIdToken = firebaseIdToken;
    return result;
  }

  ValidateTokenRequest._();

  factory ValidateTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ValidateTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ValidateTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'firebaseIdToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValidateTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValidateTokenRequest copyWith(void Function(ValidateTokenRequest) updates) =>
      super.copyWith((message) => updates(message as ValidateTokenRequest))
          as ValidateTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ValidateTokenRequest create() => ValidateTokenRequest._();
  @$core.override
  ValidateTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ValidateTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ValidateTokenRequest>(create);
  static ValidateTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get firebaseIdToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set firebaseIdToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFirebaseIdToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearFirebaseIdToken() => $_clearField(1);
}

class GetUserRequest extends $pb.GeneratedMessage {
  factory GetUserRequest({
    $core.String? userId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    return result;
  }

  GetUserRequest._();

  factory GetUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserRequest copyWith(void Function(GetUserRequest) updates) =>
      super.copyWith((message) => updates(message as GetUserRequest))
          as GetUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetUserRequest create() => GetUserRequest._();
  @$core.override
  GetUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetUserRequest>(create);
  static GetUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);
}

class GetUserByFirebaseUIDRequest extends $pb.GeneratedMessage {
  factory GetUserByFirebaseUIDRequest({
    $core.String? firebaseUid,
  }) {
    final result = create();
    if (firebaseUid != null) result.firebaseUid = firebaseUid;
    return result;
  }

  GetUserByFirebaseUIDRequest._();

  factory GetUserByFirebaseUIDRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetUserByFirebaseUIDRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetUserByFirebaseUIDRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'firebaseUid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserByFirebaseUIDRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserByFirebaseUIDRequest copyWith(
          void Function(GetUserByFirebaseUIDRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetUserByFirebaseUIDRequest))
          as GetUserByFirebaseUIDRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetUserByFirebaseUIDRequest create() =>
      GetUserByFirebaseUIDRequest._();
  @$core.override
  GetUserByFirebaseUIDRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetUserByFirebaseUIDRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetUserByFirebaseUIDRequest>(create);
  static GetUserByFirebaseUIDRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get firebaseUid => $_getSZ(0);
  @$pb.TagNumber(1)
  set firebaseUid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFirebaseUid() => $_has(0);
  @$pb.TagNumber(1)
  void clearFirebaseUid() => $_clearField(1);
}

class CreateUserRequest extends $pb.GeneratedMessage {
  factory CreateUserRequest({
    $core.String? firebaseUid,
    $core.String? email,
    UserRole? role,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? uiLanguage,
    $core.String? timezone,
    $core.bool? hasAcceptedTos,
    $core.String? initialPlanTier,
  }) {
    final result = create();
    if (firebaseUid != null) result.firebaseUid = firebaseUid;
    if (email != null) result.email = email;
    if (role != null) result.role = role;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (uiLanguage != null) result.uiLanguage = uiLanguage;
    if (timezone != null) result.timezone = timezone;
    if (hasAcceptedTos != null) result.hasAcceptedTos = hasAcceptedTos;
    if (initialPlanTier != null) result.initialPlanTier = initialPlanTier;
    return result;
  }

  CreateUserRequest._();

  factory CreateUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'firebaseUid')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aE<UserRole>(3, _omitFieldNames ? '' : 'role',
        enumValues: UserRole.values)
    ..aOS(4, _omitFieldNames ? '' : 'firstName')
    ..aOS(5, _omitFieldNames ? '' : 'lastName')
    ..aOS(6, _omitFieldNames ? '' : 'uiLanguage')
    ..aOS(7, _omitFieldNames ? '' : 'timezone')
    ..aOB(8, _omitFieldNames ? '' : 'hasAcceptedTos')
    ..aOS(9, _omitFieldNames ? '' : 'initialPlanTier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateUserRequest copyWith(void Function(CreateUserRequest) updates) =>
      super.copyWith((message) => updates(message as CreateUserRequest))
          as CreateUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateUserRequest create() => CreateUserRequest._();
  @$core.override
  CreateUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateUserRequest>(create);
  static CreateUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get firebaseUid => $_getSZ(0);
  @$pb.TagNumber(1)
  set firebaseUid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFirebaseUid() => $_has(0);
  @$pb.TagNumber(1)
  void clearFirebaseUid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  UserRole get role => $_getN(2);
  @$pb.TagNumber(3)
  set role(UserRole value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRole() => $_has(2);
  @$pb.TagNumber(3)
  void clearRole() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get firstName => $_getSZ(3);
  @$pb.TagNumber(4)
  set firstName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFirstName() => $_has(3);
  @$pb.TagNumber(4)
  void clearFirstName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get lastName => $_getSZ(4);
  @$pb.TagNumber(5)
  set lastName($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastName() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastName() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get uiLanguage => $_getSZ(5);
  @$pb.TagNumber(6)
  set uiLanguage($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUiLanguage() => $_has(5);
  @$pb.TagNumber(6)
  void clearUiLanguage() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get timezone => $_getSZ(6);
  @$pb.TagNumber(7)
  set timezone($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTimezone() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimezone() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get hasAcceptedTos => $_getBF(7);
  @$pb.TagNumber(8)
  set hasAcceptedTos($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHasAcceptedTos() => $_has(7);
  @$pb.TagNumber(8)
  void clearHasAcceptedTos() => $_clearField(8);

  /// Optional: plan tier to provision on signup. Valid values:
  ///   - "" or "TRIAL" → default trial (5 tokens)
  ///   - "BETA"        → beta program (120 tokens × 2 months)
  /// Paid tiers (SOLO/PRO) are provisioned via Stripe Checkout,
  /// not through this field.
  @$pb.TagNumber(9)
  $core.String get initialPlanTier => $_getSZ(8);
  @$pb.TagNumber(9)
  set initialPlanTier($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasInitialPlanTier() => $_has(8);
  @$pb.TagNumber(9)
  void clearInitialPlanTier() => $_clearField(9);
}

/// UpdateProfileRequest is the iOS-compatible profile mutation. Per
/// docs/18 D2: iOS sends a subset (fields 2-7), web sends the full
/// payload. The handler does a selective UPDATE — fields whose
/// `optional` wrapper is unset are skipped; empty strings on
/// fields 2-7 (iOS contract) are also skipped to preserve the
/// "missing field means no change" semantics existing clients rely
/// on. New fields 8-13 use `optional` so the wire distinguishes
/// "blank the column" from "don't touch it" cleanly.
class UpdateProfileRequest extends $pb.GeneratedMessage {
  factory UpdateProfileRequest({
    $core.String? userId,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? professionalTitle,
    $core.String? credentialsNumber,
    $core.String? biography,
    $core.String? phoneNumber,
    $core.String? avatarUrl,
    $core.String? defaultModalityId,
    $core.String? uiLanguage,
    $core.String? timezone,
    Address? billingAddress,
    $core.bool? hasMarketingConsent,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (professionalTitle != null) result.professionalTitle = professionalTitle;
    if (credentialsNumber != null) result.credentialsNumber = credentialsNumber;
    if (biography != null) result.biography = biography;
    if (phoneNumber != null) result.phoneNumber = phoneNumber;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (defaultModalityId != null) result.defaultModalityId = defaultModalityId;
    if (uiLanguage != null) result.uiLanguage = uiLanguage;
    if (timezone != null) result.timezone = timezone;
    if (billingAddress != null) result.billingAddress = billingAddress;
    if (hasMarketingConsent != null)
      result.hasMarketingConsent = hasMarketingConsent;
    return result;
  }

  UpdateProfileRequest._();

  factory UpdateProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'firstName')
    ..aOS(3, _omitFieldNames ? '' : 'lastName')
    ..aOS(4, _omitFieldNames ? '' : 'professionalTitle')
    ..aOS(5, _omitFieldNames ? '' : 'credentialsNumber')
    ..aOS(6, _omitFieldNames ? '' : 'biography')
    ..aOS(7, _omitFieldNames ? '' : 'phoneNumber')
    ..aOS(8, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(9, _omitFieldNames ? '' : 'defaultModalityId')
    ..aOS(10, _omitFieldNames ? '' : 'uiLanguage')
    ..aOS(11, _omitFieldNames ? '' : 'timezone')
    ..aOM<Address>(12, _omitFieldNames ? '' : 'billingAddress',
        subBuilder: Address.create)
    ..aOB(13, _omitFieldNames ? '' : 'hasMarketingConsent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProfileRequest copyWith(void Function(UpdateProfileRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateProfileRequest))
          as UpdateProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateProfileRequest create() => UpdateProfileRequest._();
  @$core.override
  UpdateProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateProfileRequest>(create);
  static UpdateProfileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get firstName => $_getSZ(1);
  @$pb.TagNumber(2)
  set firstName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirstName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirstName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get lastName => $_getSZ(2);
  @$pb.TagNumber(3)
  set lastName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastName() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get professionalTitle => $_getSZ(3);
  @$pb.TagNumber(4)
  set professionalTitle($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProfessionalTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearProfessionalTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get credentialsNumber => $_getSZ(4);
  @$pb.TagNumber(5)
  set credentialsNumber($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCredentialsNumber() => $_has(4);
  @$pb.TagNumber(5)
  void clearCredentialsNumber() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get biography => $_getSZ(5);
  @$pb.TagNumber(6)
  set biography($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBiography() => $_has(5);
  @$pb.TagNumber(6)
  void clearBiography() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get phoneNumber => $_getSZ(6);
  @$pb.TagNumber(7)
  set phoneNumber($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPhoneNumber() => $_has(6);
  @$pb.TagNumber(7)
  void clearPhoneNumber() => $_clearField(7);

  /// Web additions (docs/18 §13.4) — full editable surface.
  @$pb.TagNumber(8)
  $core.String get avatarUrl => $_getSZ(7);
  @$pb.TagNumber(8)
  set avatarUrl($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAvatarUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearAvatarUrl() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get defaultModalityId => $_getSZ(8);
  @$pb.TagNumber(9)
  set defaultModalityId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDefaultModalityId() => $_has(8);
  @$pb.TagNumber(9)
  void clearDefaultModalityId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get uiLanguage => $_getSZ(9);
  @$pb.TagNumber(10)
  set uiLanguage($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasUiLanguage() => $_has(9);
  @$pb.TagNumber(10)
  void clearUiLanguage() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get timezone => $_getSZ(10);
  @$pb.TagNumber(11)
  set timezone($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasTimezone() => $_has(10);
  @$pb.TagNumber(11)
  void clearTimezone() => $_clearField(11);

  @$pb.TagNumber(12)
  Address get billingAddress => $_getN(11);
  @$pb.TagNumber(12)
  set billingAddress(Address value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasBillingAddress() => $_has(11);
  @$pb.TagNumber(12)
  void clearBillingAddress() => $_clearField(12);
  @$pb.TagNumber(12)
  Address ensureBillingAddress() => $_ensure(11);

  @$pb.TagNumber(13)
  $core.bool get hasMarketingConsent => $_getBF(12);
  @$pb.TagNumber(13)
  set hasMarketingConsent($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasHasMarketingConsent() => $_has(12);
  @$pb.TagNumber(13)
  void clearHasMarketingConsent() => $_clearField(13);
}

class CheckPermissionRequest extends $pb.GeneratedMessage {
  factory CheckPermissionRequest({
    $core.String? userId,
    $core.String? resourceType,
    $core.String? resourceId,
    $core.String? action,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (resourceType != null) result.resourceType = resourceType;
    if (resourceId != null) result.resourceId = resourceId;
    if (action != null) result.action = action;
    return result;
  }

  CheckPermissionRequest._();

  factory CheckPermissionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckPermissionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckPermissionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'resourceType')
    ..aOS(3, _omitFieldNames ? '' : 'resourceId')
    ..aOS(4, _omitFieldNames ? '' : 'action')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckPermissionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckPermissionRequest copyWith(
          void Function(CheckPermissionRequest) updates) =>
      super.copyWith((message) => updates(message as CheckPermissionRequest))
          as CheckPermissionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckPermissionRequest create() => CheckPermissionRequest._();
  @$core.override
  CheckPermissionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckPermissionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckPermissionRequest>(create);
  static CheckPermissionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get resourceType => $_getSZ(1);
  @$pb.TagNumber(2)
  set resourceType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResourceType() => $_has(1);
  @$pb.TagNumber(2)
  void clearResourceType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get resourceId => $_getSZ(2);
  @$pb.TagNumber(3)
  set resourceId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasResourceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearResourceId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get action => $_getSZ(3);
  @$pb.TagNumber(4)
  set action($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAction() => $_has(3);
  @$pb.TagNumber(4)
  void clearAction() => $_clearField(4);
}

class PermissionDecision extends $pb.GeneratedMessage {
  factory PermissionDecision({
    $core.bool? allowed,
    $core.String? reason,
  }) {
    final result = create();
    if (allowed != null) result.allowed = allowed;
    if (reason != null) result.reason = reason;
    return result;
  }

  PermissionDecision._();

  factory PermissionDecision.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PermissionDecision.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PermissionDecision',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'allowed')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PermissionDecision clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PermissionDecision copyWith(void Function(PermissionDecision) updates) =>
      super.copyWith((message) => updates(message as PermissionDecision))
          as PermissionDecision;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PermissionDecision create() => PermissionDecision._();
  @$core.override
  PermissionDecision createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PermissionDecision getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PermissionDecision>(create);
  static PermissionDecision? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get allowed => $_getBF(0);
  @$pb.TagNumber(1)
  set allowed($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAllowed() => $_has(0);
  @$pb.TagNumber(1)
  void clearAllowed() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class HealthCheckResponse extends $pb.GeneratedMessage {
  factory HealthCheckResponse({
    $core.String? status,
    $core.String? version,
  }) {
    final result = create();
    if (status != null) result.status = status;
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
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'status')
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
  $core.String get status => $_getSZ(0);
  @$pb.TagNumber(1)
  set status($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);
}

/// ─── Report customization messages ───
/// Each enum-valued field stores the string ID of the choice (e.g.
/// "brief", "clinical_formal") — UI translates to localized labels.
/// Empty strings mean "use default" for that dimension; the renderer
/// in ai-pipeline-svc treats them as no-op.
class ReportPreferences extends $pb.GeneratedMessage {
  factory ReportPreferences({
    $core.int? version,
    $core.String? length,
    $core.String? tone,
    $core.String? quoteDensity,
    $core.String? diagnosticLanguage,
    $core.String? hypothesisHedging,
    $core.Iterable<$core.String>? sectionEmphasis,
    $core.String? strengthsFraming,
    $core.String? freeText,
    $2.Timestamp? updatedAt,
    $core.bool? experimentalDualRun,
    $core.bool? experimentalAvailable,
  }) {
    final result = create();
    if (version != null) result.version = version;
    if (length != null) result.length = length;
    if (tone != null) result.tone = tone;
    if (quoteDensity != null) result.quoteDensity = quoteDensity;
    if (diagnosticLanguage != null)
      result.diagnosticLanguage = diagnosticLanguage;
    if (hypothesisHedging != null) result.hypothesisHedging = hypothesisHedging;
    if (sectionEmphasis != null) result.sectionEmphasis.addAll(sectionEmphasis);
    if (strengthsFraming != null) result.strengthsFraming = strengthsFraming;
    if (freeText != null) result.freeText = freeText;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (experimentalDualRun != null)
      result.experimentalDualRun = experimentalDualRun;
    if (experimentalAvailable != null)
      result.experimentalAvailable = experimentalAvailable;
    return result;
  }

  ReportPreferences._();

  factory ReportPreferences.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReportPreferences.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReportPreferences',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'version')
    ..aOS(2, _omitFieldNames ? '' : 'length')
    ..aOS(3, _omitFieldNames ? '' : 'tone')
    ..aOS(4, _omitFieldNames ? '' : 'quoteDensity')
    ..aOS(5, _omitFieldNames ? '' : 'diagnosticLanguage')
    ..aOS(6, _omitFieldNames ? '' : 'hypothesisHedging')
    ..pPS(7, _omitFieldNames ? '' : 'sectionEmphasis')
    ..aOS(8, _omitFieldNames ? '' : 'strengthsFraming')
    ..aOS(9, _omitFieldNames ? '' : 'freeText')
    ..aOM<$2.Timestamp>(10, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $2.Timestamp.create)
    ..aOB(11, _omitFieldNames ? '' : 'experimentalDualRun')
    ..aOB(12, _omitFieldNames ? '' : 'experimentalAvailable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportPreferences clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportPreferences copyWith(void Function(ReportPreferences) updates) =>
      super.copyWith((message) => updates(message as ReportPreferences))
          as ReportPreferences;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReportPreferences create() => ReportPreferences._();
  @$core.override
  ReportPreferences createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReportPreferences getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReportPreferences>(create);
  static ReportPreferences? _defaultInstance;

  /// Schema version. Bump when we add a new dimension without a
  /// proto-message change so renderers can branch on it.
  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  /// Length: "brief" | "standard" | "detailed"
  @$pb.TagNumber(2)
  $core.String get length => $_getSZ(1);
  @$pb.TagNumber(2)
  set length($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLength() => $_has(1);
  @$pb.TagNumber(2)
  void clearLength() => $_clearField(2);

  /// Tone: "clinical_formal" | "empathic_warm" | "pragmatic_direct"
  /// | "academic_rigorous"
  @$pb.TagNumber(3)
  $core.String get tone => $_getSZ(2);
  @$pb.TagNumber(3)
  set tone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTone() => $_has(2);
  @$pb.TagNumber(3)
  void clearTone() => $_clearField(3);

  /// Quote density: "few" | "selective" | "many"
  @$pb.TagNumber(4)
  $core.String get quoteDensity => $_getSZ(3);
  @$pb.TagNumber(4)
  set quoteDensity($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasQuoteDensity() => $_has(3);
  @$pb.TagNumber(4)
  void clearQuoteDensity() => $_clearField(4);

  /// Diagnostic language: "descriptive" | "clinical_labels" | "dsm_icd"
  @$pb.TagNumber(5)
  $core.String get diagnosticLanguage => $_getSZ(4);
  @$pb.TagNumber(5)
  set diagnosticLanguage($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDiagnosticLanguage() => $_has(4);
  @$pb.TagNumber(5)
  void clearDiagnosticLanguage() => $_clearField(5);

  /// Hypothesis hedging: "tentative" | "balanced" | "assertive"
  @$pb.TagNumber(6)
  $core.String get hypothesisHedging => $_getSZ(5);
  @$pb.TagNumber(6)
  set hypothesisHedging($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHypothesisHedging() => $_has(5);
  @$pb.TagNumber(6)
  void clearHypothesisHedging() => $_clearField(6);

  /// Multi-select section IDs to expand:
  /// "clinical_picture", "interventions", "case_formulation",
  /// "supervisory_recommendations", "homework_between_sessions",
  /// "cultural_context", "safety_and_risk".
  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get sectionEmphasis => $_getList(6);

  /// Strengths framing: "problem_focused" | "balanced" | "strengths_first"
  @$pb.TagNumber(8)
  $core.String get strengthsFraming => $_getSZ(7);
  @$pb.TagNumber(8)
  set strengthsFraming($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStrengthsFraming() => $_has(7);
  @$pb.TagNumber(8)
  void clearStrengthsFraming() => $_clearField(8);

  /// Free-text additional guidance, ≤500 chars, server-sanitized.
  @$pb.TagNumber(9)
  $core.String get freeText => $_getSZ(8);
  @$pb.TagNumber(9)
  set freeText($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFreeText() => $_has(8);
  @$pb.TagNumber(9)
  void clearFreeText() => $_clearField(9);

  @$pb.TagNumber(10)
  $2.Timestamp get updatedAt => $_getN(9);
  @$pb.TagNumber(10)
  set updatedAt($2.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasUpdatedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearUpdatedAt() => $_clearField(10);
  @$pb.TagNumber(10)
  $2.Timestamp ensureUpdatedAt() => $_ensure(9);

  /// Tryb eksperymentalny (plan 16 §2.5): kazda NOWA ukonczona sesja
  /// generuje raport eksperymentalny OBOK produkcyjnego. Ekspert nagrywa
  /// normalnie i dostaje oba do porownania, zero czynnosci per raport.
  ///
  /// NIE jest preferencja stylu jak pozostale pola — decyduje, ILE
  /// raportow powstaje, i nie wchodzi do promptu. Jedzie tym kanalem, bo
  /// llm-worker i tak czyta preferencje przy generacji, wiec sciezka
  /// automatyczna nie potrzebuje nowego RPC.
  ///
  /// Przelacznik jest widoczny w ustawieniach WYLACZNIE, gdy organizacja
  /// ma REPORT_EXPERIMENTAL_ENABLED.
  @$pb.TagNumber(11)
  $core.bool get experimentalDualRun => $_getBF(10);
  @$pb.TagNumber(11)
  set experimentalDualRun($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasExperimentalDualRun() => $_has(10);
  @$pb.TagNumber(11)
  void clearExperimentalDualRun() => $_clearField(11);

  /// TYLKO DO ODCZYTU, wyliczane po stronie serwera z flagi organizacji
  /// REPORT_EXPERIMENTAL_ENABLED. Aplikacja pokazuje przelacznik
  /// `experimental_dual_run` wylacznie wtedy, gdy to pole jest true.
  ///
  /// Jedzie tym samym wywolaniem zamiast osobnym RPC "jakie mam flagi":
  /// ekran ustawien i tak pobiera preferencje, a dodatkowa runda tylko po
  /// to, zeby ukryc jeden przelacznik, kosztowalaby latencje wejscia w
  /// ustawienia dla wszystkich.
  ///
  /// Ustawienie go przez klienta jest IGNOROWANE — bramka jest po stronie
  /// serwera (clinical-svc sprawdza flage przy kazdym zamowieniu).
  @$pb.TagNumber(12)
  $core.bool get experimentalAvailable => $_getBF(11);
  @$pb.TagNumber(12)
  set experimentalAvailable($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasExperimentalAvailable() => $_has(11);
  @$pb.TagNumber(12)
  void clearExperimentalAvailable() => $_clearField(12);
}

class GetReportPreferencesRequest extends $pb.GeneratedMessage {
  factory GetReportPreferencesRequest({
    $core.String? therapistId,
  }) {
    final result = create();
    if (therapistId != null) result.therapistId = therapistId;
    return result;
  }

  GetReportPreferencesRequest._();

  factory GetReportPreferencesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetReportPreferencesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetReportPreferencesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'therapistId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReportPreferencesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetReportPreferencesRequest copyWith(
          void Function(GetReportPreferencesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetReportPreferencesRequest))
          as GetReportPreferencesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetReportPreferencesRequest create() =>
      GetReportPreferencesRequest._();
  @$core.override
  GetReportPreferencesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetReportPreferencesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetReportPreferencesRequest>(create);
  static GetReportPreferencesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get therapistId => $_getSZ(0);
  @$pb.TagNumber(1)
  set therapistId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTherapistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTherapistId() => $_clearField(1);
}

class UpdateReportPreferencesRequest extends $pb.GeneratedMessage {
  factory UpdateReportPreferencesRequest({
    $core.String? therapistId,
    ReportPreferences? preferences,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (therapistId != null) result.therapistId = therapistId;
    if (preferences != null) result.preferences = preferences;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  UpdateReportPreferencesRequest._();

  factory UpdateReportPreferencesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateReportPreferencesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateReportPreferencesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'therapistId')
    ..aOM<ReportPreferences>(2, _omitFieldNames ? '' : 'preferences',
        subBuilder: ReportPreferences.create)
    ..aOS(3, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateReportPreferencesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateReportPreferencesRequest copyWith(
          void Function(UpdateReportPreferencesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateReportPreferencesRequest))
          as UpdateReportPreferencesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateReportPreferencesRequest create() =>
      UpdateReportPreferencesRequest._();
  @$core.override
  UpdateReportPreferencesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateReportPreferencesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateReportPreferencesRequest>(create);
  static UpdateReportPreferencesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get therapistId => $_getSZ(0);
  @$pb.TagNumber(1)
  set therapistId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTherapistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTherapistId() => $_clearField(1);

  @$pb.TagNumber(2)
  ReportPreferences get preferences => $_getN(1);
  @$pb.TagNumber(2)
  set preferences(ReportPreferences value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPreferences() => $_has(1);
  @$pb.TagNumber(2)
  void clearPreferences() => $_clearField(2);
  @$pb.TagNumber(2)
  ReportPreferences ensurePreferences() => $_ensure(1);

  /// Required: must be a stable client-generated UUID. Same key with
  /// same payload → no-op past the first write. Same key with
  /// different payload → AlreadyExists (idempotency violation).
  @$pb.TagNumber(3)
  $core.String get idempotencyKey => $_getSZ(2);
  @$pb.TagNumber(3)
  set idempotencyKey($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIdempotencyKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearIdempotencyKey() => $_clearField(3);
}

/// Address is the shared shape used by Organization headquarters and
/// User billing addresses. Backed by the `addresses` PG table; the
/// handler creates one row per parent (org / user) and updates it
/// in place on subsequent edits.
class Address extends $pb.GeneratedMessage {
  factory Address({
    $core.String? id,
    $core.String? countryCode,
    $core.String? region,
    $core.String? city,
    $core.String? postalCode,
    $core.String? streetLine,
    $core.String? buildingNumber,
    $core.String? unitNumber,
    $core.String? directions,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (countryCode != null) result.countryCode = countryCode;
    if (region != null) result.region = region;
    if (city != null) result.city = city;
    if (postalCode != null) result.postalCode = postalCode;
    if (streetLine != null) result.streetLine = streetLine;
    if (buildingNumber != null) result.buildingNumber = buildingNumber;
    if (unitNumber != null) result.unitNumber = unitNumber;
    if (directions != null) result.directions = directions;
    return result;
  }

  Address._();

  factory Address.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Address.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Address',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'countryCode')
    ..aOS(3, _omitFieldNames ? '' : 'region')
    ..aOS(4, _omitFieldNames ? '' : 'city')
    ..aOS(5, _omitFieldNames ? '' : 'postalCode')
    ..aOS(6, _omitFieldNames ? '' : 'streetLine')
    ..aOS(7, _omitFieldNames ? '' : 'buildingNumber')
    ..aOS(8, _omitFieldNames ? '' : 'unitNumber')
    ..aOS(9, _omitFieldNames ? '' : 'directions')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Address clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Address copyWith(void Function(Address) updates) =>
      super.copyWith((message) => updates(message as Address)) as Address;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Address create() => Address._();
  @$core.override
  Address createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Address getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Address>(create);
  static Address? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get countryCode => $_getSZ(1);
  @$pb.TagNumber(2)
  set countryCode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCountryCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCountryCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get region => $_getSZ(2);
  @$pb.TagNumber(3)
  set region($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRegion() => $_has(2);
  @$pb.TagNumber(3)
  void clearRegion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get city => $_getSZ(3);
  @$pb.TagNumber(4)
  set city($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCity() => $_has(3);
  @$pb.TagNumber(4)
  void clearCity() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get postalCode => $_getSZ(4);
  @$pb.TagNumber(5)
  set postalCode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPostalCode() => $_has(4);
  @$pb.TagNumber(5)
  void clearPostalCode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get streetLine => $_getSZ(5);
  @$pb.TagNumber(6)
  set streetLine($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStreetLine() => $_has(5);
  @$pb.TagNumber(6)
  void clearStreetLine() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get buildingNumber => $_getSZ(6);
  @$pb.TagNumber(7)
  set buildingNumber($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBuildingNumber() => $_has(6);
  @$pb.TagNumber(7)
  void clearBuildingNumber() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get unitNumber => $_getSZ(7);
  @$pb.TagNumber(8)
  set unitNumber($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUnitNumber() => $_has(7);
  @$pb.TagNumber(8)
  void clearUnitNumber() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get directions => $_getSZ(8);
  @$pb.TagNumber(9)
  set directions($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDirections() => $_has(8);
  @$pb.TagNumber(9)
  void clearDirections() => $_clearField(9);
}

class Organization extends $pb.GeneratedMessage {
  factory Organization({
    $core.String? id,
    $core.String? legalName,
    $core.String? taxId,
    $core.String? vatIdEu,
    OrganizationType? type,
    Address? headquartersAddress,
    $core.String? primaryAdminUserId,
    $2.Timestamp? createdAt,
    $core.bool? isBlocked,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (legalName != null) result.legalName = legalName;
    if (taxId != null) result.taxId = taxId;
    if (vatIdEu != null) result.vatIdEu = vatIdEu;
    if (type != null) result.type = type;
    if (headquartersAddress != null)
      result.headquartersAddress = headquartersAddress;
    if (primaryAdminUserId != null)
      result.primaryAdminUserId = primaryAdminUserId;
    if (createdAt != null) result.createdAt = createdAt;
    if (isBlocked != null) result.isBlocked = isBlocked;
    return result;
  }

  Organization._();

  factory Organization.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Organization.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Organization',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'legalName')
    ..aOS(3, _omitFieldNames ? '' : 'taxId')
    ..aOS(4, _omitFieldNames ? '' : 'vatIdEu')
    ..aE<OrganizationType>(5, _omitFieldNames ? '' : 'type',
        enumValues: OrganizationType.values)
    ..aOM<Address>(6, _omitFieldNames ? '' : 'headquartersAddress',
        subBuilder: Address.create)
    ..aOS(7, _omitFieldNames ? '' : 'primaryAdminUserId')
    ..aOM<$2.Timestamp>(8, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOB(9, _omitFieldNames ? '' : 'isBlocked')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Organization clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Organization copyWith(void Function(Organization) updates) =>
      super.copyWith((message) => updates(message as Organization))
          as Organization;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Organization create() => Organization._();
  @$core.override
  Organization createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Organization getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Organization>(create);
  static Organization? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get legalName => $_getSZ(1);
  @$pb.TagNumber(2)
  set legalName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLegalName() => $_has(1);
  @$pb.TagNumber(2)
  void clearLegalName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get taxId => $_getSZ(2);
  @$pb.TagNumber(3)
  set taxId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTaxId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTaxId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get vatIdEu => $_getSZ(3);
  @$pb.TagNumber(4)
  set vatIdEu($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVatIdEu() => $_has(3);
  @$pb.TagNumber(4)
  void clearVatIdEu() => $_clearField(4);

  @$pb.TagNumber(5)
  OrganizationType get type => $_getN(4);
  @$pb.TagNumber(5)
  set type(OrganizationType value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasType() => $_has(4);
  @$pb.TagNumber(5)
  void clearType() => $_clearField(5);

  @$pb.TagNumber(6)
  Address get headquartersAddress => $_getN(5);
  @$pb.TagNumber(6)
  set headquartersAddress(Address value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasHeadquartersAddress() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeadquartersAddress() => $_clearField(6);
  @$pb.TagNumber(6)
  Address ensureHeadquartersAddress() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.String get primaryAdminUserId => $_getSZ(6);
  @$pb.TagNumber(7)
  set primaryAdminUserId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPrimaryAdminUserId() => $_has(6);
  @$pb.TagNumber(7)
  void clearPrimaryAdminUserId() => $_clearField(7);

  @$pb.TagNumber(8)
  $2.Timestamp get createdAt => $_getN(7);
  @$pb.TagNumber(8)
  set createdAt($2.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => $_clearField(8);
  @$pb.TagNumber(8)
  $2.Timestamp ensureCreatedAt() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.bool get isBlocked => $_getBF(8);
  @$pb.TagNumber(9)
  set isBlocked($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsBlocked() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsBlocked() => $_clearField(9);
}

/// RegisterOrganization payload — clinic founder self-serve.
///
/// The founder becomes role=ORG_ADMIN with no THERAPIST powers
/// (single-role MVP per docs/18 R4). To also record sessions they
/// invite themselves under a different email via the standard
/// invitation flow (§9).
class RegisterOrganizationRequest extends $pb.GeneratedMessage {
  factory RegisterOrganizationRequest({
    $core.String? firebaseUid,
    $core.String? email,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? phoneNumber,
    $core.String? uiLanguage,
    $core.String? timezone,
    $core.bool? hasAcceptedTos,
    $core.bool? hasMarketingConsent,
    $core.String? legalName,
    OrganizationType? type,
    $core.String? taxId,
    $core.String? vatIdEu,
    Address? headquartersAddress,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (firebaseUid != null) result.firebaseUid = firebaseUid;
    if (email != null) result.email = email;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (phoneNumber != null) result.phoneNumber = phoneNumber;
    if (uiLanguage != null) result.uiLanguage = uiLanguage;
    if (timezone != null) result.timezone = timezone;
    if (hasAcceptedTos != null) result.hasAcceptedTos = hasAcceptedTos;
    if (hasMarketingConsent != null)
      result.hasMarketingConsent = hasMarketingConsent;
    if (legalName != null) result.legalName = legalName;
    if (type != null) result.type = type;
    if (taxId != null) result.taxId = taxId;
    if (vatIdEu != null) result.vatIdEu = vatIdEu;
    if (headquartersAddress != null)
      result.headquartersAddress = headquartersAddress;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  RegisterOrganizationRequest._();

  factory RegisterOrganizationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterOrganizationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterOrganizationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'firebaseUid')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOS(3, _omitFieldNames ? '' : 'firstName')
    ..aOS(4, _omitFieldNames ? '' : 'lastName')
    ..aOS(5, _omitFieldNames ? '' : 'phoneNumber')
    ..aOS(6, _omitFieldNames ? '' : 'uiLanguage')
    ..aOS(7, _omitFieldNames ? '' : 'timezone')
    ..aOB(8, _omitFieldNames ? '' : 'hasAcceptedTos')
    ..aOB(9, _omitFieldNames ? '' : 'hasMarketingConsent')
    ..aOS(10, _omitFieldNames ? '' : 'legalName')
    ..aE<OrganizationType>(11, _omitFieldNames ? '' : 'type',
        enumValues: OrganizationType.values)
    ..aOS(12, _omitFieldNames ? '' : 'taxId')
    ..aOS(13, _omitFieldNames ? '' : 'vatIdEu')
    ..aOM<Address>(14, _omitFieldNames ? '' : 'headquartersAddress',
        subBuilder: Address.create)
    ..aOS(15, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterOrganizationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterOrganizationRequest copyWith(
          void Function(RegisterOrganizationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as RegisterOrganizationRequest))
          as RegisterOrganizationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterOrganizationRequest create() =>
      RegisterOrganizationRequest._();
  @$core.override
  RegisterOrganizationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterOrganizationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterOrganizationRequest>(create);
  static RegisterOrganizationRequest? _defaultInstance;

  /// Founder user fields
  @$pb.TagNumber(1)
  $core.String get firebaseUid => $_getSZ(0);
  @$pb.TagNumber(1)
  set firebaseUid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFirebaseUid() => $_has(0);
  @$pb.TagNumber(1)
  void clearFirebaseUid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get firstName => $_getSZ(2);
  @$pb.TagNumber(3)
  set firstName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstName() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get lastName => $_getSZ(3);
  @$pb.TagNumber(4)
  set lastName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastName() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get phoneNumber => $_getSZ(4);
  @$pb.TagNumber(5)
  set phoneNumber($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPhoneNumber() => $_has(4);
  @$pb.TagNumber(5)
  void clearPhoneNumber() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get uiLanguage => $_getSZ(5);
  @$pb.TagNumber(6)
  set uiLanguage($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUiLanguage() => $_has(5);
  @$pb.TagNumber(6)
  void clearUiLanguage() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get timezone => $_getSZ(6);
  @$pb.TagNumber(7)
  set timezone($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTimezone() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimezone() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get hasAcceptedTos => $_getBF(7);
  @$pb.TagNumber(8)
  set hasAcceptedTos($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHasAcceptedTos() => $_has(7);
  @$pb.TagNumber(8)
  void clearHasAcceptedTos() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get hasMarketingConsent => $_getBF(8);
  @$pb.TagNumber(9)
  set hasMarketingConsent($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHasMarketingConsent() => $_has(8);
  @$pb.TagNumber(9)
  void clearHasMarketingConsent() => $_clearField(9);

  /// Organization fields
  @$pb.TagNumber(10)
  $core.String get legalName => $_getSZ(9);
  @$pb.TagNumber(10)
  set legalName($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLegalName() => $_has(9);
  @$pb.TagNumber(10)
  void clearLegalName() => $_clearField(10);

  @$pb.TagNumber(11)
  OrganizationType get type => $_getN(10);
  @$pb.TagNumber(11)
  set type(OrganizationType value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasType() => $_has(10);
  @$pb.TagNumber(11)
  void clearType() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get taxId => $_getSZ(11);
  @$pb.TagNumber(12)
  set taxId($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasTaxId() => $_has(11);
  @$pb.TagNumber(12)
  void clearTaxId() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get vatIdEu => $_getSZ(12);
  @$pb.TagNumber(13)
  set vatIdEu($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasVatIdEu() => $_has(12);
  @$pb.TagNumber(13)
  void clearVatIdEu() => $_clearField(13);

  @$pb.TagNumber(14)
  Address get headquartersAddress => $_getN(13);
  @$pb.TagNumber(14)
  set headquartersAddress(Address value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasHeadquartersAddress() => $_has(13);
  @$pb.TagNumber(14)
  void clearHeadquartersAddress() => $_clearField(14);
  @$pb.TagNumber(14)
  Address ensureHeadquartersAddress() => $_ensure(13);

  /// Idempotency: same key with same payload → returns existing org.
  @$pb.TagNumber(15)
  $core.String get idempotencyKey => $_getSZ(14);
  @$pb.TagNumber(15)
  set idempotencyKey($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasIdempotencyKey() => $_has(14);
  @$pb.TagNumber(15)
  void clearIdempotencyKey() => $_clearField(15);
}

class RegisterOrganizationResponse extends $pb.GeneratedMessage {
  factory RegisterOrganizationResponse({
    User? user,
    Organization? organization,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (organization != null) result.organization = organization;
    return result;
  }

  RegisterOrganizationResponse._();

  factory RegisterOrganizationResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterOrganizationResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterOrganizationResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOM<User>(1, _omitFieldNames ? '' : 'user', subBuilder: User.create)
    ..aOM<Organization>(2, _omitFieldNames ? '' : 'organization',
        subBuilder: Organization.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterOrganizationResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterOrganizationResponse copyWith(
          void Function(RegisterOrganizationResponse) updates) =>
      super.copyWith(
              (message) => updates(message as RegisterOrganizationResponse))
          as RegisterOrganizationResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterOrganizationResponse create() =>
      RegisterOrganizationResponse._();
  @$core.override
  RegisterOrganizationResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterOrganizationResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterOrganizationResponse>(create);
  static RegisterOrganizationResponse? _defaultInstance;

  @$pb.TagNumber(1)
  User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  User ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  Organization get organization => $_getN(1);
  @$pb.TagNumber(2)
  set organization(Organization value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOrganization() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrganization() => $_clearField(2);
  @$pb.TagNumber(2)
  Organization ensureOrganization() => $_ensure(1);
}

class UpdateMyOrganizationRequest extends $pb.GeneratedMessage {
  factory UpdateMyOrganizationRequest({
    $core.String? legalName,
    OrganizationType? type,
    $core.String? taxId,
    $core.String? vatIdEu,
    Address? headquartersAddress,
    $core.String? primaryAdminUserId,
  }) {
    final result = create();
    if (legalName != null) result.legalName = legalName;
    if (type != null) result.type = type;
    if (taxId != null) result.taxId = taxId;
    if (vatIdEu != null) result.vatIdEu = vatIdEu;
    if (headquartersAddress != null)
      result.headquartersAddress = headquartersAddress;
    if (primaryAdminUserId != null)
      result.primaryAdminUserId = primaryAdminUserId;
    return result;
  }

  UpdateMyOrganizationRequest._();

  factory UpdateMyOrganizationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateMyOrganizationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateMyOrganizationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'legalName')
    ..aE<OrganizationType>(2, _omitFieldNames ? '' : 'type',
        enumValues: OrganizationType.values)
    ..aOS(3, _omitFieldNames ? '' : 'taxId')
    ..aOS(4, _omitFieldNames ? '' : 'vatIdEu')
    ..aOM<Address>(5, _omitFieldNames ? '' : 'headquartersAddress',
        subBuilder: Address.create)
    ..aOS(6, _omitFieldNames ? '' : 'primaryAdminUserId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMyOrganizationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMyOrganizationRequest copyWith(
          void Function(UpdateMyOrganizationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateMyOrganizationRequest))
          as UpdateMyOrganizationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateMyOrganizationRequest create() =>
      UpdateMyOrganizationRequest._();
  @$core.override
  UpdateMyOrganizationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateMyOrganizationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateMyOrganizationRequest>(create);
  static UpdateMyOrganizationRequest? _defaultInstance;

  /// org_id resolved from caller's auth context — not in the wire
  /// payload (org-admin can only edit their own org).
  @$pb.TagNumber(1)
  $core.String get legalName => $_getSZ(0);
  @$pb.TagNumber(1)
  set legalName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLegalName() => $_has(0);
  @$pb.TagNumber(1)
  void clearLegalName() => $_clearField(1);

  @$pb.TagNumber(2)
  OrganizationType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(OrganizationType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get taxId => $_getSZ(2);
  @$pb.TagNumber(3)
  set taxId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTaxId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTaxId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get vatIdEu => $_getSZ(3);
  @$pb.TagNumber(4)
  set vatIdEu($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVatIdEu() => $_has(3);
  @$pb.TagNumber(4)
  void clearVatIdEu() => $_clearField(4);

  @$pb.TagNumber(5)
  Address get headquartersAddress => $_getN(4);
  @$pb.TagNumber(5)
  set headquartersAddress(Address value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasHeadquartersAddress() => $_has(4);
  @$pb.TagNumber(5)
  void clearHeadquartersAddress() => $_clearField(5);
  @$pb.TagNumber(5)
  Address ensureHeadquartersAddress() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get primaryAdminUserId => $_getSZ(5);
  @$pb.TagNumber(6)
  set primaryAdminUserId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPrimaryAdminUserId() => $_has(5);
  @$pb.TagNumber(6)
  void clearPrimaryAdminUserId() => $_clearField(6);
}

class Invitation extends $pb.GeneratedMessage {
  factory Invitation({
    $core.String? id,
    $core.String? organizationId,
    $core.String? invitedByUser,
    $core.String? email,
    $2.Timestamp? expiresAt,
    $2.Timestamp? acceptedAt,
    $2.Timestamp? createdAt,
    UserRole? invitedRole,
    $core.String? allocationId,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? pairingCode,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (organizationId != null) result.organizationId = organizationId;
    if (invitedByUser != null) result.invitedByUser = invitedByUser;
    if (email != null) result.email = email;
    if (expiresAt != null) result.expiresAt = expiresAt;
    if (acceptedAt != null) result.acceptedAt = acceptedAt;
    if (createdAt != null) result.createdAt = createdAt;
    if (invitedRole != null) result.invitedRole = invitedRole;
    if (allocationId != null) result.allocationId = allocationId;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (pairingCode != null) result.pairingCode = pairingCode;
    return result;
  }

  Invitation._();

  factory Invitation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Invitation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Invitation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'organizationId')
    ..aOS(3, _omitFieldNames ? '' : 'invitedByUser')
    ..aOS(4, _omitFieldNames ? '' : 'email')
    ..aOM<$2.Timestamp>(5, _omitFieldNames ? '' : 'expiresAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'acceptedAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(7, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aE<UserRole>(8, _omitFieldNames ? '' : 'invitedRole',
        enumValues: UserRole.values)
    ..aOS(9, _omitFieldNames ? '' : 'allocationId')
    ..aOS(10, _omitFieldNames ? '' : 'firstName')
    ..aOS(11, _omitFieldNames ? '' : 'lastName')
    ..aOS(12, _omitFieldNames ? '' : 'pairingCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Invitation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Invitation copyWith(void Function(Invitation) updates) =>
      super.copyWith((message) => updates(message as Invitation)) as Invitation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Invitation create() => Invitation._();
  @$core.override
  Invitation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Invitation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Invitation>(create);
  static Invitation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get organizationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set organizationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOrganizationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrganizationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get invitedByUser => $_getSZ(2);
  @$pb.TagNumber(3)
  set invitedByUser($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInvitedByUser() => $_has(2);
  @$pb.TagNumber(3)
  void clearInvitedByUser() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get email => $_getSZ(3);
  @$pb.TagNumber(4)
  set email($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEmail() => $_has(3);
  @$pb.TagNumber(4)
  void clearEmail() => $_clearField(4);

  @$pb.TagNumber(5)
  $2.Timestamp get expiresAt => $_getN(4);
  @$pb.TagNumber(5)
  set expiresAt($2.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasExpiresAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearExpiresAt() => $_clearField(5);
  @$pb.TagNumber(5)
  $2.Timestamp ensureExpiresAt() => $_ensure(4);

  @$pb.TagNumber(6)
  $2.Timestamp get acceptedAt => $_getN(5);
  @$pb.TagNumber(6)
  set acceptedAt($2.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasAcceptedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearAcceptedAt() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensureAcceptedAt() => $_ensure(5);

  @$pb.TagNumber(7)
  $2.Timestamp get createdAt => $_getN(6);
  @$pb.TagNumber(7)
  set createdAt($2.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $2.Timestamp ensureCreatedAt() => $_ensure(6);

  /// Role the acceptor will be created with (docs/38): THERAPIST for
  /// team invites, ORG_ADMIN for manager invites minted by
  /// AdminCreateOrganization. Never SUPERWIZOR_ADMIN.
  @$pb.TagNumber(8)
  UserRole get invitedRole => $_getN(7);
  @$pb.TagNumber(8)
  set invitedRole(UserRole value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasInvitedRole() => $_has(7);
  @$pb.TagNumber(8)
  void clearInvitedRole() => $_clearField(8);

  /// Seat allocation the invite is pinned to (THERAPIST only). A
  /// pending invitation reserves one seat until accepted or expired.
  @$pb.TagNumber(9)
  $core.String get allocationId => $_getSZ(8);
  @$pb.TagNumber(9)
  set allocationId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAllocationId() => $_has(8);
  @$pb.TagNumber(9)
  void clearAllocationId() => $_clearField(9);

  /// Name the inviter typed — shown in the pending-invitations list
  /// and prefilled on the accept page (acceptor's input wins).
  @$pb.TagNumber(10)
  $core.String get firstName => $_getSZ(9);
  @$pb.TagNumber(10)
  set firstName($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasFirstName() => $_has(9);
  @$pb.TagNumber(10)
  void clearFirstName() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get lastName => $_getSZ(10);
  @$pb.TagNumber(11)
  set lastName($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasLastName() => $_has(10);
  @$pb.TagNumber(11)
  void clearLastName() => $_clearField(11);

  /// docs/42: 6-digit pairing code for PATIENT invites. Populated
  /// EXCLUSIVELY in the InviteClient response (shown once to the
  /// therapist, who hands it to the patient outside e-mail); every
  /// other read returns empty — only the hash is stored.
  @$pb.TagNumber(12)
  $core.String get pairingCode => $_getSZ(11);
  @$pb.TagNumber(12)
  set pairingCode($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasPairingCode() => $_has(11);
  @$pb.TagNumber(12)
  void clearPairingCode() => $_clearField(12);
}

class InviteTherapistRequest extends $pb.GeneratedMessage {
  factory InviteTherapistRequest({
    $core.String? email,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? defaultModalityId,
    $core.String? idempotencyKey,
    $core.String? allocationId,
  }) {
    final result = create();
    if (email != null) result.email = email;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (defaultModalityId != null) result.defaultModalityId = defaultModalityId;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (allocationId != null) result.allocationId = allocationId;
    return result;
  }

  InviteTherapistRequest._();

  factory InviteTherapistRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InviteTherapistRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InviteTherapistRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..aOS(2, _omitFieldNames ? '' : 'firstName')
    ..aOS(3, _omitFieldNames ? '' : 'lastName')
    ..aOS(4, _omitFieldNames ? '' : 'defaultModalityId')
    ..aOS(5, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOS(6, _omitFieldNames ? '' : 'allocationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InviteTherapistRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InviteTherapistRequest copyWith(
          void Function(InviteTherapistRequest) updates) =>
      super.copyWith((message) => updates(message as InviteTherapistRequest))
          as InviteTherapistRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InviteTherapistRequest create() => InviteTherapistRequest._();
  @$core.override
  InviteTherapistRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InviteTherapistRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InviteTherapistRequest>(create);
  static InviteTherapistRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);

  /// Suggested fields pre-populate the accept-invite page; invitee
  /// can edit any of them. Optional.
  @$pb.TagNumber(2)
  $core.String get firstName => $_getSZ(1);
  @$pb.TagNumber(2)
  set firstName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirstName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirstName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get lastName => $_getSZ(2);
  @$pb.TagNumber(3)
  set lastName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastName() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get defaultModalityId => $_getSZ(3);
  @$pb.TagNumber(4)
  set defaultModalityId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDefaultModalityId() => $_has(3);
  @$pb.TagNumber(4)
  void clearDefaultModalityId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get idempotencyKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set idempotencyKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIdempotencyKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearIdempotencyKey() => $_clearField(5);

  /// Seat allocation (org × plan) this therapist occupies (docs/38).
  /// Optional for orgs without allocations (legacy/self-serve). When
  /// set, free-seat validation applies: FAILED_PRECONDITION
  /// "SEATS_EXHAUSTED" when active seats + pending invites >= seats.
  @$pb.TagNumber(6)
  $core.String get allocationId => $_getSZ(5);
  @$pb.TagNumber(6)
  set allocationId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAllocationId() => $_has(5);
  @$pb.TagNumber(6)
  void clearAllocationId() => $_clearField(6);
}

class InviteClientRequest extends $pb.GeneratedMessage {
  factory InviteClientRequest({
    $core.String? patientFileId,
    $core.String? email,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (email != null) result.email = email;
    return result;
  }

  InviteClientRequest._();

  factory InviteClientRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InviteClientRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InviteClientRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InviteClientRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InviteClientRequest copyWith(void Function(InviteClientRequest) updates) =>
      super.copyWith((message) => updates(message as InviteClientRequest))
          as InviteClientRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InviteClientRequest create() => InviteClientRequest._();
  @$core.override
  InviteClientRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InviteClientRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InviteClientRequest>(create);
  static InviteClientRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);

  /// Optional override; when empty the kartoteka's patient_email is
  /// used (FailedPrecondition if neither exists). A provided value is
  /// persisted back onto patient_files.patient_email.
  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);
}

class GetClientInviteStatusRequest extends $pb.GeneratedMessage {
  factory GetClientInviteStatusRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  GetClientInviteStatusRequest._();

  factory GetClientInviteStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetClientInviteStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetClientInviteStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetClientInviteStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetClientInviteStatusRequest copyWith(
          void Function(GetClientInviteStatusRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetClientInviteStatusRequest))
          as GetClientInviteStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetClientInviteStatusRequest create() =>
      GetClientInviteStatusRequest._();
  @$core.override
  GetClientInviteStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetClientInviteStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetClientInviteStatusRequest>(create);
  static GetClientInviteStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

class RevokeClientInviteRequest extends $pb.GeneratedMessage {
  factory RevokeClientInviteRequest({
    $core.String? patientFileId,
  }) {
    final result = create();
    if (patientFileId != null) result.patientFileId = patientFileId;
    return result;
  }

  RevokeClientInviteRequest._();

  factory RevokeClientInviteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RevokeClientInviteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevokeClientInviteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'patientFileId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeClientInviteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeClientInviteRequest copyWith(
          void Function(RevokeClientInviteRequest) updates) =>
      super.copyWith((message) => updates(message as RevokeClientInviteRequest))
          as RevokeClientInviteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RevokeClientInviteRequest create() => RevokeClientInviteRequest._();
  @$core.override
  RevokeClientInviteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RevokeClientInviteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevokeClientInviteRequest>(create);
  static RevokeClientInviteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get patientFileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set patientFileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPatientFileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPatientFileId() => $_clearField(1);
}

class ClientInviteStatus extends $pb.GeneratedMessage {
  factory ClientInviteStatus({
    $core.String? status,
    $core.String? email,
    $2.Timestamp? expiresAt,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (email != null) result.email = email;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  ClientInviteStatus._();

  factory ClientInviteStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientInviteStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientInviteStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'status')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOM<$2.Timestamp>(3, _omitFieldNames ? '' : 'expiresAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientInviteStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientInviteStatus copyWith(void Function(ClientInviteStatus) updates) =>
      super.copyWith((message) => updates(message as ClientInviteStatus))
          as ClientInviteStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientInviteStatus create() => ClientInviteStatus._();
  @$core.override
  ClientInviteStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientInviteStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientInviteStatus>(create);
  static ClientInviteStatus? _defaultInstance;

  /// NONE — never invited; PENDING — invitation outstanding;
  /// ACTIVE — client activated (firebase_uid attached, is_active);
  /// INACTIVE — activated but deactivated (users.is_active=false).
  @$pb.TagNumber(1)
  $core.String get status => $_getSZ(0);
  @$pb.TagNumber(1)
  set status($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $2.Timestamp get expiresAt => $_getN(2);
  @$pb.TagNumber(3)
  set expiresAt($2.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasExpiresAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearExpiresAt() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.Timestamp ensureExpiresAt() => $_ensure(2);
}

/// Menedżer organizacji, który sam prowadzi terapię.
///
/// Rola NIE ulega zmianie — konto zostaje ORG_ADMIN i zachowuje wszystkie
/// uprawnienia menedżerskie. Prawem do praktykowania jest MIEJSCE w planie:
/// to na jego podstawie powstaje licznik zużycia (GetSeatPlanForTherapist
/// w billing-svc nie patrzy na rolę), a aplikacja i tak kieruje na
/// powierzchnię terapeuty każdego, kto nie jest pacjentem.
///
/// Dostępu do danych to nie poszerza: ORG_ADMIN ma już wgląd w kartoteki
/// swojej organizacji w ramach nadzoru klinicznego (docs/38).
class SetManagerTherapistSeatRequest extends $pb.GeneratedMessage {
  factory SetManagerTherapistSeatRequest({
    $core.String? userId,
    $core.bool? practicing,
    $core.String? allocationId,
    $core.String? reason,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (practicing != null) result.practicing = practicing;
    if (allocationId != null) result.allocationId = allocationId;
    if (reason != null) result.reason = reason;
    return result;
  }

  SetManagerTherapistSeatRequest._();

  factory SetManagerTherapistSeatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetManagerTherapistSeatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetManagerTherapistSeatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOB(2, _omitFieldNames ? '' : 'practicing')
    ..aOS(3, _omitFieldNames ? '' : 'allocationId')
    ..aOS(4, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetManagerTherapistSeatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetManagerTherapistSeatRequest copyWith(
          void Function(SetManagerTherapistSeatRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SetManagerTherapistSeatRequest))
          as SetManagerTherapistSeatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetManagerTherapistSeatRequest create() =>
      SetManagerTherapistSeatRequest._();
  @$core.override
  SetManagerTherapistSeatRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetManagerTherapistSeatRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetManagerTherapistSeatRequest>(create);
  static SetManagerTherapistSeatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get practicing => $_getBF(1);
  @$pb.TagNumber(2)
  set practicing($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPracticing() => $_has(1);
  @$pb.TagNumber(2)
  void clearPracticing() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get allocationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set allocationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAllocationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAllocationId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get reason => $_getSZ(3);
  @$pb.TagNumber(4)
  set reason($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReason() => $_has(3);
  @$pb.TagNumber(4)
  void clearReason() => $_clearField(4);
}

class SetTherapistStatusRequest extends $pb.GeneratedMessage {
  factory SetTherapistStatusRequest({
    $core.String? userId,
    $core.bool? isActive,
    $core.String? reason,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (isActive != null) result.isActive = isActive;
    if (reason != null) result.reason = reason;
    return result;
  }

  SetTherapistStatusRequest._();

  factory SetTherapistStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetTherapistStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetTherapistStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOB(2, _omitFieldNames ? '' : 'isActive')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTherapistStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTherapistStatusRequest copyWith(
          void Function(SetTherapistStatusRequest) updates) =>
      super.copyWith((message) => updates(message as SetTherapistStatusRequest))
          as SetTherapistStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetTherapistStatusRequest create() => SetTherapistStatusRequest._();
  @$core.override
  SetTherapistStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetTherapistStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetTherapistStatusRequest>(create);
  static SetTherapistStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isActive => $_getBF(1);
  @$pb.TagNumber(2)
  set isActive($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsActive() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsActive() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);
}

class AcceptInvitationRequest extends $pb.GeneratedMessage {
  factory AcceptInvitationRequest({
    $core.String? token,
    $core.String? firebaseUid,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? defaultModalityId,
    $core.String? uiLanguage,
    $core.String? timezone,
    $core.bool? hasAcceptedTos,
    $core.bool? hasMarketingConsent,
    $core.String? pairingCode,
    $core.String? phoneNumber,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (firebaseUid != null) result.firebaseUid = firebaseUid;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (defaultModalityId != null) result.defaultModalityId = defaultModalityId;
    if (uiLanguage != null) result.uiLanguage = uiLanguage;
    if (timezone != null) result.timezone = timezone;
    if (hasAcceptedTos != null) result.hasAcceptedTos = hasAcceptedTos;
    if (hasMarketingConsent != null)
      result.hasMarketingConsent = hasMarketingConsent;
    if (pairingCode != null) result.pairingCode = pairingCode;
    if (phoneNumber != null) result.phoneNumber = phoneNumber;
    return result;
  }

  AcceptInvitationRequest._();

  factory AcceptInvitationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AcceptInvitationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AcceptInvitationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOS(2, _omitFieldNames ? '' : 'firebaseUid')
    ..aOS(3, _omitFieldNames ? '' : 'firstName')
    ..aOS(4, _omitFieldNames ? '' : 'lastName')
    ..aOS(5, _omitFieldNames ? '' : 'defaultModalityId')
    ..aOS(6, _omitFieldNames ? '' : 'uiLanguage')
    ..aOS(7, _omitFieldNames ? '' : 'timezone')
    ..aOB(8, _omitFieldNames ? '' : 'hasAcceptedTos')
    ..aOB(9, _omitFieldNames ? '' : 'hasMarketingConsent')
    ..aOS(10, _omitFieldNames ? '' : 'pairingCode')
    ..aOS(11, _omitFieldNames ? '' : 'phoneNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcceptInvitationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcceptInvitationRequest copyWith(
          void Function(AcceptInvitationRequest) updates) =>
      super.copyWith((message) => updates(message as AcceptInvitationRequest))
          as AcceptInvitationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AcceptInvitationRequest create() => AcceptInvitationRequest._();
  @$core.override
  AcceptInvitationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AcceptInvitationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AcceptInvitationRequest>(create);
  static AcceptInvitationRequest? _defaultInstance;

  /// The url-safe-base64 token from the email link (NOT hashed —
  /// the handler SHA-256s the incoming value before looking up in
  /// invitations.token_hash).
  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  /// Firebase UID of the just-created Firebase Auth account. The
  /// client calls createUserWithEmailAndPassword first, then sends
  /// this RPC to attach the new account to the inviting org.
  @$pb.TagNumber(2)
  $core.String get firebaseUid => $_getSZ(1);
  @$pb.TagNumber(2)
  set firebaseUid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirebaseUid() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirebaseUid() => $_clearField(2);

  /// For PATIENT invitations these are IGNORED (docs/43 §4: the client
  /// account is pseudonymous — its only direct identifier is the
  /// e-mail). Therapist/manager invitations still use them.
  @$pb.TagNumber(3)
  $core.String get firstName => $_getSZ(2);
  @$pb.TagNumber(3)
  set firstName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstName() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get lastName => $_getSZ(3);
  @$pb.TagNumber(4)
  set lastName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastName() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get defaultModalityId => $_getSZ(4);
  @$pb.TagNumber(5)
  set defaultModalityId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDefaultModalityId() => $_has(4);
  @$pb.TagNumber(5)
  void clearDefaultModalityId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get uiLanguage => $_getSZ(5);
  @$pb.TagNumber(6)
  set uiLanguage($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUiLanguage() => $_has(5);
  @$pb.TagNumber(6)
  void clearUiLanguage() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get timezone => $_getSZ(6);
  @$pb.TagNumber(7)
  set timezone($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTimezone() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimezone() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get hasAcceptedTos => $_getBF(7);
  @$pb.TagNumber(8)
  set hasAcceptedTos($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHasAcceptedTos() => $_has(7);
  @$pb.TagNumber(8)
  void clearHasAcceptedTos() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get hasMarketingConsent => $_getBF(8);
  @$pb.TagNumber(9)
  set hasMarketingConsent($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHasMarketingConsent() => $_has(8);
  @$pb.TagNumber(9)
  void clearHasMarketingConsent() => $_clearField(9);

  /// docs/42: required iff the invitation carries a pairing code
  /// (InvitationPreview.requires_pairing_code). 6 digits; spaces
  /// tolerated. 5 wrong attempts block the invitation.
  @$pb.TagNumber(10)
  $core.String get pairingCode => $_getSZ(9);
  @$pb.TagNumber(10)
  set pairingCode($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPairingCode() => $_has(9);
  @$pb.TagNumber(10)
  void clearPairingCode() => $_clearField(10);

  /// Wymagany dla zaproszeń THERAPIST i ORG_ADMIN, IGNOROWANY dla
  /// PATIENT (docs/43 §4 — konto klienta jest pseudonimowe i e-mail jest
  /// jego jedynym identyfikatorem). Ścieżka samodzielnej rejestracji
  /// terapeuty wymaga numeru „ze względów bezpieczeństwa", więc
  /// akceptacja zaproszenia nie może być furtką pozwalającą założyć
  /// konto personelu bez niego.
  @$pb.TagNumber(11)
  $core.String get phoneNumber => $_getSZ(10);
  @$pb.TagNumber(11)
  set phoneNumber($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPhoneNumber() => $_has(10);
  @$pb.TagNumber(11)
  void clearPhoneNumber() => $_clearField(11);
}

class GetInvitationPreviewRequest extends $pb.GeneratedMessage {
  factory GetInvitationPreviewRequest({
    $core.String? token,
  }) {
    final result = create();
    if (token != null) result.token = token;
    return result;
  }

  GetInvitationPreviewRequest._();

  factory GetInvitationPreviewRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetInvitationPreviewRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetInvitationPreviewRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetInvitationPreviewRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetInvitationPreviewRequest copyWith(
          void Function(GetInvitationPreviewRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetInvitationPreviewRequest))
          as GetInvitationPreviewRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetInvitationPreviewRequest create() =>
      GetInvitationPreviewRequest._();
  @$core.override
  GetInvitationPreviewRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetInvitationPreviewRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetInvitationPreviewRequest>(create);
  static GetInvitationPreviewRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);
}

class InvitationPreview extends $pb.GeneratedMessage {
  factory InvitationPreview({
    UserRole? invitedRole,
    $core.String? email,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? organizationName,
    $core.String? inviterFirstName,
    $core.bool? requiresPairingCode,
  }) {
    final result = create();
    if (invitedRole != null) result.invitedRole = invitedRole;
    if (email != null) result.email = email;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (organizationName != null) result.organizationName = organizationName;
    if (inviterFirstName != null) result.inviterFirstName = inviterFirstName;
    if (requiresPairingCode != null)
      result.requiresPairingCode = requiresPairingCode;
    return result;
  }

  InvitationPreview._();

  factory InvitationPreview.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InvitationPreview.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InvitationPreview',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aE<UserRole>(1, _omitFieldNames ? '' : 'invitedRole',
        enumValues: UserRole.values)
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOS(3, _omitFieldNames ? '' : 'firstName')
    ..aOS(4, _omitFieldNames ? '' : 'lastName')
    ..aOS(5, _omitFieldNames ? '' : 'organizationName')
    ..aOS(6, _omitFieldNames ? '' : 'inviterFirstName')
    ..aOB(7, _omitFieldNames ? '' : 'requiresPairingCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InvitationPreview clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InvitationPreview copyWith(void Function(InvitationPreview) updates) =>
      super.copyWith((message) => updates(message as InvitationPreview))
          as InvitationPreview;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InvitationPreview create() => InvitationPreview._();
  @$core.override
  InvitationPreview createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InvitationPreview getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InvitationPreview>(create);
  static InvitationPreview? _defaultInstance;

  @$pb.TagNumber(1)
  UserRole get invitedRole => $_getN(0);
  @$pb.TagNumber(1)
  set invitedRole(UserRole value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasInvitedRole() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvitedRole() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get firstName => $_getSZ(2);
  @$pb.TagNumber(3)
  set firstName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstName() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get lastName => $_getSZ(3);
  @$pb.TagNumber(4)
  set lastName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastName() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get organizationName => $_getSZ(4);
  @$pb.TagNumber(5)
  set organizationName($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOrganizationName() => $_has(4);
  @$pb.TagNumber(5)
  void clearOrganizationName() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get inviterFirstName => $_getSZ(5);
  @$pb.TagNumber(6)
  set inviterFirstName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInviterFirstName() => $_has(5);
  @$pb.TagNumber(6)
  void clearInviterFirstName() => $_clearField(6);

  /// docs/42: the accept form must show the pairing-code field.
  @$pb.TagNumber(7)
  $core.bool get requiresPairingCode => $_getBF(6);
  @$pb.TagNumber(7)
  set requiresPairingCode($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRequiresPairingCode() => $_has(6);
  @$pb.TagNumber(7)
  void clearRequiresPairingCode() => $_clearField(7);
}

class AcceptInvitationResponse extends $pb.GeneratedMessage {
  factory AcceptInvitationResponse({
    User? user,
    Organization? organization,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (organization != null) result.organization = organization;
    return result;
  }

  AcceptInvitationResponse._();

  factory AcceptInvitationResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AcceptInvitationResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AcceptInvitationResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOM<User>(1, _omitFieldNames ? '' : 'user', subBuilder: User.create)
    ..aOM<Organization>(2, _omitFieldNames ? '' : 'organization',
        subBuilder: Organization.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcceptInvitationResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcceptInvitationResponse copyWith(
          void Function(AcceptInvitationResponse) updates) =>
      super.copyWith((message) => updates(message as AcceptInvitationResponse))
          as AcceptInvitationResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AcceptInvitationResponse create() => AcceptInvitationResponse._();
  @$core.override
  AcceptInvitationResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AcceptInvitationResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AcceptInvitationResponse>(create);
  static AcceptInvitationResponse? _defaultInstance;

  @$pb.TagNumber(1)
  User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  User ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  Organization get organization => $_getN(1);
  @$pb.TagNumber(2)
  set organization(Organization value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOrganization() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrganization() => $_clearField(2);
  @$pb.TagNumber(2)
  Organization ensureOrganization() => $_ensure(1);
}

class TherapistEntry extends $pb.GeneratedMessage {
  factory TherapistEntry({
    User? user,
    Invitation? pendingInvitation,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (pendingInvitation != null) result.pendingInvitation = pendingInvitation;
    return result;
  }

  TherapistEntry._();

  factory TherapistEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TherapistEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TherapistEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOM<User>(1, _omitFieldNames ? '' : 'user', subBuilder: User.create)
    ..aOM<Invitation>(2, _omitFieldNames ? '' : 'pendingInvitation',
        subBuilder: Invitation.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TherapistEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TherapistEntry copyWith(void Function(TherapistEntry) updates) =>
      super.copyWith((message) => updates(message as TherapistEntry))
          as TherapistEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TherapistEntry create() => TherapistEntry._();
  @$core.override
  TherapistEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TherapistEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TherapistEntry>(create);
  static TherapistEntry? _defaultInstance;

  /// For an active (accepted) therapist, populated user is set and
  /// pending_invitation is empty. For a pending invitation, the
  /// reverse — `user` is empty.
  @$pb.TagNumber(1)
  User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  User ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  Invitation get pendingInvitation => $_getN(1);
  @$pb.TagNumber(2)
  set pendingInvitation(Invitation value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPendingInvitation() => $_has(1);
  @$pb.TagNumber(2)
  void clearPendingInvitation() => $_clearField(2);
  @$pb.TagNumber(2)
  Invitation ensurePendingInvitation() => $_ensure(1);
}

class ListTherapistsResponse extends $pb.GeneratedMessage {
  factory ListTherapistsResponse({
    $core.Iterable<TherapistEntry>? therapists,
  }) {
    final result = create();
    if (therapists != null) result.therapists.addAll(therapists);
    return result;
  }

  ListTherapistsResponse._();

  factory ListTherapistsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListTherapistsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTherapistsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..pPM<TherapistEntry>(1, _omitFieldNames ? '' : 'therapists',
        subBuilder: TherapistEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTherapistsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTherapistsResponse copyWith(
          void Function(ListTherapistsResponse) updates) =>
      super.copyWith((message) => updates(message as ListTherapistsResponse))
          as ListTherapistsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTherapistsResponse create() => ListTherapistsResponse._();
  @$core.override
  ListTherapistsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListTherapistsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTherapistsResponse>(create);
  static ListTherapistsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TherapistEntry> get therapists => $_getList(0);
}

class RemoveTherapistRequest extends $pb.GeneratedMessage {
  factory RemoveTherapistRequest({
    $core.String? userId,
    $core.String? reason,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (reason != null) result.reason = reason;
    return result;
  }

  RemoveTherapistRequest._();

  factory RemoveTherapistRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveTherapistRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveTherapistRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveTherapistRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveTherapistRequest copyWith(
          void Function(RemoveTherapistRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveTherapistRequest))
          as RemoveTherapistRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveTherapistRequest create() => RemoveTherapistRequest._();
  @$core.override
  RemoveTherapistRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveTherapistRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveTherapistRequest>(create);
  static RemoveTherapistRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

/// ── Manager (ORG_ADMIN) self-management — docs/38 PR14 ──
class ManagerEntry extends $pb.GeneratedMessage {
  factory ManagerEntry({
    User? user,
    Invitation? pendingInvitation,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (pendingInvitation != null) result.pendingInvitation = pendingInvitation;
    return result;
  }

  ManagerEntry._();

  factory ManagerEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ManagerEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ManagerEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOM<User>(1, _omitFieldNames ? '' : 'user', subBuilder: User.create)
    ..aOM<Invitation>(2, _omitFieldNames ? '' : 'pendingInvitation',
        subBuilder: Invitation.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ManagerEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ManagerEntry copyWith(void Function(ManagerEntry) updates) =>
      super.copyWith((message) => updates(message as ManagerEntry))
          as ManagerEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ManagerEntry create() => ManagerEntry._();
  @$core.override
  ManagerEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ManagerEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ManagerEntry>(create);
  static ManagerEntry? _defaultInstance;

  /// Same shape as TherapistEntry: an active manager sets `user`; a
  /// pending ORG_ADMIN invitation sets `pending_invitation`.
  @$pb.TagNumber(1)
  User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  User ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  Invitation get pendingInvitation => $_getN(1);
  @$pb.TagNumber(2)
  set pendingInvitation(Invitation value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPendingInvitation() => $_has(1);
  @$pb.TagNumber(2)
  void clearPendingInvitation() => $_clearField(2);
  @$pb.TagNumber(2)
  Invitation ensurePendingInvitation() => $_ensure(1);
}

class ListManagersResponse extends $pb.GeneratedMessage {
  factory ListManagersResponse({
    $core.Iterable<ManagerEntry>? managers,
  }) {
    final result = create();
    if (managers != null) result.managers.addAll(managers);
    return result;
  }

  ListManagersResponse._();

  factory ListManagersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListManagersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListManagersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..pPM<ManagerEntry>(1, _omitFieldNames ? '' : 'managers',
        subBuilder: ManagerEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListManagersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListManagersResponse copyWith(void Function(ListManagersResponse) updates) =>
      super.copyWith((message) => updates(message as ListManagersResponse))
          as ListManagersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListManagersResponse create() => ListManagersResponse._();
  @$core.override
  ListManagersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListManagersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListManagersResponse>(create);
  static ListManagersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ManagerEntry> get managers => $_getList(0);
}

class InviteMyOrgManagerRequest extends $pb.GeneratedMessage {
  factory InviteMyOrgManagerRequest({
    $core.String? email,
    $core.String? firstName,
    $core.String? lastName,
  }) {
    final result = create();
    if (email != null) result.email = email;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    return result;
  }

  InviteMyOrgManagerRequest._();

  factory InviteMyOrgManagerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InviteMyOrgManagerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InviteMyOrgManagerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..aOS(2, _omitFieldNames ? '' : 'firstName')
    ..aOS(3, _omitFieldNames ? '' : 'lastName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InviteMyOrgManagerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InviteMyOrgManagerRequest copyWith(
          void Function(InviteMyOrgManagerRequest) updates) =>
      super.copyWith((message) => updates(message as InviteMyOrgManagerRequest))
          as InviteMyOrgManagerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InviteMyOrgManagerRequest create() => InviteMyOrgManagerRequest._();
  @$core.override
  InviteMyOrgManagerRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InviteMyOrgManagerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InviteMyOrgManagerRequest>(create);
  static InviteMyOrgManagerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get firstName => $_getSZ(1);
  @$pb.TagNumber(2)
  set firstName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirstName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirstName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get lastName => $_getSZ(2);
  @$pb.TagNumber(3)
  set lastName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastName() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastName() => $_clearField(3);
}

class SetMyOrgManagerStatusRequest extends $pb.GeneratedMessage {
  factory SetMyOrgManagerStatusRequest({
    $core.String? userId,
    $core.bool? isActive,
    $core.String? reason,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (isActive != null) result.isActive = isActive;
    if (reason != null) result.reason = reason;
    return result;
  }

  SetMyOrgManagerStatusRequest._();

  factory SetMyOrgManagerStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetMyOrgManagerStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetMyOrgManagerStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOB(2, _omitFieldNames ? '' : 'isActive')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMyOrgManagerStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMyOrgManagerStatusRequest copyWith(
          void Function(SetMyOrgManagerStatusRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SetMyOrgManagerStatusRequest))
          as SetMyOrgManagerStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetMyOrgManagerStatusRequest create() =>
      SetMyOrgManagerStatusRequest._();
  @$core.override
  SetMyOrgManagerStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetMyOrgManagerStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetMyOrgManagerStatusRequest>(create);
  static SetMyOrgManagerStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isActive => $_getBF(1);
  @$pb.TagNumber(2)
  set isActive($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsActive() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsActive() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);
}

class RevokeMyOrgManagerInviteRequest extends $pb.GeneratedMessage {
  factory RevokeMyOrgManagerInviteRequest({
    $core.String? invitationId,
  }) {
    final result = create();
    if (invitationId != null) result.invitationId = invitationId;
    return result;
  }

  RevokeMyOrgManagerInviteRequest._();

  factory RevokeMyOrgManagerInviteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RevokeMyOrgManagerInviteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevokeMyOrgManagerInviteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'invitationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeMyOrgManagerInviteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeMyOrgManagerInviteRequest copyWith(
          void Function(RevokeMyOrgManagerInviteRequest) updates) =>
      super.copyWith(
              (message) => updates(message as RevokeMyOrgManagerInviteRequest))
          as RevokeMyOrgManagerInviteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RevokeMyOrgManagerInviteRequest create() =>
      RevokeMyOrgManagerInviteRequest._();
  @$core.override
  RevokeMyOrgManagerInviteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RevokeMyOrgManagerInviteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevokeMyOrgManagerInviteRequest>(
          create);
  static RevokeMyOrgManagerInviteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get invitationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set invitationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInvitationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvitationId() => $_clearField(1);
}

class AdminCreateOrganizationRequest extends $pb.GeneratedMessage {
  factory AdminCreateOrganizationRequest({
    $core.String? legalName,
    $core.String? taxId,
    $core.String? vatIdEu,
    Address? headquarters,
    OrganizationType? type,
    $core.Iterable<$core.String>? managerEmails,
    $core.String? reason,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (legalName != null) result.legalName = legalName;
    if (taxId != null) result.taxId = taxId;
    if (vatIdEu != null) result.vatIdEu = vatIdEu;
    if (headquarters != null) result.headquarters = headquarters;
    if (type != null) result.type = type;
    if (managerEmails != null) result.managerEmails.addAll(managerEmails);
    if (reason != null) result.reason = reason;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  AdminCreateOrganizationRequest._();

  factory AdminCreateOrganizationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminCreateOrganizationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminCreateOrganizationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'legalName')
    ..aOS(2, _omitFieldNames ? '' : 'taxId')
    ..aOS(3, _omitFieldNames ? '' : 'vatIdEu')
    ..aOM<Address>(4, _omitFieldNames ? '' : 'headquarters',
        subBuilder: Address.create)
    ..aE<OrganizationType>(5, _omitFieldNames ? '' : 'type',
        enumValues: OrganizationType.values)
    ..pPS(6, _omitFieldNames ? '' : 'managerEmails')
    ..aOS(15, _omitFieldNames ? '' : 'reason')
    ..aOS(16, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminCreateOrganizationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminCreateOrganizationRequest copyWith(
          void Function(AdminCreateOrganizationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminCreateOrganizationRequest))
          as AdminCreateOrganizationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminCreateOrganizationRequest create() =>
      AdminCreateOrganizationRequest._();
  @$core.override
  AdminCreateOrganizationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminCreateOrganizationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminCreateOrganizationRequest>(create);
  static AdminCreateOrganizationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get legalName => $_getSZ(0);
  @$pb.TagNumber(1)
  set legalName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLegalName() => $_has(0);
  @$pb.TagNumber(1)
  void clearLegalName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get taxId => $_getSZ(1);
  @$pb.TagNumber(2)
  set taxId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTaxId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTaxId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get vatIdEu => $_getSZ(2);
  @$pb.TagNumber(3)
  set vatIdEu($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVatIdEu() => $_has(2);
  @$pb.TagNumber(3)
  void clearVatIdEu() => $_clearField(3);

  @$pb.TagNumber(4)
  Address get headquarters => $_getN(3);
  @$pb.TagNumber(4)
  set headquarters(Address value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasHeadquarters() => $_has(3);
  @$pb.TagNumber(4)
  void clearHeadquarters() => $_clearField(4);
  @$pb.TagNumber(4)
  Address ensureHeadquarters() => $_ensure(3);

  @$pb.TagNumber(5)
  OrganizationType get type => $_getN(4);
  @$pb.TagNumber(5)
  set type(OrganizationType value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasType() => $_has(4);
  @$pb.TagNumber(5)
  void clearType() => $_clearField(5);

  /// Org manager e-mails — each gets an ORG_ADMIN magic-link
  /// invitation (7-day expiry). At least one required.
  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get managerEmails => $_getList(5);

  @$pb.TagNumber(15)
  $core.String get reason => $_getSZ(6);
  @$pb.TagNumber(15)
  set reason($core.String value) => $_setString(6, value);
  @$pb.TagNumber(15)
  $core.bool hasReason() => $_has(6);
  @$pb.TagNumber(15)
  void clearReason() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get idempotencyKey => $_getSZ(7);
  @$pb.TagNumber(16)
  set idempotencyKey($core.String value) => $_setString(7, value);
  @$pb.TagNumber(16)
  $core.bool hasIdempotencyKey() => $_has(7);
  @$pb.TagNumber(16)
  void clearIdempotencyKey() => $_clearField(16);
}

class AdminInviteOrgManagerRequest extends $pb.GeneratedMessage {
  factory AdminInviteOrgManagerRequest({
    $core.String? organizationId,
    $core.String? email,
    $core.String? reason,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (email != null) result.email = email;
    if (reason != null) result.reason = reason;
    return result;
  }

  AdminInviteOrgManagerRequest._();

  factory AdminInviteOrgManagerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminInviteOrgManagerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminInviteOrgManagerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOS(15, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminInviteOrgManagerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminInviteOrgManagerRequest copyWith(
          void Function(AdminInviteOrgManagerRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminInviteOrgManagerRequest))
          as AdminInviteOrgManagerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminInviteOrgManagerRequest create() =>
      AdminInviteOrgManagerRequest._();
  @$core.override
  AdminInviteOrgManagerRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminInviteOrgManagerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminInviteOrgManagerRequest>(create);
  static AdminInviteOrgManagerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(15)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(15)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(15)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(15)
  void clearReason() => $_clearField(15);
}

class AdminAssignTherapistToOrgRequest extends $pb.GeneratedMessage {
  factory AdminAssignTherapistToOrgRequest({
    $core.String? organizationId,
    $core.String? email,
    $core.bool? confirmTransfer,
    $core.String? seatAllocationId,
    $core.String? reason,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (email != null) result.email = email;
    if (confirmTransfer != null) result.confirmTransfer = confirmTransfer;
    if (seatAllocationId != null) result.seatAllocationId = seatAllocationId;
    if (reason != null) result.reason = reason;
    return result;
  }

  AdminAssignTherapistToOrgRequest._();

  factory AdminAssignTherapistToOrgRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminAssignTherapistToOrgRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminAssignTherapistToOrgRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOB(3, _omitFieldNames ? '' : 'confirmTransfer')
    ..aOS(4, _omitFieldNames ? '' : 'seatAllocationId')
    ..aOS(15, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminAssignTherapistToOrgRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminAssignTherapistToOrgRequest copyWith(
          void Function(AdminAssignTherapistToOrgRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminAssignTherapistToOrgRequest))
          as AdminAssignTherapistToOrgRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminAssignTherapistToOrgRequest create() =>
      AdminAssignTherapistToOrgRequest._();
  @$core.override
  AdminAssignTherapistToOrgRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminAssignTherapistToOrgRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminAssignTherapistToOrgRequest>(
          create);
  static AdminAssignTherapistToOrgRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  /// The therapist's account e-mail. Matched case-insensitively against
  /// users.email (non-deleted). No account = NotFound; this RPC never
  /// creates users and never sends invitations.
  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  /// Set true to go through with a move when the therapist already
  /// belongs to another organization. Without it the server answers
  /// TRANSFER_CONFIRMATION_REQUIRED and writes nothing.
  @$pb.TagNumber(3)
  $core.bool get confirmTransfer => $_getBF(2);
  @$pb.TagNumber(3)
  set confirmTransfer($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConfirmTransfer() => $_has(2);
  @$pb.TagNumber(3)
  void clearConfirmTransfer() => $_clearField(3);

  /// Which seat allocation to occupy. Optional: when the org has exactly
  /// one allocation the server picks it; with several, omitting this is
  /// an InvalidArgument. Orgs with no allocations get no seat row at
  /// all, matching the allocation-less invite path.
  @$pb.TagNumber(4)
  $core.String get seatAllocationId => $_getSZ(3);
  @$pb.TagNumber(4)
  set seatAllocationId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSeatAllocationId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSeatAllocationId() => $_clearField(4);

  @$pb.TagNumber(15)
  $core.String get reason => $_getSZ(4);
  @$pb.TagNumber(15)
  set reason($core.String value) => $_setString(4, value);
  @$pb.TagNumber(15)
  $core.bool hasReason() => $_has(4);
  @$pb.TagNumber(15)
  void clearReason() => $_clearField(15);
}

/// What an admin should see BEFORE moving a therapist out of their
/// current organization. Sessions and kartoteki stay with the therapist,
/// but the billing history stays with the OLD org — that asymmetry is
/// the reason this confirmation exists.
class TherapistTransferWarning extends $pb.GeneratedMessage {
  factory TherapistTransferWarning({
    $core.String? currentOrganizationId,
    $core.String? currentOrganizationName,
    $core.int? totalSessions,
    $core.int? billableSessions,
    $core.int? tokensConsumed,
    $2.Timestamp? lastSessionAt,
    $core.bool? holdsActiveSeat,
  }) {
    final result = create();
    if (currentOrganizationId != null)
      result.currentOrganizationId = currentOrganizationId;
    if (currentOrganizationName != null)
      result.currentOrganizationName = currentOrganizationName;
    if (totalSessions != null) result.totalSessions = totalSessions;
    if (billableSessions != null) result.billableSessions = billableSessions;
    if (tokensConsumed != null) result.tokensConsumed = tokensConsumed;
    if (lastSessionAt != null) result.lastSessionAt = lastSessionAt;
    if (holdsActiveSeat != null) result.holdsActiveSeat = holdsActiveSeat;
    return result;
  }

  TherapistTransferWarning._();

  factory TherapistTransferWarning.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TherapistTransferWarning.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TherapistTransferWarning',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'currentOrganizationId')
    ..aOS(2, _omitFieldNames ? '' : 'currentOrganizationName')
    ..aI(3, _omitFieldNames ? '' : 'totalSessions')
    ..aI(4, _omitFieldNames ? '' : 'billableSessions')
    ..aI(5, _omitFieldNames ? '' : 'tokensConsumed')
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'lastSessionAt',
        subBuilder: $2.Timestamp.create)
    ..aOB(7, _omitFieldNames ? '' : 'holdsActiveSeat')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TherapistTransferWarning clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TherapistTransferWarning copyWith(
          void Function(TherapistTransferWarning) updates) =>
      super.copyWith((message) => updates(message as TherapistTransferWarning))
          as TherapistTransferWarning;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TherapistTransferWarning create() => TherapistTransferWarning._();
  @$core.override
  TherapistTransferWarning createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TherapistTransferWarning getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TherapistTransferWarning>(create);
  static TherapistTransferWarning? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get currentOrganizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set currentOrganizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCurrentOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrentOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get currentOrganizationName => $_getSZ(1);
  @$pb.TagNumber(2)
  set currentOrganizationName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCurrentOrganizationName() => $_has(1);
  @$pb.TagNumber(2)
  void clearCurrentOrganizationName() => $_clearField(2);

  /// Every session ever recorded by this therapist, across orgs.
  @$pb.TagNumber(3)
  $core.int get totalSessions => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalSessions($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalSessions() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalSessions() => $_clearField(3);

  /// Of those, the ones that consumed billing tokens (usage_events).
  @$pb.TagNumber(4)
  $core.int get billableSessions => $_getIZ(3);
  @$pb.TagNumber(4)
  set billableSessions($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBillableSessions() => $_has(3);
  @$pb.TagNumber(4)
  void clearBillableSessions() => $_clearField(4);

  /// Sum of usage_events.tokens_consumed for this therapist's sessions.
  @$pb.TagNumber(5)
  $core.int get tokensConsumed => $_getIZ(4);
  @$pb.TagNumber(5)
  set tokensConsumed($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTokensConsumed() => $_has(4);
  @$pb.TagNumber(5)
  void clearTokensConsumed() => $_clearField(5);

  @$pb.TagNumber(6)
  $2.Timestamp get lastSessionAt => $_getN(5);
  @$pb.TagNumber(6)
  set lastSessionAt($2.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasLastSessionAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearLastSessionAt() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensureLastSessionAt() => $_ensure(5);

  /// True when the therapist currently occupies a seat in the old org —
  /// that seat is released by the move.
  @$pb.TagNumber(7)
  $core.bool get holdsActiveSeat => $_getBF(6);
  @$pb.TagNumber(7)
  set holdsActiveSeat($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasHoldsActiveSeat() => $_has(6);
  @$pb.TagNumber(7)
  void clearHoldsActiveSeat() => $_clearField(7);
}

class AdminAssignTherapistToOrgResponse extends $pb.GeneratedMessage {
  factory AdminAssignTherapistToOrgResponse({
    AdminAssignTherapistStatus? status,
    User? therapist,
    TherapistTransferWarning? transferWarning,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (therapist != null) result.therapist = therapist;
    if (transferWarning != null) result.transferWarning = transferWarning;
    return result;
  }

  AdminAssignTherapistToOrgResponse._();

  factory AdminAssignTherapistToOrgResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminAssignTherapistToOrgResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminAssignTherapistToOrgResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aE<AdminAssignTherapistStatus>(1, _omitFieldNames ? '' : 'status',
        enumValues: AdminAssignTherapistStatus.values)
    ..aOM<User>(2, _omitFieldNames ? '' : 'therapist', subBuilder: User.create)
    ..aOM<TherapistTransferWarning>(3, _omitFieldNames ? '' : 'transferWarning',
        subBuilder: TherapistTransferWarning.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminAssignTherapistToOrgResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminAssignTherapistToOrgResponse copyWith(
          void Function(AdminAssignTherapistToOrgResponse) updates) =>
      super.copyWith((message) =>
              updates(message as AdminAssignTherapistToOrgResponse))
          as AdminAssignTherapistToOrgResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminAssignTherapistToOrgResponse create() =>
      AdminAssignTherapistToOrgResponse._();
  @$core.override
  AdminAssignTherapistToOrgResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminAssignTherapistToOrgResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminAssignTherapistToOrgResponse>(
          create);
  static AdminAssignTherapistToOrgResponse? _defaultInstance;

  @$pb.TagNumber(1)
  AdminAssignTherapistStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(AdminAssignTherapistStatus value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  /// Set when status = ASSIGNED.
  @$pb.TagNumber(2)
  User get therapist => $_getN(1);
  @$pb.TagNumber(2)
  set therapist(User value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapist() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapist() => $_clearField(2);
  @$pb.TagNumber(2)
  User ensureTherapist() => $_ensure(1);

  /// Set when status = TRANSFER_CONFIRMATION_REQUIRED.
  @$pb.TagNumber(3)
  TherapistTransferWarning get transferWarning => $_getN(2);
  @$pb.TagNumber(3)
  set transferWarning(TherapistTransferWarning value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasTransferWarning() => $_has(2);
  @$pb.TagNumber(3)
  void clearTransferWarning() => $_clearField(3);
  @$pb.TagNumber(3)
  TherapistTransferWarning ensureTransferWarning() => $_ensure(2);
}

class AdminUnassignTherapistFromOrgRequest extends $pb.GeneratedMessage {
  factory AdminUnassignTherapistFromOrgRequest({
    $core.String? organizationId,
    $core.String? userId,
    $core.String? reason,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (userId != null) result.userId = userId;
    if (reason != null) result.reason = reason;
    return result;
  }

  AdminUnassignTherapistFromOrgRequest._();

  factory AdminUnassignTherapistFromOrgRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminUnassignTherapistFromOrgRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminUnassignTherapistFromOrgRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(15, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUnassignTherapistFromOrgRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUnassignTherapistFromOrgRequest copyWith(
          void Function(AdminUnassignTherapistFromOrgRequest) updates) =>
      super.copyWith((message) =>
              updates(message as AdminUnassignTherapistFromOrgRequest))
          as AdminUnassignTherapistFromOrgRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminUnassignTherapistFromOrgRequest create() =>
      AdminUnassignTherapistFromOrgRequest._();
  @$core.override
  AdminUnassignTherapistFromOrgRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminUnassignTherapistFromOrgRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          AdminUnassignTherapistFromOrgRequest>(create);
  static AdminUnassignTherapistFromOrgRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(15)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(15)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(15)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(15)
  void clearReason() => $_clearField(15);
}

class AdminCreateOrganizationResponse extends $pb.GeneratedMessage {
  factory AdminCreateOrganizationResponse({
    Organization? organization,
    $core.Iterable<Invitation>? managerInvitations,
  }) {
    final result = create();
    if (organization != null) result.organization = organization;
    if (managerInvitations != null)
      result.managerInvitations.addAll(managerInvitations);
    return result;
  }

  AdminCreateOrganizationResponse._();

  factory AdminCreateOrganizationResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminCreateOrganizationResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminCreateOrganizationResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOM<Organization>(1, _omitFieldNames ? '' : 'organization',
        subBuilder: Organization.create)
    ..pPM<Invitation>(2, _omitFieldNames ? '' : 'managerInvitations',
        subBuilder: Invitation.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminCreateOrganizationResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminCreateOrganizationResponse copyWith(
          void Function(AdminCreateOrganizationResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AdminCreateOrganizationResponse))
          as AdminCreateOrganizationResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminCreateOrganizationResponse create() =>
      AdminCreateOrganizationResponse._();
  @$core.override
  AdminCreateOrganizationResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminCreateOrganizationResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminCreateOrganizationResponse>(
          create);
  static AdminCreateOrganizationResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Organization get organization => $_getN(0);
  @$pb.TagNumber(1)
  set organization(Organization value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganization() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganization() => $_clearField(1);
  @$pb.TagNumber(1)
  Organization ensureOrganization() => $_ensure(0);

  /// The ORG_ADMIN invitations created (one per manager e-mail),
  /// so the admin UI can show pending state immediately.
  @$pb.TagNumber(2)
  $pb.PbList<Invitation> get managerInvitations => $_getList(1);
}

class AdminListOrganizationsRequest extends $pb.GeneratedMessage {
  factory AdminListOrganizationsRequest({
    $core.int? pageSize,
    $core.String? pageToken,
    $core.String? search,
    OrganizationType? type,
  }) {
    final result = create();
    if (pageSize != null) result.pageSize = pageSize;
    if (pageToken != null) result.pageToken = pageToken;
    if (search != null) result.search = search;
    if (type != null) result.type = type;
    return result;
  }

  AdminListOrganizationsRequest._();

  factory AdminListOrganizationsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListOrganizationsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListOrganizationsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'pageSize')
    ..aOS(2, _omitFieldNames ? '' : 'pageToken')
    ..aOS(3, _omitFieldNames ? '' : 'search')
    ..aE<OrganizationType>(4, _omitFieldNames ? '' : 'type',
        enumValues: OrganizationType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListOrganizationsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListOrganizationsRequest copyWith(
          void Function(AdminListOrganizationsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminListOrganizationsRequest))
          as AdminListOrganizationsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListOrganizationsRequest create() =>
      AdminListOrganizationsRequest._();
  @$core.override
  AdminListOrganizationsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListOrganizationsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListOrganizationsRequest>(create);
  static AdminListOrganizationsRequest? _defaultInstance;

  /// Pagination — for now we just slice on (created_at, id) ordering.
  @$pb.TagNumber(1)
  $core.int get pageSize => $_getIZ(0);
  @$pb.TagNumber(1)
  set pageSize($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPageSize() => $_has(0);
  @$pb.TagNumber(1)
  void clearPageSize() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set pageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get search => $_getSZ(2);
  @$pb.TagNumber(3)
  set search($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSearch() => $_has(2);
  @$pb.TagNumber(3)
  void clearSearch() => $_clearField(3);

  /// Optional type filter (UNSPECIFIED = all). The /admin/orgs table
  /// defaults to CLINIC — B2B clinics are the admin's day-to-day; solo
  /// bootstrap orgs are noise there.
  @$pb.TagNumber(4)
  OrganizationType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(OrganizationType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);
}

class OrganizationSummary extends $pb.GeneratedMessage {
  factory OrganizationSummary({
    Organization? organization,
    $core.int? therapistsCount,
    $2.Timestamp? lastSessionAt,
  }) {
    final result = create();
    if (organization != null) result.organization = organization;
    if (therapistsCount != null) result.therapistsCount = therapistsCount;
    if (lastSessionAt != null) result.lastSessionAt = lastSessionAt;
    return result;
  }

  OrganizationSummary._();

  factory OrganizationSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OrganizationSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OrganizationSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOM<Organization>(1, _omitFieldNames ? '' : 'organization',
        subBuilder: Organization.create)
    ..aI(2, _omitFieldNames ? '' : 'therapistsCount')
    ..aOM<$2.Timestamp>(3, _omitFieldNames ? '' : 'lastSessionAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrganizationSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrganizationSummary copyWith(void Function(OrganizationSummary) updates) =>
      super.copyWith((message) => updates(message as OrganizationSummary))
          as OrganizationSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OrganizationSummary create() => OrganizationSummary._();
  @$core.override
  OrganizationSummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OrganizationSummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OrganizationSummary>(create);
  static OrganizationSummary? _defaultInstance;

  @$pb.TagNumber(1)
  Organization get organization => $_getN(0);
  @$pb.TagNumber(1)
  set organization(Organization value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganization() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganization() => $_clearField(1);
  @$pb.TagNumber(1)
  Organization ensureOrganization() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get therapistsCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set therapistsCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistsCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistsCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $2.Timestamp get lastSessionAt => $_getN(2);
  @$pb.TagNumber(3)
  set lastSessionAt($2.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasLastSessionAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastSessionAt() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.Timestamp ensureLastSessionAt() => $_ensure(2);
}

class AdminListOrganizationsResponse extends $pb.GeneratedMessage {
  factory AdminListOrganizationsResponse({
    $core.Iterable<OrganizationSummary>? organizations,
    $core.String? nextPageToken,
  }) {
    final result = create();
    if (organizations != null) result.organizations.addAll(organizations);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    return result;
  }

  AdminListOrganizationsResponse._();

  factory AdminListOrganizationsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListOrganizationsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListOrganizationsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..pPM<OrganizationSummary>(1, _omitFieldNames ? '' : 'organizations',
        subBuilder: OrganizationSummary.create)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListOrganizationsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListOrganizationsResponse copyWith(
          void Function(AdminListOrganizationsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AdminListOrganizationsResponse))
          as AdminListOrganizationsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListOrganizationsResponse create() =>
      AdminListOrganizationsResponse._();
  @$core.override
  AdminListOrganizationsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListOrganizationsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListOrganizationsResponse>(create);
  static AdminListOrganizationsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<OrganizationSummary> get organizations => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);
}

class AdminGetOrganizationRequest extends $pb.GeneratedMessage {
  factory AdminGetOrganizationRequest({
    $core.String? organizationId,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    return result;
  }

  AdminGetOrganizationRequest._();

  factory AdminGetOrganizationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminGetOrganizationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminGetOrganizationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetOrganizationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetOrganizationRequest copyWith(
          void Function(AdminGetOrganizationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminGetOrganizationRequest))
          as AdminGetOrganizationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminGetOrganizationRequest create() =>
      AdminGetOrganizationRequest._();
  @$core.override
  AdminGetOrganizationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminGetOrganizationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminGetOrganizationRequest>(create);
  static AdminGetOrganizationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);
}

/// Richer view than Organization — includes admin-relevant adjuncts.
class OrganizationDetails extends $pb.GeneratedMessage {
  factory OrganizationDetails({
    Organization? organization,
    $core.Iterable<User>? therapists,
    $core.Iterable<AuditEntry>? recentAudit,
    $core.Iterable<User>? managers,
  }) {
    final result = create();
    if (organization != null) result.organization = organization;
    if (therapists != null) result.therapists.addAll(therapists);
    if (recentAudit != null) result.recentAudit.addAll(recentAudit);
    if (managers != null) result.managers.addAll(managers);
    return result;
  }

  OrganizationDetails._();

  factory OrganizationDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OrganizationDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OrganizationDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOM<Organization>(1, _omitFieldNames ? '' : 'organization',
        subBuilder: Organization.create)
    ..pPM<User>(2, _omitFieldNames ? '' : 'therapists', subBuilder: User.create)
    ..pPM<AuditEntry>(3, _omitFieldNames ? '' : 'recentAudit',
        subBuilder: AuditEntry.create)
    ..pPM<User>(4, _omitFieldNames ? '' : 'managers', subBuilder: User.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrganizationDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrganizationDetails copyWith(void Function(OrganizationDetails) updates) =>
      super.copyWith((message) => updates(message as OrganizationDetails))
          as OrganizationDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OrganizationDetails create() => OrganizationDetails._();
  @$core.override
  OrganizationDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OrganizationDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OrganizationDetails>(create);
  static OrganizationDetails? _defaultInstance;

  @$pb.TagNumber(1)
  Organization get organization => $_getN(0);
  @$pb.TagNumber(1)
  set organization(Organization value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganization() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganization() => $_clearField(1);
  @$pb.TagNumber(1)
  Organization ensureOrganization() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<User> get therapists => $_getList(1);

  /// Recent audit history scoped to this org (last 20 entries).
  @$pb.TagNumber(3)
  $pb.PbList<AuditEntry> get recentAudit => $_getList(2);

  /// Org managers (role=ORG_ADMIN) — the candidate pool for the
  /// primary-admin transfer select on /admin/orgs/[id] (docs/38).
  @$pb.TagNumber(4)
  $pb.PbList<User> get managers => $_getList(3);
}

class AuditEntry extends $pb.GeneratedMessage {
  factory AuditEntry({
    $core.String? id,
    $2.Timestamp? occurredAt,
    $core.String? actorEmail,
    $core.String? action,
    $core.String? reason,
    $core.String? resourceType,
    $core.String? resourceId,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (occurredAt != null) result.occurredAt = occurredAt;
    if (actorEmail != null) result.actorEmail = actorEmail;
    if (action != null) result.action = action;
    if (reason != null) result.reason = reason;
    if (resourceType != null) result.resourceType = resourceType;
    if (resourceId != null) result.resourceId = resourceId;
    return result;
  }

  AuditEntry._();

  factory AuditEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AuditEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AuditEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOM<$2.Timestamp>(2, _omitFieldNames ? '' : 'occurredAt',
        subBuilder: $2.Timestamp.create)
    ..aOS(3, _omitFieldNames ? '' : 'actorEmail')
    ..aOS(4, _omitFieldNames ? '' : 'action')
    ..aOS(5, _omitFieldNames ? '' : 'reason')
    ..aOS(6, _omitFieldNames ? '' : 'resourceType')
    ..aOS(7, _omitFieldNames ? '' : 'resourceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuditEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuditEntry copyWith(void Function(AuditEntry) updates) =>
      super.copyWith((message) => updates(message as AuditEntry)) as AuditEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AuditEntry create() => AuditEntry._();
  @$core.override
  AuditEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AuditEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AuditEntry>(create);
  static AuditEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $2.Timestamp get occurredAt => $_getN(1);
  @$pb.TagNumber(2)
  set occurredAt($2.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOccurredAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearOccurredAt() => $_clearField(2);
  @$pb.TagNumber(2)
  $2.Timestamp ensureOccurredAt() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get actorEmail => $_getSZ(2);
  @$pb.TagNumber(3)
  set actorEmail($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActorEmail() => $_has(2);
  @$pb.TagNumber(3)
  void clearActorEmail() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get action => $_getSZ(3);
  @$pb.TagNumber(4)
  set action($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAction() => $_has(3);
  @$pb.TagNumber(4)
  void clearAction() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get reason => $_getSZ(4);
  @$pb.TagNumber(5)
  set reason($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReason() => $_has(4);
  @$pb.TagNumber(5)
  void clearReason() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get resourceType => $_getSZ(5);
  @$pb.TagNumber(6)
  set resourceType($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasResourceType() => $_has(5);
  @$pb.TagNumber(6)
  void clearResourceType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get resourceId => $_getSZ(6);
  @$pb.TagNumber(7)
  set resourceId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasResourceId() => $_has(6);
  @$pb.TagNumber(7)
  void clearResourceId() => $_clearField(7);
}

class AdminSetOrganizationStatusRequest extends $pb.GeneratedMessage {
  factory AdminSetOrganizationStatusRequest({
    $core.String? organizationId,
    $core.String? desiredStatus,
    $core.String? reason,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (desiredStatus != null) result.desiredStatus = desiredStatus;
    if (reason != null) result.reason = reason;
    return result;
  }

  AdminSetOrganizationStatusRequest._();

  factory AdminSetOrganizationStatusRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminSetOrganizationStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminSetOrganizationStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOS(2, _omitFieldNames ? '' : 'desiredStatus')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetOrganizationStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetOrganizationStatusRequest copyWith(
          void Function(AdminSetOrganizationStatusRequest) updates) =>
      super.copyWith((message) =>
              updates(message as AdminSetOrganizationStatusRequest))
          as AdminSetOrganizationStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminSetOrganizationStatusRequest create() =>
      AdminSetOrganizationStatusRequest._();
  @$core.override
  AdminSetOrganizationStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminSetOrganizationStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminSetOrganizationStatusRequest>(
          create);
  static AdminSetOrganizationStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  /// Currently supports: "active" | "blocked". Maps to
  /// subscriptions.status (ACTIVE / PAST_DUE).
  @$pb.TagNumber(2)
  $core.String get desiredStatus => $_getSZ(1);
  @$pb.TagNumber(2)
  set desiredStatus($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDesiredStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearDesiredStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);
}

class AdminUpdateOrganizationRequest extends $pb.GeneratedMessage {
  factory AdminUpdateOrganizationRequest({
    $core.String? organizationId,
    $core.String? legalName,
    OrganizationType? type,
    $core.String? taxId,
    $core.String? vatIdEu,
    Address? headquartersAddress,
    $core.String? primaryAdminUserId,
    $core.String? reason,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (legalName != null) result.legalName = legalName;
    if (type != null) result.type = type;
    if (taxId != null) result.taxId = taxId;
    if (vatIdEu != null) result.vatIdEu = vatIdEu;
    if (headquartersAddress != null)
      result.headquartersAddress = headquartersAddress;
    if (primaryAdminUserId != null)
      result.primaryAdminUserId = primaryAdminUserId;
    if (reason != null) result.reason = reason;
    return result;
  }

  AdminUpdateOrganizationRequest._();

  factory AdminUpdateOrganizationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminUpdateOrganizationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminUpdateOrganizationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOS(2, _omitFieldNames ? '' : 'legalName')
    ..aE<OrganizationType>(3, _omitFieldNames ? '' : 'type',
        enumValues: OrganizationType.values)
    ..aOS(4, _omitFieldNames ? '' : 'taxId')
    ..aOS(5, _omitFieldNames ? '' : 'vatIdEu')
    ..aOM<Address>(6, _omitFieldNames ? '' : 'headquartersAddress',
        subBuilder: Address.create)
    ..aOS(7, _omitFieldNames ? '' : 'primaryAdminUserId')
    ..aOS(8, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateOrganizationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateOrganizationRequest copyWith(
          void Function(AdminUpdateOrganizationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminUpdateOrganizationRequest))
          as AdminUpdateOrganizationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminUpdateOrganizationRequest create() =>
      AdminUpdateOrganizationRequest._();
  @$core.override
  AdminUpdateOrganizationRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminUpdateOrganizationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminUpdateOrganizationRequest>(create);
  static AdminUpdateOrganizationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get legalName => $_getSZ(1);
  @$pb.TagNumber(2)
  set legalName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLegalName() => $_has(1);
  @$pb.TagNumber(2)
  void clearLegalName() => $_clearField(2);

  @$pb.TagNumber(3)
  OrganizationType get type => $_getN(2);
  @$pb.TagNumber(3)
  set type(OrganizationType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get taxId => $_getSZ(3);
  @$pb.TagNumber(4)
  set taxId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTaxId() => $_has(3);
  @$pb.TagNumber(4)
  void clearTaxId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get vatIdEu => $_getSZ(4);
  @$pb.TagNumber(5)
  set vatIdEu($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVatIdEu() => $_has(4);
  @$pb.TagNumber(5)
  void clearVatIdEu() => $_clearField(5);

  @$pb.TagNumber(6)
  Address get headquartersAddress => $_getN(5);
  @$pb.TagNumber(6)
  set headquartersAddress(Address value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasHeadquartersAddress() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeadquartersAddress() => $_clearField(6);
  @$pb.TagNumber(6)
  Address ensureHeadquartersAddress() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.String get primaryAdminUserId => $_getSZ(6);
  @$pb.TagNumber(7)
  set primaryAdminUserId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPrimaryAdminUserId() => $_has(6);
  @$pb.TagNumber(7)
  void clearPrimaryAdminUserId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get reason => $_getSZ(7);
  @$pb.TagNumber(8)
  set reason($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasReason() => $_has(7);
  @$pb.TagNumber(8)
  void clearReason() => $_clearField(8);
}

class AdminListUsersRequest extends $pb.GeneratedMessage {
  factory AdminListUsersRequest({
    $core.int? pageSize,
    $core.String? pageToken,
    $core.String? organizationId,
    UserRole? role,
    $core.String? search,
  }) {
    final result = create();
    if (pageSize != null) result.pageSize = pageSize;
    if (pageToken != null) result.pageToken = pageToken;
    if (organizationId != null) result.organizationId = organizationId;
    if (role != null) result.role = role;
    if (search != null) result.search = search;
    return result;
  }

  AdminListUsersRequest._();

  factory AdminListUsersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListUsersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListUsersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'pageSize')
    ..aOS(2, _omitFieldNames ? '' : 'pageToken')
    ..aOS(3, _omitFieldNames ? '' : 'organizationId')
    ..aE<UserRole>(4, _omitFieldNames ? '' : 'role',
        enumValues: UserRole.values)
    ..aOS(5, _omitFieldNames ? '' : 'search')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListUsersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListUsersRequest copyWith(
          void Function(AdminListUsersRequest) updates) =>
      super.copyWith((message) => updates(message as AdminListUsersRequest))
          as AdminListUsersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListUsersRequest create() => AdminListUsersRequest._();
  @$core.override
  AdminListUsersRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListUsersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListUsersRequest>(create);
  static AdminListUsersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get pageSize => $_getIZ(0);
  @$pb.TagNumber(1)
  set pageSize($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPageSize() => $_has(0);
  @$pb.TagNumber(1)
  void clearPageSize() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set pageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageToken() => $_clearField(2);

  /// Optional filters — all AND-ed when set.
  @$pb.TagNumber(3)
  $core.String get organizationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set organizationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOrganizationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearOrganizationId() => $_clearField(3);

  @$pb.TagNumber(4)
  UserRole get role => $_getN(3);
  @$pb.TagNumber(4)
  set role(UserRole value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRole() => $_has(3);
  @$pb.TagNumber(4)
  void clearRole() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get search => $_getSZ(4);
  @$pb.TagNumber(5)
  set search($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSearch() => $_has(4);
  @$pb.TagNumber(5)
  void clearSearch() => $_clearField(5);
}

class AdminListUsersResponse extends $pb.GeneratedMessage {
  factory AdminListUsersResponse({
    $core.Iterable<User>? users,
    $core.String? nextPageToken,
  }) {
    final result = create();
    if (users != null) result.users.addAll(users);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    return result;
  }

  AdminListUsersResponse._();

  factory AdminListUsersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListUsersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListUsersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..pPM<User>(1, _omitFieldNames ? '' : 'users', subBuilder: User.create)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListUsersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListUsersResponse copyWith(
          void Function(AdminListUsersResponse) updates) =>
      super.copyWith((message) => updates(message as AdminListUsersResponse))
          as AdminListUsersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListUsersResponse create() => AdminListUsersResponse._();
  @$core.override
  AdminListUsersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListUsersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListUsersResponse>(create);
  static AdminListUsersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<User> get users => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);
}

class AdminGetUserRequest extends $pb.GeneratedMessage {
  factory AdminGetUserRequest({
    $core.String? userId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    return result;
  }

  AdminGetUserRequest._();

  factory AdminGetUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminGetUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminGetUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetUserRequest copyWith(void Function(AdminGetUserRequest) updates) =>
      super.copyWith((message) => updates(message as AdminGetUserRequest))
          as AdminGetUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminGetUserRequest create() => AdminGetUserRequest._();
  @$core.override
  AdminGetUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminGetUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminGetUserRequest>(create);
  static AdminGetUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);
}

class AdminUpdateUserRequest extends $pb.GeneratedMessage {
  factory AdminUpdateUserRequest({
    $core.String? userId,
    $core.String? email,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? phoneNumber,
    UserRole? role,
    $core.String? organizationId,
    $core.String? defaultModalityId,
    $core.String? uiLanguage,
    $core.String? timezone,
    $core.String? professionalTitle,
    $core.String? credentialsNumber,
    $core.String? biography,
    $core.String? avatarUrl,
    Address? billingAddress,
    $core.bool? isEmailVerified,
    $core.String? reason,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (email != null) result.email = email;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (phoneNumber != null) result.phoneNumber = phoneNumber;
    if (role != null) result.role = role;
    if (organizationId != null) result.organizationId = organizationId;
    if (defaultModalityId != null) result.defaultModalityId = defaultModalityId;
    if (uiLanguage != null) result.uiLanguage = uiLanguage;
    if (timezone != null) result.timezone = timezone;
    if (professionalTitle != null) result.professionalTitle = professionalTitle;
    if (credentialsNumber != null) result.credentialsNumber = credentialsNumber;
    if (biography != null) result.biography = biography;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (billingAddress != null) result.billingAddress = billingAddress;
    if (isEmailVerified != null) result.isEmailVerified = isEmailVerified;
    if (reason != null) result.reason = reason;
    return result;
  }

  AdminUpdateUserRequest._();

  factory AdminUpdateUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminUpdateUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminUpdateUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOS(3, _omitFieldNames ? '' : 'firstName')
    ..aOS(4, _omitFieldNames ? '' : 'lastName')
    ..aOS(5, _omitFieldNames ? '' : 'phoneNumber')
    ..aE<UserRole>(6, _omitFieldNames ? '' : 'role',
        enumValues: UserRole.values)
    ..aOS(7, _omitFieldNames ? '' : 'organizationId')
    ..aOS(8, _omitFieldNames ? '' : 'defaultModalityId')
    ..aOS(9, _omitFieldNames ? '' : 'uiLanguage')
    ..aOS(10, _omitFieldNames ? '' : 'timezone')
    ..aOS(11, _omitFieldNames ? '' : 'professionalTitle')
    ..aOS(12, _omitFieldNames ? '' : 'credentialsNumber')
    ..aOS(13, _omitFieldNames ? '' : 'biography')
    ..aOS(14, _omitFieldNames ? '' : 'avatarUrl')
    ..aOM<Address>(15, _omitFieldNames ? '' : 'billingAddress',
        subBuilder: Address.create)
    ..aOB(16, _omitFieldNames ? '' : 'isEmailVerified')
    ..aOS(17, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateUserRequest copyWith(
          void Function(AdminUpdateUserRequest) updates) =>
      super.copyWith((message) => updates(message as AdminUpdateUserRequest))
          as AdminUpdateUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminUpdateUserRequest create() => AdminUpdateUserRequest._();
  @$core.override
  AdminUpdateUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminUpdateUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminUpdateUserRequest>(create);
  static AdminUpdateUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get firstName => $_getSZ(2);
  @$pb.TagNumber(3)
  set firstName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstName() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get lastName => $_getSZ(3);
  @$pb.TagNumber(4)
  set lastName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastName() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get phoneNumber => $_getSZ(4);
  @$pb.TagNumber(5)
  set phoneNumber($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPhoneNumber() => $_has(4);
  @$pb.TagNumber(5)
  void clearPhoneNumber() => $_clearField(5);

  @$pb.TagNumber(6)
  UserRole get role => $_getN(5);
  @$pb.TagNumber(6)
  set role(UserRole value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRole() => $_has(5);
  @$pb.TagNumber(6)
  void clearRole() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get organizationId => $_getSZ(6);
  @$pb.TagNumber(7)
  set organizationId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOrganizationId() => $_has(6);
  @$pb.TagNumber(7)
  void clearOrganizationId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get defaultModalityId => $_getSZ(7);
  @$pb.TagNumber(8)
  set defaultModalityId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDefaultModalityId() => $_has(7);
  @$pb.TagNumber(8)
  void clearDefaultModalityId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get uiLanguage => $_getSZ(8);
  @$pb.TagNumber(9)
  set uiLanguage($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUiLanguage() => $_has(8);
  @$pb.TagNumber(9)
  void clearUiLanguage() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get timezone => $_getSZ(9);
  @$pb.TagNumber(10)
  set timezone($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTimezone() => $_has(9);
  @$pb.TagNumber(10)
  void clearTimezone() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get professionalTitle => $_getSZ(10);
  @$pb.TagNumber(11)
  set professionalTitle($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasProfessionalTitle() => $_has(10);
  @$pb.TagNumber(11)
  void clearProfessionalTitle() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get credentialsNumber => $_getSZ(11);
  @$pb.TagNumber(12)
  set credentialsNumber($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasCredentialsNumber() => $_has(11);
  @$pb.TagNumber(12)
  void clearCredentialsNumber() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get biography => $_getSZ(12);
  @$pb.TagNumber(13)
  set biography($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasBiography() => $_has(12);
  @$pb.TagNumber(13)
  void clearBiography() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get avatarUrl => $_getSZ(13);
  @$pb.TagNumber(14)
  set avatarUrl($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasAvatarUrl() => $_has(13);
  @$pb.TagNumber(14)
  void clearAvatarUrl() => $_clearField(14);

  @$pb.TagNumber(15)
  Address get billingAddress => $_getN(14);
  @$pb.TagNumber(15)
  set billingAddress(Address value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasBillingAddress() => $_has(14);
  @$pb.TagNumber(15)
  void clearBillingAddress() => $_clearField(15);
  @$pb.TagNumber(15)
  Address ensureBillingAddress() => $_ensure(14);

  @$pb.TagNumber(16)
  $core.bool get isEmailVerified => $_getBF(15);
  @$pb.TagNumber(16)
  set isEmailVerified($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(16)
  $core.bool hasIsEmailVerified() => $_has(15);
  @$pb.TagNumber(16)
  void clearIsEmailVerified() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get reason => $_getSZ(16);
  @$pb.TagNumber(17)
  set reason($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasReason() => $_has(16);
  @$pb.TagNumber(17)
  void clearReason() => $_clearField(17);
}

class AdminDeleteUserRequest extends $pb.GeneratedMessage {
  factory AdminDeleteUserRequest({
    $core.String? userId,
    $core.String? reason,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (reason != null) result.reason = reason;
    return result;
  }

  AdminDeleteUserRequest._();

  factory AdminDeleteUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminDeleteUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminDeleteUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminDeleteUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminDeleteUserRequest copyWith(
          void Function(AdminDeleteUserRequest) updates) =>
      super.copyWith((message) => updates(message as AdminDeleteUserRequest))
          as AdminDeleteUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminDeleteUserRequest create() => AdminDeleteUserRequest._();
  @$core.override
  AdminDeleteUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminDeleteUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminDeleteUserRequest>(create);
  static AdminDeleteUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

/// Global cross-org audit list, used by the /admin/audit viewer.
/// All filters are optional and AND together when set; empty actor_email
/// / action / since / until means "any". Pagination uses the same
/// (occurred_at, id) cursor format as the other admin lists.
class AdminListAuditEventsRequest extends $pb.GeneratedMessage {
  factory AdminListAuditEventsRequest({
    $core.int? pageSize,
    $core.String? pageToken,
    $core.String? actorEmail,
    $core.String? action,
    $2.Timestamp? since,
    $2.Timestamp? until,
  }) {
    final result = create();
    if (pageSize != null) result.pageSize = pageSize;
    if (pageToken != null) result.pageToken = pageToken;
    if (actorEmail != null) result.actorEmail = actorEmail;
    if (action != null) result.action = action;
    if (since != null) result.since = since;
    if (until != null) result.until = until;
    return result;
  }

  AdminListAuditEventsRequest._();

  factory AdminListAuditEventsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListAuditEventsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListAuditEventsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'pageSize')
    ..aOS(2, _omitFieldNames ? '' : 'pageToken')
    ..aOS(3, _omitFieldNames ? '' : 'actorEmail')
    ..aOS(4, _omitFieldNames ? '' : 'action')
    ..aOM<$2.Timestamp>(5, _omitFieldNames ? '' : 'since',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'until',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListAuditEventsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListAuditEventsRequest copyWith(
          void Function(AdminListAuditEventsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminListAuditEventsRequest))
          as AdminListAuditEventsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListAuditEventsRequest create() =>
      AdminListAuditEventsRequest._();
  @$core.override
  AdminListAuditEventsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListAuditEventsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListAuditEventsRequest>(create);
  static AdminListAuditEventsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get pageSize => $_getIZ(0);
  @$pb.TagNumber(1)
  set pageSize($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPageSize() => $_has(0);
  @$pb.TagNumber(1)
  void clearPageSize() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get pageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set pageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get actorEmail => $_getSZ(2);
  @$pb.TagNumber(3)
  set actorEmail($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActorEmail() => $_has(2);
  @$pb.TagNumber(3)
  void clearActorEmail() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get action => $_getSZ(3);
  @$pb.TagNumber(4)
  set action($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAction() => $_has(3);
  @$pb.TagNumber(4)
  void clearAction() => $_clearField(4);

  @$pb.TagNumber(5)
  $2.Timestamp get since => $_getN(4);
  @$pb.TagNumber(5)
  set since($2.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSince() => $_has(4);
  @$pb.TagNumber(5)
  void clearSince() => $_clearField(5);
  @$pb.TagNumber(5)
  $2.Timestamp ensureSince() => $_ensure(4);

  @$pb.TagNumber(6)
  $2.Timestamp get until => $_getN(5);
  @$pb.TagNumber(6)
  set until($2.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasUntil() => $_has(5);
  @$pb.TagNumber(6)
  void clearUntil() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensureUntil() => $_ensure(5);
}

class AdminListAuditEventsResponse extends $pb.GeneratedMessage {
  factory AdminListAuditEventsResponse({
    $core.Iterable<AuditEntry>? events,
    $core.String? nextPageToken,
  }) {
    final result = create();
    if (events != null) result.events.addAll(events);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    return result;
  }

  AdminListAuditEventsResponse._();

  factory AdminListAuditEventsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListAuditEventsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListAuditEventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..pPM<AuditEntry>(1, _omitFieldNames ? '' : 'events',
        subBuilder: AuditEntry.create)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListAuditEventsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListAuditEventsResponse copyWith(
          void Function(AdminListAuditEventsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AdminListAuditEventsResponse))
          as AdminListAuditEventsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListAuditEventsResponse create() =>
      AdminListAuditEventsResponse._();
  @$core.override
  AdminListAuditEventsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListAuditEventsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListAuditEventsResponse>(create);
  static AdminListAuditEventsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AuditEntry> get events => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);
}

class RecordConsentRequest extends $pb.GeneratedMessage {
  factory RecordConsentRequest({
    $core.String? userId,
    $core.String? consentType,
    $core.bool? granted,
    $core.String? consentVersion,
    $core.String? ipAddress,
    $core.String? userAgent,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (consentType != null) result.consentType = consentType;
    if (granted != null) result.granted = granted;
    if (consentVersion != null) result.consentVersion = consentVersion;
    if (ipAddress != null) result.ipAddress = ipAddress;
    if (userAgent != null) result.userAgent = userAgent;
    return result;
  }

  RecordConsentRequest._();

  factory RecordConsentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordConsentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordConsentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'consentType')
    ..aOB(3, _omitFieldNames ? '' : 'granted')
    ..aOS(4, _omitFieldNames ? '' : 'consentVersion')
    ..aOS(5, _omitFieldNames ? '' : 'ipAddress')
    ..aOS(6, _omitFieldNames ? '' : 'userAgent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordConsentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordConsentRequest copyWith(void Function(RecordConsentRequest) updates) =>
      super.copyWith((message) => updates(message as RecordConsentRequest))
          as RecordConsentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordConsentRequest create() => RecordConsentRequest._();
  @$core.override
  RecordConsentRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordConsentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordConsentRequest>(create);
  static RecordConsentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get consentType => $_getSZ(1);
  @$pb.TagNumber(2)
  set consentType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConsentType() => $_has(1);
  @$pb.TagNumber(2)
  void clearConsentType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get granted => $_getBF(2);
  @$pb.TagNumber(3)
  set granted($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGranted() => $_has(2);
  @$pb.TagNumber(3)
  void clearGranted() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get consentVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set consentVersion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasConsentVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearConsentVersion() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get ipAddress => $_getSZ(4);
  @$pb.TagNumber(5)
  set ipAddress($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIpAddress() => $_has(4);
  @$pb.TagNumber(5)
  void clearIpAddress() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get userAgent => $_getSZ(5);
  @$pb.TagNumber(6)
  set userAgent($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUserAgent() => $_has(5);
  @$pb.TagNumber(6)
  void clearUserAgent() => $_clearField(6);
}

class RecordConsentResponse extends $pb.GeneratedMessage {
  factory RecordConsentResponse({
    $core.String? consentRecordId,
    $2.Timestamp? recordedAt,
  }) {
    final result = create();
    if (consentRecordId != null) result.consentRecordId = consentRecordId;
    if (recordedAt != null) result.recordedAt = recordedAt;
    return result;
  }

  RecordConsentResponse._();

  factory RecordConsentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordConsentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordConsentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'consentRecordId')
    ..aOM<$2.Timestamp>(2, _omitFieldNames ? '' : 'recordedAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordConsentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordConsentResponse copyWith(
          void Function(RecordConsentResponse) updates) =>
      super.copyWith((message) => updates(message as RecordConsentResponse))
          as RecordConsentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordConsentResponse create() => RecordConsentResponse._();
  @$core.override
  RecordConsentResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordConsentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordConsentResponse>(create);
  static RecordConsentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get consentRecordId => $_getSZ(0);
  @$pb.TagNumber(1)
  set consentRecordId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConsentRecordId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConsentRecordId() => $_clearField(1);

  @$pb.TagNumber(2)
  $2.Timestamp get recordedAt => $_getN(1);
  @$pb.TagNumber(2)
  set recordedAt($2.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRecordedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearRecordedAt() => $_clearField(2);
  @$pb.TagNumber(2)
  $2.Timestamp ensureRecordedAt() => $_ensure(1);
}

class CheckEmailExistsRequest extends $pb.GeneratedMessage {
  factory CheckEmailExistsRequest({
    $core.String? email,
  }) {
    final result = create();
    if (email != null) result.email = email;
    return result;
  }

  CheckEmailExistsRequest._();

  factory CheckEmailExistsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckEmailExistsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckEmailExistsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckEmailExistsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckEmailExistsRequest copyWith(
          void Function(CheckEmailExistsRequest) updates) =>
      super.copyWith((message) => updates(message as CheckEmailExistsRequest))
          as CheckEmailExistsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckEmailExistsRequest create() => CheckEmailExistsRequest._();
  @$core.override
  CheckEmailExistsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckEmailExistsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckEmailExistsRequest>(create);
  static CheckEmailExistsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);
}

class CheckEmailExistsResponse extends $pb.GeneratedMessage {
  factory CheckEmailExistsResponse({
    $core.bool? exists,
    $core.bool? isPendingDeletion,
  }) {
    final result = create();
    if (exists != null) result.exists = exists;
    if (isPendingDeletion != null) result.isPendingDeletion = isPendingDeletion;
    return result;
  }

  CheckEmailExistsResponse._();

  factory CheckEmailExistsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckEmailExistsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckEmailExistsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOB(2, _omitFieldNames ? '' : 'exists')
    ..aOB(3, _omitFieldNames ? '' : 'isPendingDeletion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckEmailExistsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckEmailExistsResponse copyWith(
          void Function(CheckEmailExistsResponse) updates) =>
      super.copyWith((message) => updates(message as CheckEmailExistsResponse))
          as CheckEmailExistsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckEmailExistsResponse create() => CheckEmailExistsResponse._();
  @$core.override
  CheckEmailExistsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckEmailExistsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckEmailExistsResponse>(create);
  static CheckEmailExistsResponse? _defaultInstance;

  @$pb.TagNumber(2)
  $core.bool get exists => $_getBF(0);
  @$pb.TagNumber(2)
  set exists($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(2)
  $core.bool hasExists() => $_has(0);
  @$pb.TagNumber(2)
  void clearExists() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isPendingDeletion => $_getBF(1);
  @$pb.TagNumber(3)
  set isPendingDeletion($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(3)
  $core.bool hasIsPendingDeletion() => $_has(1);
  @$pb.TagNumber(3)
  void clearIsPendingDeletion() => $_clearField(3);
}

class CheckPhoneNumberExistsRequest extends $pb.GeneratedMessage {
  factory CheckPhoneNumberExistsRequest({
    $core.String? phoneNumber,
  }) {
    final result = create();
    if (phoneNumber != null) result.phoneNumber = phoneNumber;
    return result;
  }

  CheckPhoneNumberExistsRequest._();

  factory CheckPhoneNumberExistsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckPhoneNumberExistsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckPhoneNumberExistsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'phoneNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckPhoneNumberExistsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckPhoneNumberExistsRequest copyWith(
          void Function(CheckPhoneNumberExistsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as CheckPhoneNumberExistsRequest))
          as CheckPhoneNumberExistsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckPhoneNumberExistsRequest create() =>
      CheckPhoneNumberExistsRequest._();
  @$core.override
  CheckPhoneNumberExistsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckPhoneNumberExistsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckPhoneNumberExistsRequest>(create);
  static CheckPhoneNumberExistsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get phoneNumber => $_getSZ(0);
  @$pb.TagNumber(1)
  set phoneNumber($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPhoneNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhoneNumber() => $_clearField(1);
}

class CheckPhoneNumberExistsResponse extends $pb.GeneratedMessage {
  factory CheckPhoneNumberExistsResponse({
    $core.bool? exists,
  }) {
    final result = create();
    if (exists != null) result.exists = exists;
    return result;
  }

  CheckPhoneNumberExistsResponse._();

  factory CheckPhoneNumberExistsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckPhoneNumberExistsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckPhoneNumberExistsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'exists')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckPhoneNumberExistsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckPhoneNumberExistsResponse copyWith(
          void Function(CheckPhoneNumberExistsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as CheckPhoneNumberExistsResponse))
          as CheckPhoneNumberExistsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckPhoneNumberExistsResponse create() =>
      CheckPhoneNumberExistsResponse._();
  @$core.override
  CheckPhoneNumberExistsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckPhoneNumberExistsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckPhoneNumberExistsResponse>(create);
  static CheckPhoneNumberExistsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get exists => $_getBF(0);
  @$pb.TagNumber(1)
  set exists($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExists() => $_has(0);
  @$pb.TagNumber(1)
  void clearExists() => $_clearField(1);
}

class ResendVerificationEmailRequest extends $pb.GeneratedMessage {
  factory ResendVerificationEmailRequest({
    $core.String? email,
  }) {
    final result = create();
    if (email != null) result.email = email;
    return result;
  }

  ResendVerificationEmailRequest._();

  factory ResendVerificationEmailRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResendVerificationEmailRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResendVerificationEmailRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResendVerificationEmailRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResendVerificationEmailRequest copyWith(
          void Function(ResendVerificationEmailRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ResendVerificationEmailRequest))
          as ResendVerificationEmailRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResendVerificationEmailRequest create() =>
      ResendVerificationEmailRequest._();
  @$core.override
  ResendVerificationEmailRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResendVerificationEmailRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResendVerificationEmailRequest>(create);
  static ResendVerificationEmailRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);
}

class UpdateMyEmailRequest extends $pb.GeneratedMessage {
  factory UpdateMyEmailRequest({
    $core.String? newEmail,
  }) {
    final result = create();
    if (newEmail != null) result.newEmail = newEmail;
    return result;
  }

  UpdateMyEmailRequest._();

  factory UpdateMyEmailRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateMyEmailRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateMyEmailRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'identity.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'newEmail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMyEmailRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMyEmailRequest copyWith(void Function(UpdateMyEmailRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateMyEmailRequest))
          as UpdateMyEmailRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateMyEmailRequest create() => UpdateMyEmailRequest._();
  @$core.override
  UpdateMyEmailRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateMyEmailRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateMyEmailRequest>(create);
  static UpdateMyEmailRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get newEmail => $_getSZ(0);
  @$pb.TagNumber(1)
  set newEmail($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNewEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearNewEmail() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
