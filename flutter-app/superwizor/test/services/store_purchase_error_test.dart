// Mapowanie odmów billing-svc na komunikaty (docs/70 E1, E19).
//
// Trzy różne odmowy wracają jako ta sama „odmowa" na poziomie kodu gRPC, a
// wymagają trzech różnych reakcji użytkownika: przelogowania się na inne
// konto, poczekania na konfigurację sklepu albo niczego (sandbox). Sklejenie
// ich w generyczny błąd zostawia człowieka z obciążoną kartą i bez wskazówki.

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:superwizor/services/store_purchase_service.dart';

void main() {
  group('mapVerifyError', () {
    test('transakcja cudzego konta (E1)', () {
      expect(
        mapVerifyError(GrpcError.permissionDenied(
            'TRANSACTION_OWNED_BY_ANOTHER_ACCOUNT')),
        StorePurchaseOutcome.foreignAccount,
      );
    });

    test('brak konfiguracji sklepu po stronie serwera', () {
      expect(
        mapVerifyError(GrpcError.failedPrecondition('STORE_NOT_CONFIGURED')),
        StorePurchaseOutcome.storeNotConfigured,
      );
    });

    test('sandbox poza allowlistą (E19)', () {
      expect(
        mapVerifyError(GrpcError.failedPrecondition('SANDBOX_NOT_ALLOWED')),
        StorePurchaseOutcome.sandboxNotAllowed,
      );
    });

    test('UNIMPLEMENTED = backend bez tego RPC, nie błąd zakupu', () {
      expect(
        mapVerifyError(GrpcError.unimplemented('unknown method')),
        StorePurchaseOutcome.unavailable,
      );
    });

    test('nieznana odmowa spada do nieudanej weryfikacji, nie do sukcesu', () {
      expect(
        mapVerifyError(GrpcError.internal('boom')),
        StorePurchaseOutcome.verificationFailed,
      );
      expect(
        mapVerifyError(GrpcError.permissionDenied('coś nowego')),
        StorePurchaseOutcome.verificationFailed,
      );
    });
  });
}
