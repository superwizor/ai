import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/cache/dto/report_dto.dart';
import 'package:superwizor/cache/dto/session_details_dto.dart';

ReportDto _r(String id, {bool eksperyment = false}) => ReportDto(
      id: id,
      title: eksperyment ? '[EKSPERYMENT] Sesja' : 'Sesja',
      summaryShort: '',
      content: '',
      sentimentLabel: '',
      riskLevel: '',
      isExperimental: eksperyment,
    );

void main() {
  group('kolejność raportów', () {
    // Serwer zwraca raporty od najnowszego, a eksperymentalny powstaje PO
    // produkcyjnym (dual-run rusza dopiero po opublikowaniu „gotowe").
    // Bez porządkowania otwarcie sesji pokazywałoby domyślnie eksperyment
    // — materiał, który jawnie nie służy do pracy klinicznej.
    test('produkcyjny idzie pierwszy, choć powstał wcześniej', () {
      final wynik = uporzadkujRaporty([
        _r('eksperyment', eksperyment: true),
        _r('produkcyjny'),
      ]);
      expect(wynik.first.id, 'produkcyjny');
      expect(wynik.last.id, 'eksperyment');
    });

    test('kolejność wewnątrz grupy zostaje z serwera', () {
      final wynik = uporzadkujRaporty([
        _r('e2', eksperyment: true),
        _r('e1', eksperyment: true),
        _r('p2'),
        _r('p1'),
      ]);
      expect(wynik.map((r) => r.id).toList(), ['p2', 'p1', 'e2', 'e1']);
    });

    // Cache zapisany starszą wersją aplikacji nie ma pola isExperimental.
    // Domyślne false ustawia wszystko jako produkcyjne, więc kolejność z
    // serwera zostaje i nic się nie psuje.
    test('brak pola nie zmienia kolejności', () {
      final stary = [
        ReportDto.fromJson({'id': 'a', 'title': 'A'}),
        ReportDto.fromJson({'id': 'b', 'title': 'B'}),
      ];
      final wynik = uporzadkujRaporty(stary);
      expect(wynik.map((r) => r.id).toList(), ['a', 'b']);
      expect(wynik.every((r) => !r.isExperimental), isTrue);
    });

    test('same raporty produkcyjne zostają nietknięte', () {
      final wynik = uporzadkujRaporty([_r('p1'), _r('p2')]);
      expect(wynik.map((r) => r.id).toList(), ['p1', 'p2']);
    });
  });
}
