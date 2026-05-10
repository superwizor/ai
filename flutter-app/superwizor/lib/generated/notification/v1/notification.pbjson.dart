// This is a generated file - do not edit.
//
// Generated from notification/v1/notification.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use platformDescriptor instead')
const Platform$json = {
  '1': 'Platform',
  '2': [
    {'1': 'PLATFORM_UNSPECIFIED', '2': 0},
    {'1': 'PLATFORM_IOS', '2': 1},
    {'1': 'PLATFORM_ANDROID', '2': 2},
    {'1': 'PLATFORM_WEB', '2': 3},
  ],
};

/// Descriptor for `Platform`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List platformDescriptor = $convert.base64Decode(
    'CghQbGF0Zm9ybRIYChRQTEFURk9STV9VTlNQRUNJRklFRBAAEhAKDFBMQVRGT1JNX0lPUxABEh'
    'QKEFBMQVRGT1JNX0FORFJPSUQQAhIQCgxQTEFURk9STV9XRUIQAw==');

@$core.Deprecated('Use registerFCMTokenRequestDescriptor instead')
const RegisterFCMTokenRequest$json = {
  '1': 'RegisterFCMTokenRequest',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {
      '1': 'platform',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.notification.v1.Platform',
      '10': 'platform'
    },
    {'1': 'app_version', '3': 3, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'device_model', '3': 4, '4': 1, '5': 9, '10': 'deviceModel'},
    {'1': 'locale', '3': 5, '4': 1, '5': 9, '10': 'locale'},
  ],
};

/// Descriptor for `RegisterFCMTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerFCMTokenRequestDescriptor = $convert.base64Decode(
    'ChdSZWdpc3RlckZDTVRva2VuUmVxdWVzdBIUCgV0b2tlbhgBIAEoCVIFdG9rZW4SNQoIcGxhdG'
    'Zvcm0YAiABKA4yGS5ub3RpZmljYXRpb24udjEuUGxhdGZvcm1SCHBsYXRmb3JtEh8KC2FwcF92'
    'ZXJzaW9uGAMgASgJUgphcHBWZXJzaW9uEiEKDGRldmljZV9tb2RlbBgEIAEoCVILZGV2aWNlTW'
    '9kZWwSFgoGbG9jYWxlGAUgASgJUgZsb2NhbGU=');

@$core.Deprecated('Use registerFCMTokenResponseDescriptor instead')
const RegisterFCMTokenResponse$json = {
  '1': 'RegisterFCMTokenResponse',
  '2': [
    {'1': 'token_id', '3': 1, '4': 1, '5': 9, '10': 'tokenId'},
    {
      '1': 'already_registered',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'alreadyRegistered'
    },
  ],
};

/// Descriptor for `RegisterFCMTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerFCMTokenResponseDescriptor =
    $convert.base64Decode(
        'ChhSZWdpc3RlckZDTVRva2VuUmVzcG9uc2USGQoIdG9rZW5faWQYASABKAlSB3Rva2VuSWQSLQ'
        'oSYWxyZWFkeV9yZWdpc3RlcmVkGAIgASgIUhFhbHJlYWR5UmVnaXN0ZXJlZA==');

@$core.Deprecated('Use removeFCMTokenRequestDescriptor instead')
const RemoveFCMTokenRequest$json = {
  '1': 'RemoveFCMTokenRequest',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `RemoveFCMTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeFCMTokenRequestDescriptor =
    $convert.base64Decode(
        'ChVSZW1vdmVGQ01Ub2tlblJlcXVlc3QSFAoFdG9rZW4YASABKAlSBXRva2Vu');

@$core.Deprecated('Use getUnreadCountResponseDescriptor instead')
const GetUnreadCountResponse$json = {
  '1': 'GetUnreadCountResponse',
  '2': [
    {'1': 'count', '3': 1, '4': 1, '5': 5, '10': 'count'},
  ],
};

/// Descriptor for `GetUnreadCountResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUnreadCountResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRVbnJlYWRDb3VudFJlc3BvbnNlEhQKBWNvdW50GAEgASgFUgVjb3VudA==');

@$core.Deprecated('Use healthCheckResponseDescriptor instead')
const HealthCheckResponse$json = {
  '1': 'HealthCheckResponse',
  '2': [
    {'1': 'ok', '3': 1, '4': 1, '5': 8, '10': 'ok'},
    {'1': 'version', '3': 2, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `HealthCheckResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List healthCheckResponseDescriptor = $convert.base64Decode(
    'ChNIZWFsdGhDaGVja1Jlc3BvbnNlEg4KAm9rGAEgASgIUgJvaxIYCgd2ZXJzaW9uGAIgASgJUg'
    'd2ZXJzaW9u');
