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

class UserRole extends $pb.ProtobufEnum {
  static const UserRole USER_ROLE_UNSPECIFIED =
      UserRole._(0, _omitEnumNames ? '' : 'USER_ROLE_UNSPECIFIED');
  static const UserRole USER_ROLE_THERAPIST =
      UserRole._(1, _omitEnumNames ? '' : 'USER_ROLE_THERAPIST');
  static const UserRole USER_ROLE_PATIENT =
      UserRole._(2, _omitEnumNames ? '' : 'USER_ROLE_PATIENT');

  /// Web app additions per docs/18 R4. Single-role MVP — a user holds
  /// exactly one role. Org founders are ORG_ADMIN only (cannot record
  /// sessions); to also practise they invite themselves as THERAPIST.
  static const UserRole USER_ROLE_ORG_ADMIN =
      UserRole._(3, _omitEnumNames ? '' : 'USER_ROLE_ORG_ADMIN');
  static const UserRole USER_ROLE_SUPERWIZOR_ADMIN =
      UserRole._(4, _omitEnumNames ? '' : 'USER_ROLE_SUPERWIZOR_ADMIN');

  /// Ekspert kliniczny pracujacy w Ontology Studio (plan 16 v1.2 §4.1).
  /// Tworzy i edytuje wersje ontologii, zatwierdza CUDZE. NIE aktywuje
  /// ich na produkcji — to zostaje przy SUPERWIZOR_ADMIN. Dostep do
  /// panelu ograniczony do sekcji /admin/ontologies.
  static const UserRole USER_ROLE_ONTOLOGY_EDITOR =
      UserRole._(5, _omitEnumNames ? '' : 'USER_ROLE_ONTOLOGY_EDITOR');

  static const $core.List<UserRole> values = <UserRole>[
    USER_ROLE_UNSPECIFIED,
    USER_ROLE_THERAPIST,
    USER_ROLE_PATIENT,
    USER_ROLE_ORG_ADMIN,
    USER_ROLE_SUPERWIZOR_ADMIN,
    USER_ROLE_ONTOLOGY_EDITOR,
  ];

  static final $core.List<UserRole?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static UserRole? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const UserRole._(super.value, super.name);
}

class OrganizationType extends $pb.ProtobufEnum {
  static const OrganizationType ORGANIZATION_TYPE_UNSPECIFIED =
      OrganizationType._(
          0, _omitEnumNames ? '' : 'ORGANIZATION_TYPE_UNSPECIFIED');
  static const OrganizationType ORGANIZATION_TYPE_SOLO =
      OrganizationType._(1, _omitEnumNames ? '' : 'ORGANIZATION_TYPE_SOLO');
  static const OrganizationType ORGANIZATION_TYPE_CLINIC =
      OrganizationType._(2, _omitEnumNames ? '' : 'ORGANIZATION_TYPE_CLINIC');
  static const OrganizationType ORGANIZATION_TYPE_ENTERPRISE =
      OrganizationType._(
          3, _omitEnumNames ? '' : 'ORGANIZATION_TYPE_ENTERPRISE');

  static const $core.List<OrganizationType> values = <OrganizationType>[
    ORGANIZATION_TYPE_UNSPECIFIED,
    ORGANIZATION_TYPE_SOLO,
    ORGANIZATION_TYPE_CLINIC,
    ORGANIZATION_TYPE_ENTERPRISE,
  ];

  static final $core.List<OrganizationType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static OrganizationType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const OrganizationType._(super.value, super.name);
}

class AdminAssignTherapistStatus extends $pb.ProtobufEnum {
  static const AdminAssignTherapistStatus
      ADMIN_ASSIGN_THERAPIST_STATUS_UNSPECIFIED = AdminAssignTherapistStatus._(
          0, _omitEnumNames ? '' : 'ADMIN_ASSIGN_THERAPIST_STATUS_UNSPECIFIED');

  /// The therapist is now a member of the requested organization.
  static const AdminAssignTherapistStatus
      ADMIN_ASSIGN_THERAPIST_STATUS_ASSIGNED = AdminAssignTherapistStatus._(
          1, _omitEnumNames ? '' : 'ADMIN_ASSIGN_THERAPIST_STATUS_ASSIGNED');

  /// Nothing was written. The therapist belongs to another org; the
  /// response carries `transfer_warning` so the admin can see what
  /// moving would drag along, then retry with confirm_transfer=true.
  static const AdminAssignTherapistStatus
      ADMIN_ASSIGN_THERAPIST_STATUS_TRANSFER_CONFIRMATION_REQUIRED =
      AdminAssignTherapistStatus._(
          2,
          _omitEnumNames
              ? ''
              : 'ADMIN_ASSIGN_THERAPIST_STATUS_TRANSFER_CONFIRMATION_REQUIRED');

  static const $core.List<AdminAssignTherapistStatus> values =
      <AdminAssignTherapistStatus>[
    ADMIN_ASSIGN_THERAPIST_STATUS_UNSPECIFIED,
    ADMIN_ASSIGN_THERAPIST_STATUS_ASSIGNED,
    ADMIN_ASSIGN_THERAPIST_STATUS_TRANSFER_CONFIRMATION_REQUIRED,
  ];

  static final $core.List<AdminAssignTherapistStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static AdminAssignTherapistStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AdminAssignTherapistStatus._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
