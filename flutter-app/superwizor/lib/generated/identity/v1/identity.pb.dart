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
}

class UpdateProfileRequest extends $pb.GeneratedMessage {
  factory UpdateProfileRequest({
    $core.String? userId,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? professionalTitle,
    $core.String? credentialsNumber,
    $core.String? biography,
    $core.String? phoneNumber,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (professionalTitle != null) result.professionalTitle = professionalTitle;
    if (credentialsNumber != null) result.credentialsNumber = credentialsNumber;
    if (biography != null) result.biography = biography;
    if (phoneNumber != null) result.phoneNumber = phoneNumber;
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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
