// Error classification for the upload pipeline — Web implementation.
//
// On Web, dart:io exceptions (SocketException, HttpException,
// HandshakeException) don't exist. Network errors surface as
// http.ClientException instead. The core logic is identical but
// the dart:io type checks are omitted.

import 'dart:async';

import 'package:grpc/grpc.dart' as grpc;
import 'package:http/http.dart' as http;

import '../services/secure_audio_types.dart';

enum UploadErrorClass {
  retryable,
  signedUrlExpired,
  terminal,
}

class ClassifiedError {
  final UploadErrorClass kind;
  final String message;
  const ClassifiedError(this.kind, this.message);
}

ClassifiedError classifyUploadError(Object error) {
  // ── gRPC ────────────────────────────────────────────────────
  if (error is grpc.GrpcError) {
    final msg = 'gRPC ${error.codeName}: ${error.message ?? ''}';
    switch (error.code) {
      case grpc.StatusCode.failedPrecondition:
      case grpc.StatusCode.invalidArgument:
      case grpc.StatusCode.notFound:
      case grpc.StatusCode.permissionDenied:
      case grpc.StatusCode.unauthenticated:
      case grpc.StatusCode.alreadyExists:
      case grpc.StatusCode.outOfRange:
      case grpc.StatusCode.unimplemented:
        return ClassifiedError(UploadErrorClass.terminal, msg);

      case grpc.StatusCode.unavailable:
      case grpc.StatusCode.deadlineExceeded:
      case grpc.StatusCode.resourceExhausted:
      case grpc.StatusCode.aborted:
      case grpc.StatusCode.internal:
      case grpc.StatusCode.unknown:
      case grpc.StatusCode.dataLoss:
      case grpc.StatusCode.cancelled:
      default:
        return ClassifiedError(UploadErrorClass.retryable, msg);
    }
  }

  // ── HTTP (PUT to signed URL) ────────────────────────────────
  if (error is _HttpStatusError) {
    final s = error.statusCode;
    final msg = 'HTTP $s: ${error.body}';
    if (s == 403 || s == 410 || s == 401) {
      return ClassifiedError(UploadErrorClass.signedUrlExpired, msg);
    }
    if (s == 400 &&
        (error.body.contains('<Code>ExpiredToken</Code>') ||
            error.body.contains('<Code>SignatureDoesNotMatch</Code>'))) {
      return ClassifiedError(UploadErrorClass.signedUrlExpired, msg);
    }
    if (s >= 500) return ClassifiedError(UploadErrorClass.retryable, msg);
    return ClassifiedError(UploadErrorClass.terminal, msg);
  }

  // ── Network plumbing (Web: no dart:io types) ────────────────
  if (error is http.ClientException || error is TimeoutException) {
    return ClassifiedError(
        UploadErrorClass.retryable, 'network: ${error.runtimeType} $error');
  }

  // ── Integrity violation (F-03) ──────────────────────────────
  if (error is IntegrityViolation) {
    return ClassifiedError(UploadErrorClass.terminal,
        'integrity: ${error.message}');
  }

  // ── Default: be conservative, retry ─────────────────────────
  return ClassifiedError(UploadErrorClass.retryable, error.toString());
}

class _HttpStatusError implements Exception {
  final int statusCode;
  final String body;
  const _HttpStatusError(this.statusCode, this.body);
  @override
  String toString() => 'HTTP $statusCode';
}

Exception httpStatusError(int statusCode, [String body = '']) =>
    _HttpStatusError(statusCode, body);
