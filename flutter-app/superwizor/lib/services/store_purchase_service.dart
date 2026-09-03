// StorePurchaseService — jedyne miejsce, przez które przechodzą zakupy
// sklepowe (docs/70 §7.4 „Transakcje").
//
// Trzy reguły, na których stoi cała ta klasa:
//
//  1. **Nigdy nie finishujemy transakcji przed potwierdzeniem serwera** (E28).
//     `completePurchase()` na iOS domyka transakcję StoreKit, a na Androidzie
//     robi `acknowledgePurchase`. Zrobione za wcześnie — przy padzie sieci
//     tuż po zapłacie — kasuje jedyny dowód zakupu, jaki mamy, i użytkownik
//     zostaje z obciążoną kartą bez uprawnienia. Domykamy WYŁĄCZNIE po
//     udanym `VerifyStorePurchase`; nieudana weryfikacja zostawia transakcję
//     w kolejce sklepu, więc wróci przy następnym starcie.
//
//  2. **Nasłuch od startu aplikacji, nie od ekranu paywalla.** Transakcja
//     potwierdzona przez sklep może dojść po crashu, po zabiciu aplikacji
//     albo po powrocie sieci — wtedy nikogo nie ma na paywallu. Strumień
//     żyje tak długo jak aplikacja.
//
//  3. **Cena zawsze ze sklepu.** Backend podaje wyłącznie `product_id`;
//     kwota, waluta i formatowanie pochodzą z `ProductDetails.price`
//     (docs/70 E25). Cena z serwera nie ma prawa pojawić się w UI.
//
// Klasa celowo nie zna Riverpoda ani widgetów — dostaje wstrzykiwane
// zależności, żeby dała się testować bez sklepu i bez gRPC.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../generated/billing/v1/billing.pb.dart' as billing_pb;
import '../generated/billing/v1/billing.pbgrpc.dart' show BillingServiceClient;
import 'billing_surface_state.dart';

/// Jak skończyła się próba zakupu / przywrócenia.
enum StorePurchaseOutcome {
  /// Serwer potwierdził zakup i uprawnienie jest już aktywne.
  success,

  /// Użytkownik przerwał płatność. Nie jest to błąd — nie pokazujemy alertu.
  cancelled,

  /// Sklep przyjął zakup, ale czeka na potwierdzenie (Google `PENDING`,
  /// Apple „Ask to Buy"). Uprawnienia jeszcze NIE przyznajemy (docs/70 E20).
  pending,

  /// Serwer odmówił rozpoczęcia zakupu (macierz z docs/70 §5.1).
  blocked,

  /// Sklep niedostępny (brak konta, urządzenie z ograniczeniami, web).
  storeUnavailable,

  /// Sklep nie zna tego `product_id` — literówka w konfiguracji albo produkt
  /// nie jest jeszcze zatwierdzony w App Store Connect / Play Console.
  productUnavailable,

  /// Zakup u sklepu się udał, ale serwer go nie potwierdził. Transakcja
  /// ZOSTAJE otwarta i wróci przy następnym starcie (E28).
  verificationFailed,

  /// Transakcja jest przypisana do innej organizacji SuperWizor —
  /// `PERMISSION_DENIED TRANSACTION_OWNED_BY_ANOTHER_ACCOUNT` (docs/70 E1).
  /// Drugie konto w aplikacji albo cudze Apple ID na tym urządzeniu.
  foreignAccount,

  /// Backend nie ma jeszcze kluczy App Store / Play —
  /// `FAILED_PRECONDITION STORE_NOT_CONFIGURED`.
  storeNotConfigured,

  /// Zakup z sandboxa na koncie spoza allowlisty testowej —
  /// `FAILED_PRECONDITION SANDBOX_NOT_ALLOWED` (docs/70 E19).
  sandboxNotAllowed,

  /// „Przywróć zakupy" nie znalazło niczego do przywrócenia.
  nothingToRestore,

  /// Warstwa commerce nie działa (brak klienta billing-svc, UNIMPLEMENTED).
  unavailable,

  /// Błąd sklepu lub sieci.
  error,
}

class StorePurchaseResult {
  const StorePurchaseResult(
    this.outcome, {
    this.blockReason,
    this.blockedUntil,
    this.message,
  });

  final StorePurchaseOutcome outcome;
  final PurchaseBlockReason? blockReason;
  final DateTime? blockedUntil;

  /// Techniczny opis do logów. NIE nadaje się do pokazania użytkownikowi —
  /// teksty UI biorą się z ARB na podstawie [outcome].
  final String? message;

  bool get isSuccess => outcome == StorePurchaseOutcome.success;
}

