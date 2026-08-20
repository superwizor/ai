// This is a generated file - do not edit.
//
// Generated from clinical/v1/clinical.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ProcessType extends $pb.ProtobufEnum {
  static const ProcessType PROCESS_TYPE_UNSPECIFIED =
      ProcessType._(0, _omitEnumNames ? '' : 'PROCESS_TYPE_UNSPECIFIED');
  static const ProcessType PROCESS_TYPE_INDIVIDUAL =
      ProcessType._(1, _omitEnumNames ? '' : 'PROCESS_TYPE_INDIVIDUAL');
  static const ProcessType PROCESS_TYPE_COUPLE =
      ProcessType._(2, _omitEnumNames ? '' : 'PROCESS_TYPE_COUPLE');
  static const ProcessType PROCESS_TYPE_FAMILY =
      ProcessType._(3, _omitEnumNames ? '' : 'PROCESS_TYPE_FAMILY');
  static const ProcessType PROCESS_TYPE_GROUP =
      ProcessType._(4, _omitEnumNames ? '' : 'PROCESS_TYPE_GROUP');

  static const $core.List<ProcessType> values = <ProcessType>[
    PROCESS_TYPE_UNSPECIFIED,
    PROCESS_TYPE_INDIVIDUAL,
    PROCESS_TYPE_COUPLE,
    PROCESS_TYPE_FAMILY,
    PROCESS_TYPE_GROUP,
  ];

  static final $core.List<ProcessType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ProcessType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProcessType._(super.value, super.name);
}

/// ChatIntent mirrors the taxonomy in ADR section 5.4 v1.1. The
/// prohibited categories appear here so a refusal can name what was
/// refused — never so a payload can carry one.
class ChatIntent extends $pb.ProtobufEnum {
  static const ChatIntent CHAT_INTENT_UNSPECIFIED =
      ChatIntent._(0, _omitEnumNames ? '' : 'CHAT_INTENT_UNSPECIFIED');

  /// ALLOWED — extractive
  static const ChatIntent CHAT_INTENT_A1_SEARCH =
      ChatIntent._(1, _omitEnumNames ? '' : 'CHAT_INTENT_A1_SEARCH');
  static const ChatIntent CHAT_INTENT_A2_FACTS =
      ChatIntent._(2, _omitEnumNames ? '' : 'CHAT_INTENT_A2_FACTS');
  static const ChatIntent CHAT_INTENT_A3_FORMAT =
      ChatIntent._(3, _omitEnumNames ? '' : 'CHAT_INTENT_A3_FORMAT');
  static const ChatIntent CHAT_INTENT_A4_EDU =
      ChatIntent._(4, _omitEnumNames ? '' : 'CHAT_INTENT_A4_EDU');
  static const ChatIntent CHAT_INTENT_A5_SUPERVISION_PACK =
      ChatIntent._(5, _omitEnumNames ? '' : 'CHAT_INTENT_A5_SUPERVISION_PACK');
  static const ChatIntent CHAT_INTENT_A6_ADMIN =
      ChatIntent._(6, _omitEnumNames ? '' : 'CHAT_INTENT_A6_ADMIN');
  static const ChatIntent CHAT_INTENT_A7_TEMPLATE_MAP =
      ChatIntent._(7, _omitEnumNames ? '' : 'CHAT_INTENT_A7_TEMPLATE_MAP');

  /// ALLOWED — generative, grounded (decision D1, 2026-08-20)
  static const ChatIntent CHAT_INTENT_A8_CONCEPT =
      ChatIntent._(8, _omitEnumNames ? '' : 'CHAT_INTENT_A8_CONCEPT');
  static const ChatIntent CHAT_INTENT_A9_PROGRESS =
      ChatIntent._(9, _omitEnumNames ? '' : 'CHAT_INTENT_A9_PROGRESS');
  static const ChatIntent CHAT_INTENT_A10_TREAT =
      ChatIntent._(10, _omitEnumNames ? '' : 'CHAT_INTENT_A10_TREAT');

  /// PROHIBITED
  static const ChatIntent CHAT_INTENT_P1_DIAG =
      ChatIntent._(11, _omitEnumNames ? '' : 'CHAT_INTENT_P1_DIAG');
  static const ChatIntent CHAT_INTENT_P2_MED =
      ChatIntent._(12, _omitEnumNames ? '' : 'CHAT_INTENT_P2_MED');
  static const ChatIntent CHAT_INTENT_R_RISK =
      ChatIntent._(13, _omitEnumNames ? '' : 'CHAT_INTENT_R_RISK');
  static const ChatIntent CHAT_INTENT_X_OTHER =
      ChatIntent._(14, _omitEnumNames ? '' : 'CHAT_INTENT_X_OTHER');

