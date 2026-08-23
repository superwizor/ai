import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/cache/dto/session_details_dto.dart';

void main() {
  group('powód pominięcia raportu', () {
    // Pominięcie zapisuje się WYŁĄCZNIE wtedy, gdy terapeuta miał
    // włączony przełącznik — serwer kończy wcześniej dla wszystkich
    // pozostałych. Sama obecność wartości znaczy więc „spodziewał się
    // drugiego raportu", i to jest cała informacja, jakiej ekran
    // potrzebuje, żeby zdecydować, czy pokazać wyjaśnienie.
    test('powód i szczegół przechodzą przez cache', () {
      const przed = ExperimentalSkipDto(reason: 'daily_limit', detail: '5');
      final po = ExperimentalSkipDto.fromJson(przed.toJson());
      expect(po.reason, 'daily_limit');
      expect(po.detail, '5');
    });

    test('stary cache bez pola nie wywraca odczytu', () {
      final dto = ExperimentalSkipDto.fromJson(<String, dynamic>{});
      expect(dto.reason, isEmpty);
      expect(dto.detail, isEmpty);
    });

    // Sesja bez pominięcia nie może udawać, że coś pominięto — inaczej
    // wyjaśnienie pojawiłoby się pod każdym raportem, także tam, gdzie
    // drugiego nikt się nie spodziewał.
    test('brak klucza w cache daje null, nie pusty obiekt', () {
      final dto = SessionDetailsDto.fromJson({
        'session': <String, dynamic>{
          'id': 's1',
          'createdAt': '2026-08-23T10:00:00Z',
        },
        'transcript': <String, dynamic>{
          'id': 't1',
          'createdAt': '2026-08-23T10:00:00Z',
        },
        'reports': <dynamic>[],
      });
      expect(dto.experimentalSkip, isNull);
    });
  });
}
