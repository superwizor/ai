// Pomiar wgrywania na produkcji (Firebase Performance).
//
// Po co akurat tu: dochodzenie z 13.08.2026 w sprawie trzech sesji
// wiszących w PENDING_UPLOAD trwało godziny, bo o przebiegu transferu nie
// wiedzieliśmy NIC. Sygnaturę „urwało się w połowie" trzeba było
// odtwarzać z zakresu bajtów zwróconego przez sesję wznawialną GCS.
// Ślad wysyłany stąd odpowiada na te pytania wprost: ile bajtów poszło,
// ile było rund bez postępu i czym się skończyło.
//
// Świadomie NIE mierzymy tu treści ani metadanych nagrania — wyłącznie
// wielkości techniczne. Nazwa pliku, identyfikator pacjenta ani cokolwiek
// klinicznego nie może trafić do atrybutów.
//
// Wszystko degraduje się do braku działania, gdy Performance nie jest
// dostępne (web, testy jednostkowe bez Firebase'a, tryb debug). Dzięki
// temu ścieżka wgrywania nie zyskuje nowego trybu awarii — pomiar nigdy
// nie może wywalić transferu.

import 'package:flutter/foundation.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// Uchwyt na trwający pomiar. Wszystkie metody są bezpieczne także
/// wtedy, gdy pomiar się nie uruchomił.
class UploadTrace {
  UploadTrace._(this._trace);

  final Trace? _trace;

  /// Wartość liczbowa, np. liczba wysłanych bajtów.
  void metric(String nazwa, int wartosc) {
    try {
      _trace?.setMetric(nazwa, wartosc);
    } catch (_) {
      // Pomiar nie ma prawa przeszkodzić wgrywaniu.
    }
  }

  /// Etykieta, np. wynik ('completed' / 'stuck' / 'session_gone').
  void attribute(String nazwa, String wartosc) {
    try {
      _trace?.putAttribute(nazwa, wartosc);
    } catch (_) {}
  }
}

/// Obejmuje [body] pomiarem o nazwie [nazwa].
///
/// Zwraca dokładnie to, co [body]; wyjątki przepuszcza bez zmian, ale
/// przed ich wypuszczeniem domyka pomiar, żeby nieudane transfery też
/// były widoczne — to one są tu najciekawsze.
Future<T> traceUpload<T>(
  String nazwa,
  Future<T> Function(UploadTrace) body,
) async {
  Trace? trace;
  if (!kIsWeb) {
    try {
      trace = FirebasePerformance.instance.newTrace(nazwa);
      await trace.start();
    } catch (_) {
      trace = null; // brak Firebase'a (testy) — jedziemy bez pomiaru
    }
  }
  final uchwyt = UploadTrace._(trace);
  try {
    return await body(uchwyt);
  } finally {
    try {
      await trace?.stop();
    } catch (_) {}
  }
}
