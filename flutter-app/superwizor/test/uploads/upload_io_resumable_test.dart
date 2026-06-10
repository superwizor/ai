// GCS resumable-transfer semantics in GrpcUploadIo.putBytes
// (docs/26 R2, fix/upload-stall-resilience).
//
// A fake in-memory GCS session plays the resumable protocol: offset
// probes (`bytes */total`), 308 + Range acks per chunk, 200 on the
// final chunk. Tests drive the failure paths the real network
// produces — transient socket drops mid-transfer, partially-acked
// chunks, dead sessions — and assert the in-attempt retry loop,
// progress reporting, and error escalation contracts.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:superwizor/generated/ingestion/v1/ingestion.pbgrpc.dart'
    as ingestion_grpc;
import 'package:superwizor/services/secure_audio_storage_service.dart';
import 'package:superwizor/uploads/pending_upload.dart';
import 'package:superwizor/uploads/upload_error.dart';
import 'package:superwizor/uploads/upload_io_grpc.dart';

const int _kib = 1024;
const int _chunk = 256 * _kib; // test chunk size (GCS 256 KiB quantum)

/// Stateful fake of one GCS resumable session.
class _FakeGcs {
  _FakeGcs({required this.total});

  final int total;
  int acked = 0;
  int chunkPuts = 0;
  int offsetQueries = 0;

  /// 1-based chunk-PUT indices that throw [error] instead of acking.
  bool Function(int chunkPutIndex)? failWhen;
  Object error = const SocketException('simulated drop');

  /// Bytes GCS keeps from a failed chunk before the "connection died"
  /// (the partially-acked-chunk case the offset re-query must absorb).
  int ackBeforeThrow = 0;

  /// When true every chunk PUT answers 410 — session expired/deleted.
  bool sessionGone = false;

  Future<http.Response> call(http.Request req) async {
    final cr = req.headers['content-range'] ?? '';
    if (cr.startsWith('bytes */')) {
      offsetQueries++;
      if (acked >= total) return http.Response('', 200);
      return http.Response('', 308, headers: _rangeHeaders());
    }
    chunkPuts++;
    if (sessionGone) return http.Response('', 410);
    final m = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(cr)!;
    final start = int.parse(m.group(1)!);
    final endIncl = int.parse(m.group(2)!);
    expect(start, acked, reason: 'client must PUT from the acked offset');
    expect(req.bodyBytes.length, endIncl - start + 1,
        reason: 'body must match the Content-Range');
    if (failWhen?.call(chunkPuts) ?? false) {
      acked = math.min(total, acked + ackBeforeThrow);
      throw error;
    }
    acked = endIncl + 1;
    if (acked >= total) return http.Response('', 200);
    return http.Response('', 308, headers: _rangeHeaders());
  }

  Map<String, String> _rangeHeaders() =>
      acked > 0 ? {'range': 'bytes=0-${acked - 1}'} : const {};
}

GrpcUploadIo _io(http.Client client) => GrpcUploadIo(
      // Never dialed — putBytes talks HTTP only. Constructing a channel
      // does not connect.
      ingestion: ingestion_grpc.IngestionServiceClient(grpc.ClientChannel(
        'unused-in-test',
        port: 1,
        options: const grpc.ChannelOptions(
            credentials: grpc.ChannelCredentials.insecure()),
      )),
      secureStorage: SecureAudioStorageService(),
      httpClient: client,
      chunkRetryDelay: (_) => Duration.zero, // tests must not sleep
      maxStuckRounds: 2,
    );