  static const $core.List<ChatIntent> values = <ChatIntent>[
    CHAT_INTENT_UNSPECIFIED,
    CHAT_INTENT_A1_SEARCH,
    CHAT_INTENT_A2_FACTS,
    CHAT_INTENT_A3_FORMAT,
    CHAT_INTENT_A4_EDU,
    CHAT_INTENT_A5_SUPERVISION_PACK,
    CHAT_INTENT_A6_ADMIN,
    CHAT_INTENT_A7_TEMPLATE_MAP,
    CHAT_INTENT_A8_CONCEPT,
    CHAT_INTENT_A9_PROGRESS,
    CHAT_INTENT_A10_TREAT,
    CHAT_INTENT_P1_DIAG,
    CHAT_INTENT_P2_MED,
    CHAT_INTENT_R_RISK,
    CHAT_INTENT_X_OTHER,
  ];

  static final $core.List<ChatIntent?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 14);
  static ChatIntent? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ChatIntent._(super.value, super.name);
}

/// ChatOutcome says what the server did, so the client renders the right
/// surface without re-deriving it from which fields are populated.
class ChatOutcome extends $pb.ProtobufEnum {
  static const ChatOutcome CHAT_OUTCOME_UNSPECIFIED =
      ChatOutcome._(0, _omitEnumNames ? '' : 'CHAT_OUTCOME_UNSPECIFIED');
  static const ChatOutcome CHAT_OUTCOME_ANSWERED =
      ChatOutcome._(1, _omitEnumNames ? '' : 'CHAT_OUTCOME_ANSWERED');

  /// Answered, but not the way that was asked: low classifier confidence,
  /// defined_ops mode, or an exhausted quota downgraded the operation.
  static const ChatOutcome CHAT_OUTCOME_DEGRADED =
      ChatOutcome._(2, _omitEnumNames ? '' : 'CHAT_OUTCOME_DEGRADED');

  /// Refused on category grounds (P1/P2/R/X).
  static const ChatOutcome CHAT_OUTCOME_REFUSED =
      ChatOutcome._(3, _omitEnumNames ? '' : 'CHAT_OUTCOME_REFUSED');

  /// The model answered but the verifier blocked the result.
  static const ChatOutcome CHAT_OUTCOME_VERIFIER_BLOCKED =
      ChatOutcome._(4, _omitEnumNames ? '' : 'CHAT_OUTCOME_VERIFIER_BLOCKED');

  /// Chat is switched off (kill switch) for this caller.
  static const ChatOutcome CHAT_OUTCOME_UNAVAILABLE =
      ChatOutcome._(5, _omitEnumNames ? '' : 'CHAT_OUTCOME_UNAVAILABLE');

  static const $core.List<ChatOutcome> values = <ChatOutcome>[
    CHAT_OUTCOME_UNSPECIFIED,
    CHAT_OUTCOME_ANSWERED,
    CHAT_OUTCOME_DEGRADED,
    CHAT_OUTCOME_REFUSED,
    CHAT_OUTCOME_VERIFIER_BLOCKED,
    CHAT_OUTCOME_UNAVAILABLE,
  ];

  static final $core.List<ChatOutcome?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ChatOutcome? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ChatOutcome._(super.value, super.name);
}

/// SectionKind drives presentation AND encodes authorship. Article 50 of
/// the AI Act requires AI-generated clinical material to be marked as
/// such; HYPOTHESIS is the marked kind, USER_ONLY is never model-authored.
class SectionKind extends $pb.ProtobufEnum {
  static const SectionKind SECTION_KIND_UNSPECIFIED =
      SectionKind._(0, _omitEnumNames ? '' : 'SECTION_KIND_UNSPECIFIED');
  static const SectionKind SECTION_KIND_EXTRACT =
      SectionKind._(1, _omitEnumNames ? '' : 'SECTION_KIND_EXTRACT');
  static const SectionKind SECTION_KIND_SUMMARY =
      SectionKind._(2, _omitEnumNames ? '' : 'SECTION_KIND_SUMMARY');
  static const SectionKind SECTION_KIND_STATS =
      SectionKind._(3, _omitEnumNames ? '' : 'SECTION_KIND_STATS');
  static const SectionKind SECTION_KIND_HYPOTHESIS =
      SectionKind._(4, _omitEnumNames ? '' : 'SECTION_KIND_HYPOTHESIS');
  static const SectionKind SECTION_KIND_USER_ONLY =
      SectionKind._(5, _omitEnumNames ? '' : 'SECTION_KIND_USER_ONLY');

  static const $core.List<SectionKind> values = <SectionKind>[
    SECTION_KIND_UNSPECIFIED,
    SECTION_KIND_EXTRACT,
    SECTION_KIND_SUMMARY,
    SECTION_KIND_STATS,
    SECTION_KIND_HYPOTHESIS,
    SECTION_KIND_USER_ONLY,
  ];

  static final $core.List<SectionKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static SectionKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SectionKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
