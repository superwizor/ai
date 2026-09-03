// Model powierzchni handlowej (docs/70 §7.2 — `BillingService.GetBillingSurface`).
//
// Czysta warstwa danych, bez transportu i bez Fluttera — dzięki temu da się ją
// testować bez podnoszenia gRPC. Odpowiada na jedno pytanie: **czy i co wolno
// dziś sprzedać na TEJ platformie**, a jeśli nie — dlaczego.
//
// Zasada nadrzędna: to serwer decyduje. Aplikacja nigdy sama nie wnioskuje
// „skoro jest trial, to pewnie można kupić" — macierz z docs/70 §5.1 (org
// zarządzana przez klinikę, aktywny Stripe, otwarty checkout, wyłączona flaga
// IAP) żyje po stronie billing-svc i tu tylko ją odczytujemy.
//
// Gdy RPC jeszcze nie istnieje (UNIMPLEMENTED — backend powstaje równolegle)
// albo padnie sieć, zwracamy [BillingSurfaceState.unavailable]: aplikacja
// zachowuje się dokładnie jak przed IAP — żadnego paywalla, żadnych CTA.

/// Powód, dla którego zakup jest zablokowany. Wartości pochodzą z
/// `BillingSurface.block_reason` / `BeginStorePurchaseResponse.block_reason`.
enum PurchaseBlockReason {
  /// Subskrypcja kupiona u innego dostawcy (Stripe, druga platforma sklepowa).
  otherProviderActive,

  /// Planem zarządza organizacja (klinika z alokacją miejsc) — paywall ukryty.
  orgManaged,

  /// Flaga `IAP_ENABLED_<platforma>` wyłączona po stronie serwera (docs/70 E26).
  iapDisabled,

  /// Otwarta sesja Checkout Stripe < 24 h (docs/70 E22).
  pendingCheckout,

  /// Konto nieaktywne — i tak nie może nagrywać.
  accountInactive,

  /// Serwer podał powód, którego ta wersja aplikacji nie zna. Traktujemy jak
  /// blokadę bez szczegółów — nowy powód nigdy nie może odblokować sprzedaży.
  unknown,
}

PurchaseBlockReason? parseBlockReason(String raw) {
  switch (raw) {
    case '':
      return null;
    case 'OTHER_PROVIDER_ACTIVE':
      return PurchaseBlockReason.otherProviderActive;
    case 'ORG_MANAGED':
      return PurchaseBlockReason.orgManaged;
    case 'IAP_DISABLED':
      return PurchaseBlockReason.iapDisabled;
    case 'PENDING_CHECKOUT':
      return PurchaseBlockReason.pendingCheckout;
    case 'ACCOUNT_INACTIVE':
      return PurchaseBlockReason.accountInactive;
    default:
      return PurchaseBlockReason.unknown;
  }
}

/// Czy aplikacji wolno w ogóle wspomnieć o zakupie na superwizor.ai.
///
/// `none` jest domyślne i jedyne bezpieczne bez analizy warunków DMA
/// (docs/70 §2.1 „Steering"). Dopóki tu jest `none`, w aplikacji NIE MA
/// klikalnych linków ani zachęt do zakupu poza sklepem.
enum WebLinkMode { none, text, link }

WebLinkMode parseWebLinkMode(String raw) {
  switch (raw) {
    case 'TEXT':
      return WebLinkMode.text;
    case 'LINK':
      return WebLinkMode.link;
    default:
      return WebLinkMode.none;
  }
}

/// Jeden produkt sklepowy do pokazania na paywallu.
///
/// UWAGA — [productId] to jedyne pole, po którym wolno odpytać sklep o cenę.
/// [referencePriceGross] jest wyłącznie referencyjne (telemetria, porównania) i
/// **nigdy** nie trafia do UI: cena musi pochodzić z `ProductDetails.price`
/// StoreKit/Play, w walucie storefrontu użytkownika (docs/70 E25).
class StoreProductOffer {
  const StoreProductOffer({
    required this.productId,
    required this.planTier,
    required this.planCycle,
    required this.tokensPerPeriod,
    this.referencePriceGross = '',
    this.currencyCode = '',
  });