void main() {
  late Directory tmp;
  late File source;

  PendingUpload row({String? resumableUri, String? signedUrl}) =>
      PendingUpload.initial(
        localId: 'l1',
        therapistId: 'th',
        patientFileId: 'pf',
        patientLanguageCode: 'pl-PL',
        sourceKind: UploadSourceKind.plainFile,
        sourcePath: source.path,
        contentType: 'audio/flac',
        sizeBytes: 600 * _kib,
        chunkCount: 1,
        actualDurationSeconds: 60,
        needsServerSideConversion: false,
        idempotencyKey: 'idem-1',
        now: DateTime.now().toUtc(),
      ).copyWith(
        phase: UploadPhase.created,
        uploadId: 'au-1',
        signedUrl: signedUrl,
        resumableSessionUri: resumableUri,
        resumableChunkSize: _chunk,
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('upload_io_test_');
    source = File(p.join(tmp.path, 'raw.flac'));
    await source.writeAsBytes(List.filled(600 * _kib, 7)); // 3 chunks: 256+256+88
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('happy path', () {
    test('uploads in chunks; progress rises monotonically to 1.0', () async {
      final gcs = _FakeGcs(total: 600 * _kib);
      final io = _io(MockClient(gcs.call));
      final progress = <double>[];

      await io.putBytes(row(resumableUri: 'https://gcs/session'),
          onProgress: progress.add);

      expect(gcs.acked, 600 * _kib);
      expect(gcs.chunkPuts, 3);
      expect(gcs.offsetQueries, 1, reason: 'no failures → one initial probe');
      expect(progress.first, 0.0, reason: 'resume position reported up front');
      expect(progress.last, 1.0);
      expect(progress.length, greaterThan(5),
          reason: 'intra-chunk slices must report, not just per-chunk acks');
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]),
            reason: 'progress must never move backwards on the happy path');
      }
    });

    test('resumes from the GCS-acked offset and reports it immediately',
        () async {
      final gcs = _FakeGcs(total: 600 * _kib)..acked = _chunk;
      final io = _io(MockClient(gcs.call));
      final progress = <double>[];

      await io.putBytes(row(resumableUri: 'https://gcs/session'),
          onProgress: progress.add);

      expect(progress.first, closeTo(_chunk / (600 * _kib), 1e-9),
          reason: 'the bar must jump to the resume offset before any chunk');
      expect(gcs.chunkPuts, 2, reason: 'first 256 KiB never re-sent');
      expect(gcs.acked, 600 * _kib);
    });

    test('object already complete → no chunk PUTs, progress 1.0', () async {
      final gcs = _FakeGcs(total: 600 * _kib)..acked = 600 * _kib;
      final io = _io(MockClient(gcs.call));
      final progress = <double>[];

      await io.putBytes(row(resumableUri: 'https://gcs/session'),
          onProgress: progress.add);

      expect(gcs.chunkPuts, 0);
      expect(progress, [1.0]);
    });
  });

  group('in-attempt retry (docs/26 R2)', () {
    test('one transient drop retries locally and completes', () async {
      final gcs = _FakeGcs(total: 600 * _kib)..failWhen = (i) => i == 1;
      final io = _io(MockClient(gcs.call));

      await io.putBytes(row(resumableUri: 'https://gcs/session'));

      expect(gcs.acked, 600 * _kib, reason: 'attempt must survive the blip');
      expect(gcs.chunkPuts, 4, reason: '1 failed + 3 succeeded');
      expect(gcs.offsetQueries, 2, reason: 'initial probe + post-failure probe');
    });

    test('partially-acked failed chunk resumes from the re-queried offset',
        () async {
      final gcs = _FakeGcs(total: 600 * _kib)
        ..failWhen = ((i) => i == 1)
        ..ackBeforeThrow = 128 * _kib; // half the chunk landed before the drop
      final io = _io(MockClient(gcs.call));
      final progress = <double>[];

      await io.putBytes(row(resumableUri: 'https://gcs/session'),
          onProgress: progress.add);

      expect(gcs.acked, 600 * _kib);
      expect(progress, contains(closeTo(128 * _kib / (600 * _kib), 1e-9)),
          reason: 'post-failure probe must surface the partial ack');
    });

    test('zero-progress rounds exhaust and rethrow the raw network error',
        () async {
      final gcs = _FakeGcs(total: 600 * _kib)..failWhen = (_) => true;
      final io = _io(MockClient(gcs.call));

      await expectLater(
        io.putBytes(row(resumableUri: 'https://gcs/session')),
        throwsA(isA<SocketException>()),
      );
      // maxStuckRounds=2 → initial try + 2 zero-progress retries.
      expect(gcs.chunkPuts, 3);
    });

    test('failure after forward progress escalates as UploadProgressMadeError',
        () async {
      // Chunk 1 lands, everything after dies: the worker must learn that
      // bytes moved so it resets its backoff ladder instead of treating
      // this like the 3rd consecutive dead attempt.
      final gcs = _FakeGcs(total: 600 * _kib)..failWhen = (i) => i >= 2;
      final io = _io(MockClient(gcs.call));

      Object? caught;
      try {
        await io.putBytes(row(resumableUri: 'https://gcs/session'));
        fail('expected a throw');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<UploadProgressMadeError>());
      final cause = (caught as UploadProgressMadeError).cause;
      expect(cause, isA<SocketException>());
      expect(classifyUploadError(caught).kind, UploadErrorClass.retryable,
          reason: 'classifier must unwrap to the cause');
      expect(gcs.acked, _chunk, reason: 'chunk 1 stays acked for the resume');
    });

    test('dead session (410) propagates immediately — no local retries',
        () async {
      final gcs = _FakeGcs(total: 600 * _kib)..sessionGone = true;
      final io = _io(MockClient(gcs.call));

      Object? caught;
      try {
        await io.putBytes(row(resumableUri: 'https://gcs/session'));
        fail('expected a throw');
      } catch (e) {
        caught = e;
      }
      expect(classifyUploadError(caught).kind,
          UploadErrorClass.signedUrlExpired,
          reason: 'worker must re-run CreateAudioUpload for a new session');
      expect(gcs.chunkPuts, 1,
          reason: 'retrying a dead session locally is wasted time');
    });
  });

  group('single-PUT fallback (no resumable session)', () {
    test('streams the body with intra-body progress and a 2xx terminates',
        () async {
      String? contentType;
      var puts = 0;
      final client = MockClient((req) async {
        puts++;
        contentType = req.headers['content-type'];
        expect(req.bodyBytes.length, 600 * _kib);
        return http.Response('', 200);
      });
      final io = _io(client);
      final progress = <double>[];

      await io.putBytes(row(signedUrl: 'https://signed/legacy'),
          onProgress: progress.add);

      expect(puts, 1);
      expect(contentType, 'audio/flac');
      expect(progress.last, 1.0);
      expect(progress.length, greaterThan(5),
          reason: 'fallback path must also report intra-body progress');
    });
  });
}
