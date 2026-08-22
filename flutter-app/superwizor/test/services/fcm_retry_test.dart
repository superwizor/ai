// Ponawianie rejestracji tokenu FCM.
//
// Kontekst: do 22.08.2026 rejestracja odpalała się raz w życiu konta (z
// ekranu konfiguracji), a pojedyncza porażka RPC była połykana do
// debugPrint. Terapeuta zostawał bez powiadomień i nic tego nie
// naprawiało — log produkcyjny z 21.08: "therapist has no active FCM
// tokens — skipping push".

import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/services/fcm_token_service.dart';

void main() {
  const delays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
  ];

  test('sukces za pierwszym razem nie śpi ani razu', () async {
    var calls = 0;
    final spane = <Duration>[];
    var udane = false;

    await retryQuietly(
      () async => calls++,
      delays: delays,
      onSuccess: () => udane = true,
      sleep: (d) async => spane.add(d),
    );

    expect(calls, 1);
    expect(spane, isEmpty);
    expect(udane, isTrue);
  });

  test('ponawia po każdym odstępie i kończy sukcesem', () async {
    var calls = 0;
    final spane = <Duration>[];

    await retryQuietly(
      () async {
        calls++;
        if (calls < 3) throw StateError('brak sieci');
      },
      delays: delays,
      sleep: (d) async => spane.add(d),
    );

    expect(calls, 3);
    expect(spane, [delays[0], delays[1]],
        reason: 'odstępy muszą iść po kolei, bez pomijania');
  });

  test('liczba prób to delays.length + 1, nie delays.length', () async {
    var calls = 0;
    Object? bladKoncowy;
    int? zgloszoneProby;

    await retryQuietly(
      () async {
        calls++;
        throw StateError('trwała awaria');
      },
      delays: delays,
      onGiveUp: (e, n) {
        bladKoncowy = e;
        zgloszoneProby = n;
      },
      sleep: (_) async {},
    );

    expect(calls, delays.length + 1,
        reason: 'pierwsza próba nie jest ponowieniem');
    expect(zgloszoneProby, delays.length + 1);
    expect(bladKoncowy, isA<StateError>());
  });

  test('trwała awaria NIE rzuca — start aplikacji nie może paść', () async {
    await expectLater(
      retryQuietly(
        () async => throw Exception('backend leży'),
        delays: const [Duration(milliseconds: 1)],
        sleep: (_) async {},
      ),
      completes,
    );
  });

  test('pusta lista odstępów = jedna próba, bez pętli', () async {
    var calls = 0;
    await retryQuietly(
      () async {
        calls++;
        throw StateError('x');
      },
      delays: const [],
      sleep: (_) async {},
    );
    expect(calls, 1);
  });
}
