// Error classification for the upload pipeline. The worker uses this
// to decide between three outcomes after an UploadIo call throws:
//
//   • retryable    → schedule another attempt with backoff
//   • signedUrlExpired → clear uploadId + signedUrl, re-run
//                        CreateAudioUpload on next tick (same
//                        idempotencyKey returns the same uploadId
//                        + a fresh signedUrl)
//   • terminal     → mark the row failed; the user must intervene
//
// We're conservative: anything we don't recognize is retryable.
// Worst-case is wasted attempts on a permanent error — the
// max-age sweep (7 days) eventually reaps it. The opposite mistake
// (silently giving up on a transient blip) is a lost recording,
// which we never want.

import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart' as grpc;
import 'package:http/http.dart' as http;

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
      // Programmer error / server-state mismatch — retrying won't
      // help. The MP3 / FAILED_PRECONDITION bug we shipped a fix
      // for last week is the canonical example.
      case grpc.StatusCode.failedPrecondition:
      case grpc.StatusCode.invalidArgument:
      case grpc.StatusCode.notFound:
      case grpc.StatusCode.permissionDenied:
      case grpc.StatusCode.unauthenticated:
      case grpc.StatusCode.alreadyExists:
      case grpc.StatusCode.outOfRange:
      case grpc.StatusCode.unimplemented:
        return ClassifiedError(UploadErrorClass.terminal, msg);

      // Transient — retry with backoff.
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
      // Signed URL expired or unauthorized — refresh and retry.
      // GCS signed URLs return 403 SignatureDoesNotMatch /
      // ExpiredToken; 410 Gone for resumable-session-style URLs.
      return ClassifiedError(UploadErrorClass.signedUrlExpired, msg);
    }
    if (s >= 500) return ClassifiedError(UploadErrorClass.retryable, msg);
    // Any other 4xx (400 bad request, 404, 413 payload too large,
    // etc.) is terminal — re-uploading the same bytes won't fix it.
    return ClassifiedError(UploadErrorClass.terminal, msg);
  }

  // ── Network plumbing ────────────────────────────────────────
  if (error is SocketException ||
      error is HttpException ||
      error is http.ClientException ||
      error is TimeoutException ||
      error is HandshakeException) {
    return ClassifiedError(
        UploadErrorClass.retryable, 'network: ${error.runtimeType} $error');
  }

  // ── Default: be conservative, retry ─────────────────────────
  return ClassifiedError(UploadErrorClass.retryable, error.toString());
}

/// Thin wrapper UploadIo implementations throw when they need to
/// surface an HTTP status code separately from the body. Keeping it
/// here avoids leaking the http package's StreamedResponse type into
/// the worker's classification table.
class _HttpStatusError implements Exception {
  final int statusCode;
  final String body;
  const _HttpStatusError(this.statusCode, this.body);
  @override
  String toString() => 'HTTP $statusCode';
}

/// Public factory so UploadIo implementations can construct the
/// internal HTTP-status error without exposing the class itself.
Exception httpStatusError(int statusCode, [String body = '']) =>
    _HttpStatusError(statusCode, body);
