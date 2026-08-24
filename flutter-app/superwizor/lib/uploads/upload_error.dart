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

  /// Quota exhausted — billing has no tokens left for this org.
  /// Surfaced as gRPC ResourceExhausted ("QUOTA_EXHAUSTED") from
  /// CreateAudioUpload's ReserveCredit. We do NOT auto-retry these:
  /// hammering CreateAudioUpload every 30 min won't conjure tokens,
  /// and the old behavior (retryable) produced the "próba 7/4"
  /// runaway. The worker parks the row (phase=quotaBlocked) and the
  /// UI offers an explicit resend / cancel. See pending_upload.dart.
  quotaBlocked,
}

class ClassifiedError {
  final UploadErrorClass kind;
  final String message;
  const ClassifiedError(this.kind, this.message);
}

/// Wrapper an UploadIo implementation throws when an attempt ultimately
/// failed BUT moved bytes forward first (the GCS resumable offset
/// advanced). The worker unwraps it and resets attemptCount before
/// classifying [cause]: escalating backoff is for attempts stuck at the
/// same offset, not for a 127 MB transfer that keeps making progress
/// between network blips.
class UploadProgressMadeError implements Exception {
  final Object cause;
  const UploadProgressMadeError(this.cause);
  @override
  String toString() => 'UploadProgressMadeError($cause)';
}

ClassifiedError classifyUploadError(Object error) {
  // Defensive unwrap — the worker normally strips this before
  // classifying, but a future call site shouldn't misroute into the
  // catch-all retryable branch with a useless message.
  if (error is UploadProgressMadeError) {
    return classifyUploadError(error.cause);
  }
  // ── gRPC ────────────────────────────────────────────────────
  if (error is grpc.GrpcError) {
    final msg = 'gRPC ${error.codeName}: ${error.message ?? ''}';
    switch (error.code) {
      // Billing preconditions (SUBSCRIPTION_INACTIVE / _PAST_DUE /
      // QUOTA_COUNTER_MISSING from ReserveCredit via CreateAudioUpload)
      // are the same UX as quota exhausted: park, don't fail. Before
      // this branch they fell into `terminal` and the user saw the
      // generic "Przesyłanie przerwane" (2026-07 incident) instead of
      // the subscription/quota sheet. Other FAILED_PRECONDITIONs (e.g.
      // the MP3 content-type mismatch) stay terminal below.
      case grpc.StatusCode.failedPrecondition
          when (error.message ?? '').contains('SUBSCRIPTION_') ||
              (error.message ?? '').contains('QUOTA_COUNTER_MISSING'):
        return ClassifiedError(UploadErrorClass.quotaBlocked, msg);

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

      // Quota exhausted — billing reservation refused. Park, don't
      // retry. ingestion-svc.CreateAudioUpload returns this (via
      // billing-svc ReserveCredit) with message "QUOTA_EXHAUSTED"
      // when the org is out of tokens.
      case grpc.StatusCode.resourceExhausted:
        return ClassifiedError(UploadErrorClass.quotaBlocked, msg);

      // Transient — retry with backoff.
      case grpc.StatusCode.unavailable:
      case grpc.StatusCode.deadlineExceeded:
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
      // 410 Gone for resumable-session-style URLs.
      return ClassifiedError(UploadErrorClass.signedUrlExpired, msg);
    }
    // GCS V4 signed URLs return HTTP **400** with body
    // `<Code>ExpiredToken</Code>` (or `SignatureDoesNotMatch`) on
    // signature expiration — empirically confirmed from Marcin's
    // 111.7 MB upload on 2026-05-22:
    //   HTTP 400: <?xml version='1.0' encoding='UTF-8'?>
    //   <Error><Code>ExpiredToken</Code><Message>Invalid
    //   argument.</Message><Details>The provided token has exp…
    // Pre-fix the classifier dropped this into `terminal`, the UI
    // showed "Błąd / Ponów / Anuluj", and Ponów retried with the
    // SAME expired URL → same 400 → permanent stuck state. We
    // inspect the body so genuinely-bad-request 400s (object size
    // mismatch, malformed body) still terminate, while expired
    // tokens correctly route into the refresh-and-retry path.
    if (s == 400 &&
        (error.body.contains('<Code>ExpiredToken</Code>') ||
            error.body.contains('<Code>SignatureDoesNotMatch</Code>'))) {
      return ClassifiedError(UploadErrorClass.signedUrlExpired, msg);
    }
    if (s >= 500) return ClassifiedError(UploadErrorClass.retryable, msg);
    // Any other 4xx (genuine 400 bad request, 404, 413 payload too
    // large, etc.) is terminal — re-uploading the same bytes won't
    // fix it.
    return ClassifiedError(UploadErrorClass.terminal, msg);
  }

  // ── Filesystem ──────────────────────────────────────────────
  // Missing source file is TERMINAL, not retryable. The runner already
  // ran _repairContainerPath (iOS container-UUID rotation) before the
  // worker touched the row — if the file still isn't there, no number
  // of retries will conjure it back. Pre-fix this fell into the
  // retryable catch-all and a row spun "Wznawianie… próba 26" forever
  // while the home banner promised "Nagranie jest bezpieczne"
  // (incydent Marcin Krzys, 2026-08-24). Other FileSystemExceptions
  // (disk full, EBUSY) stay retryable below — only a confirmed-absent
  // path is hopeless.
  if (error is PathNotFoundException) {
    return ClassifiedError(
      UploadErrorClass.terminal,
      'source_file_missing: ${error.path ?? error.message}',
    );
  }

  // ── Network plumbing ────────────────────────────────────────
  if (error is SocketException ||
      error is HttpException ||
      error is http.ClientException ||
      error is TimeoutException ||
      error is HandshakeException) {
    return ClassifiedError(
      UploadErrorClass.retryable,
      'network: ${error.runtimeType} $error',
    );
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
