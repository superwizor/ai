// billingSurfaceProvider — stan „co wolno sprzedać na tej platformie".
//
// Siostra `billingQuotaProvider`: ta trzyma ile tokenów zostało, ta druga —
// czy i co da się kupić. Rozdzielone celowo, bo mają inne źródła prawdy i inne
// cykle odświeżania: quota idzie przez clinical-svc i odświeża się po każdym
// uploadzie, powierzchnia handlowa idzie prosto do billing-svc i odświeża się
// przy cold-starcie oraz po każdym zakupie (docs/70 §7.4 „Gating").
//
// Kontrakt awaryjny: RPC jeszcze nie istnieje na serwerze (UNIMPLEMENTED,
// backend powstaje równolegle) albo padła sieć → `BillingSurfaceState`
// z `available: false`, czyli zero zmian względem zachowania sprzed IAP.
// Świadomie NIE wystawiamy tu AsyncError — brak commerce to normalny,
// spodziewany stan, a nie awaria do pokazania użytkownikowi.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart'
    as empty_pb;

import '../generated/billing/v1/billing.pb.dart' as billing_pb;
import '../services/billing_surface_state.dart';
import '../services/store_purchase_service.dart';
import 'billing_quota_provider.dart';
import 'current_user_provider.dart';
import 'grpc_provider.dart';

/// Nazwa platformy w rozumieniu `BeginStorePurchaseRequest.platform`.
/// Puste na webie i desktopie — tam sklepowego zakupu nie ma w ogóle.
String currentStorePlatform() {
  if (kIsWeb) return '';
  if (Platform.isIOS || Platform.isMacOS) return 'IOS';
  if (Platform.isAndroid) return 'ANDROID';
  return '';
}

/// Czy urządzenie w ogóle może kupować w sklepie. Bramka lokalna, tania —
/// oszczędza RPC na webie, gdzie sklepu nie ma.
bool get storePurchaseSupported => currentStorePlatform().isNotEmpty;

BillingSurfaceState mapBillingSurface(billing_pb.BillingSurface s) {
  return BillingSurfaceState(
    available: true,
    activeProvider: s.activeProvider,
    planTier: s.planTier,
    status: s.status,
    canPurchase: s.canPurchase,
    blockReason: parseBlockReason(s.blockReason),
    blockedUntil:
        s.hasBlockedUntil() ? s.blockedUntil.toDateTime().toLocal() : null,
    products: [
      for (final p in s.products)
        StoreProductOffer(
          productId: p.productId,
          planTier: p.planTier,
          planCycle: p.planCycle,
          tokensPerPeriod: p.tokensPerPeriod,
          referencePriceGross: p.referencePriceGross,
          currencyCode: p.currencyCode,
        ),
    ],
    webLinkMode: parseWebLinkMode(s.webLinkMode),
    showRestore: s.showRestore,
    manageUrl: s.manageUrl,
  );
}

class BillingSurfaceNotifier extends AsyncNotifier<BillingSurfaceState> {
  @override
  Future<BillingSurfaceState> build() async {
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return const BillingSurfaceState.unavailable();
    if (!storePurchaseSupported) return const BillingSurfaceState.unavailable();
    return _fetch();
  }

  Future<BillingSurfaceState> _fetch() async {
    final billing = ref.read(grpcClientsProvider).billing;
    if (billing == null) return const BillingSurfaceState.unavailable();
    try {
      final surface = await billing.getBillingSurface(empty_pb.Empty());
      return mapBillingSurface(surface);
    } on GrpcError catch (e) {
      // UNIMPLEMENTED = backend nie ma jeszcze tego RPC (faza przejściowa).
      // Reszta kodów (UNAVAILABLE, DEADLINE_EXCEEDED, PERMISSION_DENIED przy
      // niedopuszczonym ingressie) też ląduje w „brak commerce" — pokazanie
      // paywalla na podstawie zgadywania byłoby gorsze niż jego brak.
      debugPrint('[billing-surface] GetBillingSurface ${e.codeName}: '
          '${e.message ?? ''}');
      return const BillingSurfaceState.unavailable();
    } catch (e) {
      debugPrint('[billing-surface] GetBillingSurface failed: $e');
      return const BillingSurfaceState.unavailable();
    }
  }

  /// Ponowne pobranie stanu — po zakupie, po „Przywróć zakupy" i z pull-to-
  /// refresh na ekranie Subskrypcja.
  Future<void> refresh() async {
    final next = await _fetch();
    state = AsyncData(next);
  }
}

final billingSurfaceProvider =
    AsyncNotifierProvider<BillingSurfaceNotifier, BillingSurfaceState>(
  BillingSurfaceNotifier.new,
);

/// Skrót dla widgetów, które chcą tylko wiedzieć „pokazać CTA zakupu?".
/// Podczas ładowania i przy błędzie zwraca `false` — CTA pojawia się dopiero,
/// gdy serwer wprost na nie pozwoli.
final canPurchaseProvider = Provider<bool>((ref) {
  return ref.watch(billingSurfaceProvider).maybeWhen(
        data: (s) => s.commerceEnabled,
        orElse: () => false,
      );
});

/// Singleton obsługi zakupów. Tworzony raz na kontener — nasłuch
/// `purchaseStream` musi żyć od startu aplikacji, a nie od wejścia na
/// paywall (docs/70 E28), więc `main()` czyta go zaraz po `runApp`.
final storePurchaseServiceProvider = Provider<StorePurchaseService>((ref) {
  final service = StorePurchaseService(
    billingClient: () => ref.read(grpcClientsProvider).billing,
    platform: currentStorePlatform(),
    onEntitlementChanged: () async {
      // Nowy plan = nowa powierzchnia handlowa i nowa pula tokenów.
      await ref.read(billingSurfaceProvider.notifier).refresh();
      ref.invalidate(billingQuotaProvider);
    },
  );
  ref.onDispose(service.dispose);
  return service;
});