/// Zdarzenie z tła: transakcja domknięta poza przepływem zakupu (redelivery
/// po crashu, odnowienie potwierdzone przez sklep w trakcie działania apki).
class StorePurchaseEvent {
  const StorePurchaseEvent({required this.verified, this.productId});
  final bool verified;
  final String? productId;
}

typedef BillingClientResolver = BillingServiceClient? Function();

/// Tłumaczy odmowę billing-svc na konkretny wynik.
///
/// Serwer rozróżnia powody odmowy tekstem w `message` (kontrakt z docs/70
/// §7.2), bo kody gRPC są zbyt gruboziarniste: „nie ten właściciel",
/// „sklep nieskonfigurowany" i „sandbox zabroniony" wymagają trzech różnych
/// komunikatów, a wszystkie trzy to formalnie ta sama odmowa. Nieznany powód
/// spada do ogólnej nieudanej weryfikacji — nigdy do „sukcesu".
StorePurchaseOutcome mapVerifyError(GrpcError e) {
  final message = e.message ?? '';
  if (message.contains('TRANSACTION_OWNED_BY_ANOTHER_ACCOUNT')) {
    return StorePurchaseOutcome.foreignAccount;
  }
  if (message.contains('STORE_NOT_CONFIGURED')) {
    return StorePurchaseOutcome.storeNotConfigured;
  }
  if (message.contains('SANDBOX_NOT_ALLOWED')) {
    return StorePurchaseOutcome.sandboxNotAllowed;
  }
  if (e.code == StatusCode.unimplemented) {
    return StorePurchaseOutcome.unavailable;
  }
  return StorePurchaseOutcome.verificationFailed;
}

class StorePurchaseService {
  StorePurchaseService({
    required BillingClientResolver billingClient,
    required String platform,
    InAppPurchase? iap,
    Future<void> Function()? onEntitlementChanged,
  })  : _billingClient = billingClient,
        _platform = platform,
        _iap = iap ?? InAppPurchase.instance,
        _onEntitlementChanged = onEntitlementChanged;

  final BillingClientResolver _billingClient;

  /// 'IOS' | 'ANDROID' — puste na platformach bez sklepu.
  final String _platform;
  final InAppPurchase _iap;

  /// Wołane po każdej udanej weryfikacji: odświeża powierzchnię handlową i
  /// pulę tokenów, żeby użytkownik od razu zobaczył nowy plan.
  final Future<void> Function()? _onEntitlementChanged;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _events = StreamController<StorePurchaseEvent>.broadcast();

  /// Zakupy oczekujące na rozstrzygnięcie w bieżącym przepływie `buy()`,
  /// kluczowane po `product_id`.
  final _inFlight = <String, Completer<StorePurchaseResult>>{};

  /// Gdy niepuste, `restored`/`purchased` z tła trafiają tutaj zamiast iść
  /// pojedynczo do `VerifyStorePurchase` — batch idzie do
  /// `RestoreStorePurchases`, bo tylko tam serwer sprawdza `appAccountToken`
  /// pod kątem cudzego konta (docs/70 E1).
  List<PurchaseDetails>? _restoreCollector;

  bool get isAndroid => _platform == 'ANDROID';
  bool get isSupported => _platform.isNotEmpty;

  Stream<StorePurchaseEvent> get events => _events.stream;

