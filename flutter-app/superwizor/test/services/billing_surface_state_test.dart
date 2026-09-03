// Testy powierzchni handlowej (docs/70 §5.1, §7.2).
//
// Sedno: ten model odpowiada na pytanie „czy wolno pokazać przycisk zakupu".
// Fałszywe „tak" to przycisk, który prowadzi donikąd albo — gorzej — łamie
// wytyczne sklepu. Dlatego każda ścieżka niepewności musi kończyć się „nie".

import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/services/billing_surface_state.dart';

void main() {
  group('parseBlockReason', () {
    test('rozpoznaje wszystkie powody z kontraktu billing-svc', () {
      expect(parseBlockReason('IAP_DISABLED'), PurchaseBlockReason.iapDisabled);
      expect(parseBlockReason('ORG_MANAGED'), PurchaseBlockReason.orgManaged);
      expect(parseBlockReason('OTHER_PROVIDER_ACTIVE'),
          PurchaseBlockReason.otherProviderActive);
      expect(parseBlockReason('PENDING_CHECKOUT'),
          PurchaseBlockReason.pendingCheckout);
      expect(parseBlockReason('ACCOUNT_INACTIVE'),
          PurchaseBlockReason.accountInactive);
    });

    test('puste = brak blokady', () {
      expect(parseBlockReason(''), isNull);
    });

    test('nieznany powód NIE odblokowuje sprzedaży', () {
      // Serwer może dorzucić nowy kod przed wydaniem nowej aplikacji.
      // Stary klient musi go potraktować jak blokadę, nie jak brak blokady.
      expect(parseBlockReason('SOME_FUTURE_REASON'),
          PurchaseBlockReason.unknown);
    });
  });

  group('parseWebLinkMode', () {
    test('rozpoznaje tryby', () {
      expect(parseWebLinkMode('TEXT'), WebLinkMode.text);
      expect(parseWebLinkMode('LINK'), WebLinkMode.link);
      expect(parseWebLinkMode('NONE'), WebLinkMode.none);
    });

    test('nieznana wartość spada do NONE — najbezpieczniejszego trybu', () {
      // Wzmianka o zakupie poza aplikacją bez pewności, że wolno, to
      // ryzyko odrzucenia wydania. Milczenie nigdy nie jest naruszeniem.
      expect(parseWebLinkMode('WHATEVER'), WebLinkMode.none);
      expect(parseWebLinkMode(''), WebLinkMode.none);
    });
  });

  group('commerceEnabled', () {
    StoreProductOffer offer(String cycle) => StoreProductOffer(
          productId: 'ai.superwizor.pro.$cycle',
          planTier: 'PRO',
          planCycle: cycle,
          tokensPerPeriod: 30,
        );

    test('brak odpowiedzi serwera = brak sprzedaży', () {
      const s = BillingSurfaceState.unavailable();
      expect(s.commerceEnabled, isFalse);
      expect(s.showRestore, isFalse);
    });

    test('can_purchase = false wyłącza sprzedaż mimo produktów', () {
      final s = BillingSurfaceState(
        available: true,
        canPurchase: false,
        blockReason: PurchaseBlockReason.iapDisabled,
        products: [offer('MONTHLY')],
      );
      expect(s.commerceEnabled, isFalse);
    });

    test('can_purchase = true bez produktów też nie sprzedaje', () {
      // Karta planu bez ceny ze sklepu łamie Apple 3.1.2 — lepiej nie
      // pokazać żadnej niż pokazać pustą.
      const s = BillingSurfaceState(available: true, canPurchase: true);
      expect(s.commerceEnabled, isFalse);
    });

    test('zgoda serwera + produkty = sprzedajemy', () {
      final s = BillingSurfaceState(
        available: true,
        canPurchase: true,
        products: [offer('MONTHLY')],
      );
      expect(s.commerceEnabled, isTrue);
    });
  });

  group('cykle i dostawcy', () {
    final surface = BillingSurfaceState(
      available: true,
      canPurchase: true,
      activeProvider: 'APPLE_IAP',
      products: [
        const StoreProductOffer(
            productId: 'a',
            planTier: 'PRO',
            planCycle: 'ANNUAL',
            tokensPerPeriod: 360),
        const StoreProductOffer(
            productId: 'm',
            planTier: 'PRO',
            planCycle: 'MONTHLY',
            tokensPerPeriod: 30),
      ],
    );

    test('miesięczny idzie przed rocznym niezależnie od kolejności z serwera',
        () {
      expect(surface.availableCycles, ['MONTHLY', 'ANNUAL']);
    });

    test('productsForCycle filtruje po cyklu', () {
      expect(surface.productsForCycle('ANNUAL').single.productId, 'a');
      expect(surface.productsForCycle('MONTHLY').single.productId, 'm');
      expect(surface.productsForCycle('WEEKLY'), isEmpty);
    });

    test('rozpoznaje rodzaj dostawcy', () {
      expect(surface.isStoreProvider, isTrue);
      expect(surface.isStripeProvider, isFalse);
      expect(
        const BillingSurfaceState(available: true, activeProvider: 'STRIPE')
            .isStripeProvider,
        isTrue,
      );
      expect(
        const BillingSurfaceState(available: true, activeProvider: 'MANUAL')
            .isManagedProvider,
        isTrue,
      );
    });

    test('tryb NONE zakazuje jakiejkolwiek wzmianki o webie', () {
      const s = BillingSurfaceState(available: true);
      expect(s.mayMentionWeb, isFalse);
      expect(s.mayLinkOutToWeb, isFalse);
    });

    test('tryb TEXT pozwala wspomnieć, ale nie linkować', () {
      const s =
          BillingSurfaceState(available: true, webLinkMode: WebLinkMode.text);
      expect(s.mayMentionWeb, isTrue);
      expect(s.mayLinkOutToWeb, isFalse);
    });
  });
}
