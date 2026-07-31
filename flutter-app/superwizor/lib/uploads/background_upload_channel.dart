// BackgroundUploadChannel — cienka warstwa nad dwoma kanałami
// platformowymi z docs/58 §5-6. Projekt jest ASYMETRYCZNY i to jest
// celowe:
//
//   iOS     — bajty oddajemy `nsurlsessiond` (background URLSession).
//             System wiezie je po zawieszeniu procesu i po zabiciu
//             aplikacji przez OS, a potem wznawia nas w tle, żeby
//             dostarczyć callback. Kolejka w Darcie zostaje, ale PUT
//             już nie jest jej robotą.
//   Android — izolat Dart żyje dalej po zejściu w tło, brakuje mu
//             tylko priorytetu procesu (mikrofonowy FGS i wakelock są
//             zwalniane PRZED zakolejkowaniem uploadu). Dajemy więc
//             okno wykonania serwisem typu `dataSync` i nie piszemy
//             tam żadnego natywnego uploadera.
//
// Raport z warstwy natywnej NIE wraca kanałem, a plikiem journala:
// `<docs>/upload_journal/<localId>.json`. Powód jest twardy — iOS
// wznawia aplikację w tle także przy ZABLOKOWANYM urządzeniu, a wtedy
// klucz boxa Hive (Keychain, dostęp po odblokowaniu) jest nieczytelny i
// kolejka nie da się otworzyć. Journal to zwykły plik bez szyfrowania
// i bez PHI — same identyfikatory i status HTTP.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Wynik transferu zgłoszony przez warstwę natywną.
class BackgroundUploadReport {
  final String localId;
  final bool success;
  final int? httpStatus;
  final int? bytesSent;
  final String? error;

  const BackgroundUploadReport({
    required this.localId,
    required this.success,
    this.httpStatus,
    this.bytesSent,
    this.error,
  });

  /// Zwięzły opis do `lastError` na wierszu kolejki.
  String get failureSummary {
    if (httpStatus != null) return 'native upload HTTP $httpStatus';
    return 'native upload: ${error ?? 'nieznany błąd'}';
  }
}

class BackgroundUploadChannel {
  BackgroundUploadChannel({
    MethodChannel? uploadChannel,
    MethodChannel? fgsChannel,
    Future<Directory> Function()? documentsDir,
  })  : _upload = uploadChannel ??
            const MethodChannel('ai.superwizor/background_upload'),
        _fgs = fgsChannel ?? const MethodChannel('ai.superwizor/upload_fgs'),
        _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final MethodChannel _upload;
  final MethodChannel _fgs;
  final Future<Directory> Function() _documentsDir;

  static const _journalDirName = 'upload_journal';

  /// Czy na tej platformie transfer oddajemy systemowi.
  bool get supportsOsHandOff => !kIsWeb && Platform.isIOS;

  /// Czy na tej platformie prosimy o okno wykonania dla runnera.
  bool get supportsForegroundWindow => !kIsWeb && Platform.isAndroid;

  /// Oddaje transfer systemowi. `true` = zadanie utworzone i przyjęte.
  ///
  /// Wołane WYŁĄCZNIE gdy aplikacja jest na foregroundzie — zadanie
  /// utworzone w tle iOS traktuje jako discretionary i odkłada do Wi-Fi
  /// z ładowarką, co przywróciłoby dokładnie ten zwis, który naprawiamy.
  Future<bool> handOff({
    required String localId,
    required String uploadUri,
    required String filePath,
    required String contentType,
    required int totalBytes,
  }) async {
    if (!supportsOsHandOff) return false;
    try {
      final ok = await _upload.invokeMethod<bool>('start', <String, Object>{
        'localId': localId,
        'uploadUri': uploadUri,
        'filePath': filePath,
        'contentType': contentType,
        'totalBytes': totalBytes,
      });
      return ok ?? false;
    } on MissingPluginException {
      // Build bez natywnej części (albo starszy binarny Runner) —
      // spadamy na ścieżkę w Darcie zamiast wywalać upload.
      debugPrint('[bg-upload] brak natywnego uploadera — ścieżka Dart');
      return false;
    } catch (e) {
      debugPrint('[bg-upload] handOff nieudany: $e');
      return false;
    }
  }

  Future<void> cancel(String localId) async {
    if (!supportsOsHandOff) return;
    try {
      await _upload.invokeMethod<bool>('cancel', <String, Object>{
        'localId': localId,
      });
    } catch (e) {
      debugPrint('[bg-upload] cancel nieudany: $e');
    }
  }

  /// localId, dla których system ma jeszcze żywe zadanie. Używane do
  /// rozstrzygnięcia „leasing wisi, ale czy cokolwiek jeszcze jedzie?".
  Future<Set<String>> pendingIds() async {
    if (!supportsOsHandOff) return const <String>{};
    try {
      final ids = await _upload.invokeListMethod<String>('pendingIds');
      return (ids ?? const <String>[]).toSet();
    } catch (e) {
      debugPrint('[bg-upload] pendingIds nieudane: $e');
      return const <String>{};
    }
  }

  /// Czyta i USUWA wszystkie raporty z journala. Dart jest jedynym
  /// czytelnikiem i jedynym, kto kasuje te pliki.
  Future<List<BackgroundUploadReport>> drainJournal() async {
    if (!supportsOsHandOff) return const <BackgroundUploadReport>[];
    final out = <BackgroundUploadReport>[];
    try {
      final dir = Directory('${(await _documentsDir()).path}/$_journalDirName');
      if (!await dir.exists()) return out;
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final raw = await entity.readAsString();
          final j = jsonDecode(raw) as Map<String, dynamic>;
          final localId = j['localId'] as String?;
          if (localId == null || localId.isEmpty) {
            await entity.delete();
            continue;
          }
          out.add(BackgroundUploadReport(
            localId: localId,
            success: (j['state'] as String?) == 'success',
            httpStatus: (j['httpStatus'] as num?)?.toInt(),
            bytesSent: (j['bytesSent'] as num?)?.toInt(),
            error: j['error'] as String?,
          ));
          await entity.delete();
        } catch (e) {
          // Uszkodzony wpis nie może blokować pozostałych ani wieszać
          // rekoncyliacji — kasujemy i idziemy dalej. Leasing wygaśnie
          // po TTL i wiersz wróci do kolejki w Darcie.
          debugPrint('[bg-upload] nieczytelny journal ${entity.path}: $e');
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[bg-upload] drainJournal nieudane: $e');
    }
    return out;
  }

  /// Prosi o okno wykonania (Android: serwis `dataSync`).
  Future<bool> startForegroundWindow(int pendingCount) async {
    if (!supportsForegroundWindow) return false;
    try {
      final ok = await _fgs.invokeMethod<bool>('start', <String, Object>{
        'pendingCount': pendingCount,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      // API 34+ zabrania startu FGS z tła — natywna strona zwraca false,
      // ale wyjątek też jest możliwy. Brak okna nie może wywalić ticka.
      debugPrint('[bg-upload] startForegroundWindow nieudany: $e');
      return false;
    }
  }

  Future<void> stopForegroundWindow() async {
    if (!supportsForegroundWindow) return;
    try {
      await _fgs.invokeMethod<bool>('stop');
    } catch (e) {
      debugPrint('[bg-upload] stopForegroundWindow nieudany: $e');
    }
  }
}