  /// Podpina nasłuch. Idempotentne — wołane z `main()` przy starcie.
  Future<void> start() async {
    if (!isSupported || _sub != null) return;
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) => debugPrint('[iap] purchaseStream error: $e'),
    );

    // Odzyskiwanie zawieszonych transakcji (E28).
    //
    // iOS: StoreKit sam wypycha niedomknięte transakcje do obserwatora, więc
    // sam nasłuch wyżej wystarcza — i nie wolno tu wołać `restorePurchases()`,
    // bo `AppStore.sync()` potrafi poprosić o hasło Apple ID przy starcie.
    //
    // Android: nic się samo nie wypycha, a niepotwierdzony zakup jest po
    // 3 dniach automatycznie zwracany. `restorePurchases()` to na tej
    // platformie zwykłe `queryPurchases` — bez UI i bez pytania o hasło.
    if (isAndroid) {
      try {
        await _iap.restorePurchases();
      } catch (e) {
        debugPrint('[iap] cold-start queryPurchases failed: $e');
      }
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _events.close();
  }

  /// Ceny do paywalla. Zwraca mapę `product_id → ProductDetails`; brakujące
  /// identyfikatory po prostu nie trafiają do mapy, a UI pomija te karty —
  /// karta planu bez ceny ze sklepu jest niezgodna z 3.1.2, więc lepiej jej
  /// nie pokazać wcale.
  Future<Map<String, ProductDetails>> loadProducts(Set<String> ids) async {
    if (!isSupported || ids.isEmpty) return const {};
    if (!await _iap.isAvailable()) return const {};
    final response = await _iap.queryProductDetails(ids);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[iap] sklep nie zna produktów: ${response.notFoundIDs}');
    }
    return {for (final p in response.productDetails) p.id: p};
  }

  /// Pełny przepływ zakupu: zgoda serwera → płatność w sklepie → weryfikacja
  /// serwerowa → dopiero potem domknięcie transakcji.
  Future<StorePurchaseResult> buy(String productId) async {
    if (!isSupported) {
      return const StorePurchaseResult(StorePurchaseOutcome.storeUnavailable);
    }
    final client = _billingClient();
    if (client == null) {
      return const StorePurchaseResult(StorePurchaseOutcome.unavailable);
    }
    if (!await _iap.isAvailable()) {
      return const StorePurchaseResult(StorePurchaseOutcome.storeUnavailable);
    }

    // 1. Zgoda serwera + `app_account_token`. Serwer trzyma tu całą macierz
    //    z §5.1 — aplikacja nie próbuje jej odtwarzać.
    final billing_pb.BeginStorePurchaseResponse begin;
    try {
      begin = await client.beginStorePurchase(
        billing_pb.BeginStorePurchaseRequest(
          platform: _platform,
          productId: productId,
        ),
      );
    } on GrpcError catch (e) {
      debugPrint('[iap] BeginStorePurchase ${e.codeName}: ${e.message ?? ''}');
      return StorePurchaseResult(
        e.code == StatusCode.unimplemented
            ? StorePurchaseOutcome.unavailable
            : StorePurchaseOutcome.error,
        message: e.message,
      );
    } catch (e) {
      return StorePurchaseResult(StorePurchaseOutcome.error,
          message: e.toString());
    }

    if (!begin.allowed) {
      return StorePurchaseResult(
        StorePurchaseOutcome.blocked,
        blockReason: parseBlockReason(begin.blockReason),
        blockedUntil: begin.hasBlockedUntil()
            ? begin.blockedUntil.toDateTime().toLocal()
            : null,
      );
    }

    // 2. Produkt ze sklepu — bez niego nie ma ani ceny, ani płatności.
    final products = await loadProducts({productId});
    final details = products[productId];
    if (details == null) {
      return const StorePurchaseResult(
          StorePurchaseOutcome.productUnavailable);
    }

    // 3. Płatność. `applicationUserName` mapuje się na `appAccountToken`
    //    (StoreKit 2) i `obfuscatedAccountId` (Play) — to po nim serwer
    //    wiąże transakcję z organizacją, a nie po adresie e-mail (E29).
    final completer = Completer<StorePurchaseResult>();
    _inFlight[productId] = completer;
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: details,
          applicationUserName: begin.appAccountToken.isEmpty
              ? null
              : begin.appAccountToken,
        ),
      );
      if (!started) {
        _inFlight.remove(productId);
        return const StorePurchaseResult(StorePurchaseOutcome.error,
            message: 'buyNonConsumable returned false');
      }
    } catch (e) {
      _inFlight.remove(productId);
      return StorePurchaseResult(StorePurchaseOutcome.error,
          message: e.toString());
    }

    // 4. Rozstrzygnięcie przychodzi strumieniem. Limit czasu jest hojny —
    //    arkusz płatności bywa długo otwarty (hasło, Face ID, „Ask to Buy") —
    //    a jego przekroczenie NIE unieważnia zakupu: transakcja dalej wisi
    //    w sklepie i domknie ją nasłuch w tle.
    return completer.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () {
        _inFlight.remove(productId);
        return const StorePurchaseResult(StorePurchaseOutcome.pending);
      },
    );
  }

  /// „Przywróć zakupy" — wymóg Apple 3.1.2.
  ///
  /// Zbiera transakcje, które sklep odda w oknie [window], i wysyła je
  /// JEDNYM `RestoreStorePurchases`: serwer sprawdza wtedy `appAccountToken`
  /// i odmawia, jeśli zakup należy do innej organizacji (E1).
  Future<StorePurchaseResult> restore({
    Duration window = const Duration(seconds: 6),
  }) async {
    if (!isSupported) {
      return const StorePurchaseResult(StorePurchaseOutcome.storeUnavailable);
    }
    final client = _billingClient();
    if (client == null) {
      return const StorePurchaseResult(StorePurchaseOutcome.unavailable);
    }

    final collected = <PurchaseDetails>[];
    _restoreCollector = collected;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _restoreCollector = null;
      return StorePurchaseResult(StorePurchaseOutcome.error,
          message: e.toString());
    }
    await Future<void>.delayed(window);
    _restoreCollector = null;

    if (collected.isEmpty) {
      return const StorePurchaseResult(StorePurchaseOutcome.nothingToRestore);
    }

    final request = billing_pb.RestoreStorePurchasesRequest(
      platform: _platform,
      productId: collected.first.productID,
    );
    for (final p in collected) {
      final token = p.verificationData.serverVerificationData;
      if (token.isEmpty) continue;
      if (isAndroid) {
        request.purchaseTokens.add(token);
      } else {
        request.jwsTransactions.add(token);
      }
    }
    if (request.purchaseTokens.isEmpty && request.jwsTransactions.isEmpty) {
      return const StorePurchaseResult(StorePurchaseOutcome.nothingToRestore);
    }

    try {
      await client.restoreStorePurchases(request);
    } on GrpcError catch (e) {
      debugPrint('[iap] RestoreStorePurchases ${e.codeName}: '
          '${e.message ?? ''}');
      return StorePurchaseResult(mapVerifyError(e), message: e.message);
    } catch (e) {
      return StorePurchaseResult(StorePurchaseOutcome.verificationFailed,
          message: e.toString());
    }

    // Serwer zapisał uprawnienie — dopiero teraz wolno domknąć transakcje.
    for (final p in collected) {
      await _finish(p);
    }
    await _onEntitlementChanged?.call();
    return const StorePurchaseResult(StorePurchaseOutcome.success);
  }

  // ── Strumień ────────────────────────────────────────────────────────────

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Google `PENDING` / Apple deferred: uprawnienia NIE przyznajemy,
          // transakcji NIE domykamy i NIE rozstrzygamy przepływu `buy()` —
          // domknie ją RTDN / `Transaction.updates` po zatwierdzeniu
          // płatności (docs/70 E20). Użytkownik czeka na paywallu.
          debugPrint('[iap] ${purchase.productID}: PENDING — czekamy na sklep');

        case PurchaseStatus.canceled:
          // Anulowaną transakcję trzeba domknąć, inaczej sklep wysyła ją
          // w kółko przy każdym starcie. Tu nie ma czego weryfikować.
          await _finish(purchase);
          _resolve(purchase.productID,
              const StorePurchaseResult(StorePurchaseOutcome.cancelled));

        case PurchaseStatus.error:
          await _finish(purchase);
          _resolve(
            purchase.productID,
            StorePurchaseResult(StorePurchaseOutcome.error,
                message: purchase.error?.message),
          );

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final collector = _restoreCollector;
          if (collector != null) {
            // Trwa „Przywróć zakupy" — zbieramy, batch pójdzie razem.
            collector.add(purchase);
            continue;
          }
          final result = await _verify(purchase);
          _resolve(purchase.productID, result);
          _events.add(StorePurchaseEvent(
            verified: result.isSuccess,
            productId: purchase.productID,
          ));
      }
    }
  }

  Future<StorePurchaseResult> _verify(PurchaseDetails purchase) async {
    final client = _billingClient();
    if (client == null) {
      // Bez klienta nie ma jak potwierdzić — zostawiamy transakcję otwartą.
      return const StorePurchaseResult(StorePurchaseOutcome.unavailable);
    }
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) {
      return const StorePurchaseResult(StorePurchaseOutcome.verificationFailed,
          message: 'empty serverVerificationData');
    }

    final request = billing_pb.VerifyStorePurchaseRequest(platform: _platform);
    if (isAndroid) {
      request
        ..purchaseToken = token
        ..productId = purchase.productID;
    } else {
      // StoreKit 2 oddaje w `serverVerificationData` reprezentację JWS
      // transakcji — dokładnie to, co weryfikuje App Store Server API.
      request.jwsTransaction = token;
    }

    try {
      await client.verifyStorePurchase(request);
    } on GrpcError catch (e) {
      debugPrint('[iap] VerifyStorePurchase ${e.codeName}: ${e.message ?? ''}');
      return StorePurchaseResult(mapVerifyError(e), message: e.message);
    } catch (e) {
      return StorePurchaseResult(StorePurchaseOutcome.verificationFailed,
          message: e.toString());
    }

    // Serwer zapisał uprawnienie → transakcja może zostać domknięta (E28).
    await _finish(purchase);
    await _onEntitlementChanged?.call();
    return const StorePurchaseResult(StorePurchaseOutcome.success);
  }

  Future<void> _finish(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint('[iap] completePurchase failed: $e');
    }
  }

  void _resolve(String productId, StorePurchaseResult result) {
    final completer = _inFlight.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }
}