  final String productId;
  final String planTier; // SOLO | PRO | ...
  final String planCycle; // MONTHLY | ANNUAL | ...
  final int tokensPerPeriod;
  final String referencePriceGross;
  final String currencyCode;

  bool get isAnnual => planCycle == 'ANNUAL';
  bool get isMonthly => planCycle == 'MONTHLY';
}

/// Migawka powierzchni handlowej dla bieżącego użytkownika i platformy.
class BillingSurfaceState {
  const BillingSurfaceState({
    required this.available,
    this.activeProvider = '',
    this.planTier = '',
    this.status = '',
    this.canPurchase = false,
    this.blockReason,
    this.blockedUntil,
    this.products = const [],
    this.webLinkMode = WebLinkMode.none,
    this.showRestore = false,
    this.manageUrl = '',
  });

  /// Stan „serwer jeszcze nie umie / nie odpowiedział". Cała warstwa commerce
  /// jest wtedy niewidoczna, a aplikacja działa jak przed fazą 3.
  const BillingSurfaceState.unavailable() : this(available: false);

  /// Czy odpowiedź serwera w ogóle dotarła. `false` → nie pokazujemy ANI
  /// paywalla, ANI przycisków zakupu, ANI „Przywróć zakupy".
  final bool available;

  /// STRIPE | APPLE_IAP | GOOGLE_IAP | MANUAL | P24; puste = brak subskrypcji.
  final String activeProvider;
  final String planTier;
  final String status;

  final bool canPurchase;
  final PurchaseBlockReason? blockReason;
  final DateTime? blockedUntil;

  final List<StoreProductOffer> products;
  final WebLinkMode webLinkMode;
  final bool showRestore;

  /// Adres „zarządzaj subskrypcją" podany przez serwer. Puste → aplikacja
  /// składa deep link sklepu sama (patrz `store_links.dart`).
  final String manageUrl;

  /// Czy w aplikacji wolno w ogóle sprzedawać — jedyna bramka, o którą pyta UI.
  bool get commerceEnabled => available && canPurchase && products.isNotEmpty;

  /// Subskrypcja pochodzi ze sklepu (Apple/Google), więc zarządzanie nią i
  /// naprawa płatności są deep linkiem do sklepu, a nie ustawieniami web.
  bool get isStoreProvider =>
      activeProvider == 'APPLE_IAP' || activeProvider == 'GOOGLE_IAP';

  bool get isStripeProvider => activeProvider == 'STRIPE';

  /// Plan przydzielony przez organizację/administratora (trial, beta, klinika).
  bool get isManagedProvider =>
      activeProvider == 'MANUAL' || activeProvider == 'P24';

  /// Czy w tej chwili wolno wspomnieć o zakupie poza aplikacją.
  bool get mayMentionWeb => webLinkMode != WebLinkMode.none;

  /// Czy wolno pokazać KLIKALNY link poza aplikację (tylko tryb `LINK`).
  bool get mayLinkOutToWeb => webLinkMode == WebLinkMode.link;

  List<StoreProductOffer> productsForCycle(String cycle) =>
      products.where((p) => p.planCycle == cycle).toList(growable: false);

  /// Cykle obecne w ofercie, w kolejności miesięczny → roczny → reszta.
  List<String> get availableCycles {
    final seen = <String>{};
    for (final p in products) {
      if (p.planCycle.isNotEmpty) seen.add(p.planCycle);
    }
    final ordered = <String>[];
    for (final preferred in const ['MONTHLY', 'ANNUAL']) {
      if (seen.remove(preferred)) ordered.add(preferred);
    }
    ordered.addAll(seen);
    return ordered;
  }
}
