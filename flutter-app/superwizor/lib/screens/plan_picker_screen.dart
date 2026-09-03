// PlanPickerScreen — paywall (docs/70 §7.4 „Paywall", Apple 3.1.1 i 3.1.2).
//
// Cztery reguły, których ten ekran pilnuje:
//
//  1. **Cena wyłącznie ze sklepu.** Karta planu renderuje się dopiero wtedy,
//     gdy StoreKit/Play odda `ProductDetails.price`. Backend podaje sam
//     `product_id`; jego `reference_price_gross` służy telemetrii i NIE MA
//     PRAWA pojawić się w UI — użytkownik z zagranicznym storefrontem
//     zobaczyłby złotówki zamiast swojej waluty (E25).
//
//  2. **Żadnego pola kodu rabatowego** (3.1.1: zakaz własnych mechanizmów
//     odblokowania w aplikacji). Kody działają na webie i tam zostają.
//
//  3. **Żadnej wzmianki o zakupie na superwizor.ai**, dopóki serwer trzyma
//     `web_link_mode == NONE`. Nie ma tu adresu, linku ani sugestii, że
//     „taniej jest gdzie indziej".
//
//  4. **Komplet informacji prawnych** przy przycisku zakupu: cena, okres
//     rozliczeniowy, automatyczne odnawianie, sposób anulowania oraz
//     klikalne Regulamin i Polityka prywatności (3.1.2).
//
// Ekran musi wyglądać sensownie także wtedy, gdy sprzedaży NIE MA — flagi
// `IAP_ENABLED_*` są domyślnie wyłączone, a organizacje klinik mają paywall
// ukryty z definicji. Zamiast pustki pokazujemy wtedy powód.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../l10n/app_localizations.dart';
import '../providers/billing_surface_provider.dart';
import '../providers/locale_provider.dart';
import '../services/billing_surface_state.dart';
import '../services/store_purchase_service.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_toast.dart';
import 'legal_markdown_screen.dart';

const _kFont = 'Montserrat';

class PlanPickerScreen extends ConsumerStatefulWidget {
  const PlanPickerScreen({super.key, this.onboarding = false});

  /// Tuż po rejestracji (S1 krok 4). Dokłada wyjście „Na razie bez planu" —
  /// trial jest już aktywny, więc pominięcie paywalla niczego nie psuje i
  /// nie wolno robić z niego ślepej uliczki.
  final bool onboarding;

  @override
  ConsumerState<PlanPickerScreen> createState() => _PlanPickerScreenState();
}

class _PlanPickerScreenState extends ConsumerState<PlanPickerScreen> {
  /// Ceny ze sklepu, `product_id` → szczegóły. Puste, dopóki nie wrócą.
  Map<String, ProductDetails> _prices = const {};
  bool _loadingPrices = true;
  String _cycle = 'MONTHLY';
  String? _busyProductId;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrices());
  }

  Future<void> _loadPrices() async {
    final surface = ref.read(billingSurfaceProvider).value;
    final ids = <String>{
      for (final p in surface?.products ?? const <StoreProductOffer>[])
        p.productId,
    };
    if (ids.isEmpty) {
      if (mounted) setState(() => _loadingPrices = false);
      return;
    }
    Map<String, ProductDetails> prices = const {};
    try {
      prices = await ref.read(storePurchaseServiceProvider).loadProducts(ids);
    } catch (e) {
      debugPrint('[paywall] pobranie cen nieudane: $e');
    }
    if (!mounted) return;
    setState(() {
      _prices = prices;
      _loadingPrices = false;
      // Domyślny cykl: ten, dla którego w ogóle mamy ceny.
      final cycles = (ref.read(billingSurfaceProvider).value
                  ?.availableCycles ??
              const <String>[])
          .where((c) => _offersWithPrice(c).isNotEmpty)
          .toList();
      if (cycles.isNotEmpty && !cycles.contains(_cycle)) _cycle = cycles.first;
    });
  }

  List<StoreProductOffer> _offersWithPrice(String cycle) {
    final surface = ref.read(billingSurfaceProvider).value;
    if (surface == null) return const [];
    return surface
        .productsForCycle(cycle)
        .where((o) => _prices.containsKey(o.productId))
        .toList(growable: false);
  }

  // ── Akcje ───────────────────────────────────────────────────────────────

  Future<void> _buy(StoreProductOffer offer) async {
    setState(() => _busyProductId = offer.productId);
    final result =
        await ref.read(storePurchaseServiceProvider).buy(offer.productId);
    if (!mounted) return;
    setState(() => _busyProductId = null);
    final t = AppLocalizations.of(context);

    if (result.isSuccess) {
      EuphireToast.success(context, message: t.purchase_success);
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    if (result.outcome == StorePurchaseOutcome.cancelled) return;
    EuphireToast.error(context, message: _messageFor(result, t));
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final result = await ref.read(storePurchaseServiceProvider).restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    final t = AppLocalizations.of(context);
    if (result.isSuccess) {
      EuphireToast.success(context, message: t.purchase_restore_success);
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    if (result.outcome == StorePurchaseOutcome.nothingToRestore) {
      EuphireToast.info(context, message: t.purchase_restore_none);
      return;
    }
    EuphireToast.error(context, message: _messageFor(result, t));
  }

  String _messageFor(StorePurchaseResult r, AppLocalizations t) {
    switch (r.outcome) {
      case StorePurchaseOutcome.blocked:
        return _blockMessage(r.blockReason, r.blockedUntil, t);
      case StorePurchaseOutcome.pending:
        return t.purchase_pending;
      case StorePurchaseOutcome.storeUnavailable:
      case StorePurchaseOutcome.unavailable:
        return t.purchase_error_store_unavailable;
      case StorePurchaseOutcome.productUnavailable:
        return t.purchase_error_product_unavailable;
      case StorePurchaseOutcome.verificationFailed:
        return t.purchase_error_verification;
      case StorePurchaseOutcome.foreignAccount:
        return t.purchase_error_foreign_account;
      case StorePurchaseOutcome.storeNotConfigured:
        return t.purchase_error_store_not_configured;
      case StorePurchaseOutcome.sandboxNotAllowed:
        return t.purchase_error_sandbox_not_allowed;
      case StorePurchaseOutcome.nothingToRestore:
        return t.purchase_restore_none;
      case StorePurchaseOutcome.success:
        return t.purchase_success;
      case StorePurchaseOutcome.cancelled:
      case StorePurchaseOutcome.error:
        return t.purchase_error_generic;
    }
  }

  void _openLegal({required bool terms}) {
    final t = AppLocalizations.of(context);
    final english = ref.read(localeProvider).languageCode == 'en';
    final asset = terms
        ? (english ? 'assets/legal/terms_en.md' : 'assets/legal/terms.md')
        : (english
            ? 'assets/legal/privacy_policy_en.md'
            : 'assets/legal/privacy_policy.md');
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'LegalMarkdownScreen'),
      builder: (_) => LegalMarkdownScreen(
        assetPath: asset,
        title: terms ? t.settings_terms : t.settings_privacy,
      ),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final surface = ref.watch(billingSurfaceProvider);

    return Scaffold(
      backgroundColor: EuphireColors.deepTealBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: EuphireColors.frostWhite),
        title: Text(
          t.plan_picker_title,
          style: const TextStyle(
            color: EuphireColors.frostWhite,
            fontFamily: _kFont,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: surface.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: EuphireColors.ember),
          ),
          error: (_, _) => _Unavailable(onSkip: _skipAction()),
          data: (s) => _body(context, s),
        ),
      ),
    );
  }

  VoidCallback? _skipAction() {
    if (!widget.onboarding) return null;
    return () {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    };
  }

  Widget _body(BuildContext context, BillingSurfaceState s) {
    final t = AppLocalizations.of(context);

    // Sprzedaży nie ma: wyłączona flaga serwera, plan kliniki, aktywna
    // subskrypcja u innego dostawcy. Zamiast pustego ekranu — powód.
    if (!s.commerceEnabled) {
      return _Unavailable(
        reason: s.available
            ? _blockMessage(s.blockReason, s.blockedUntil, t)
            : null,
        onSkip: _skipAction(),
      );
    }

    if (_loadingPrices) {
      return const Center(
        child: CircularProgressIndicator(color: EuphireColors.ember),
      );
    }

    final cycles = s.availableCycles
        .where((c) => _offersWithPrice(c).isNotEmpty)
        .toList(growable: false);
    final offers = _offersWithPrice(_cycle);

    // Sklep nie oddał ani jednej ceny (brak sieci, produkty niezatwierdzone).
    // Karta bez ceny łamie 3.1.2, więc nie pokazujemy żadnej.
    if (offers.isEmpty) {
      return _Unavailable(reason: t.plan_picker_empty, onSkip: _skipAction());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text(
          t.plan_picker_subtitle,
          style: const TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 14,
            height: 1.5,
            color: EuphireColors.mist,
          ),
        ),
        const SizedBox(height: 24),
        if (cycles.length > 1) ...[
          _CycleToggle(
            cycles: cycles,
            selected: _cycle,
            onChanged: (c) => setState(() => _cycle = c),
          ),
          const SizedBox(height: 24),
        ],
        for (final offer in offers) ...[
          _PlanCard(
            offer: offer,
            details: _prices[offer.productId]!,
            current: s.planTier == offer.planTier,
            busy: _busyProductId == offer.productId,
            enabled: _busyProductId == null && !_restoring,
            onBuy: () => _buy(offer),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        _LegalBlock(
          annual: _cycle == 'ANNUAL',
          onTerms: () => _openLegal(terms: true),
          onPrivacy: () => _openLegal(terms: false),
        ),
        if (s.showRestore) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: (_restoring || _busyProductId != null) ? null : _restore,
              child: _restoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: EuphireColors.mist),
                    )
                  : Text(
                      t.plan_picker_restore,
                      style: const TextStyle(
                        fontFamily: _kFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: EuphireColors.mist,
                      ),
                    ),
            ),
          ),
        ],
        if (widget.onboarding) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _busyProductId != null ? null : _skipAction(),
              child: Text(
                t.plan_picker_skip,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontSize: 14,
                  color: EuphireColors.mist.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _blockMessage(
  PurchaseBlockReason? reason,
  DateTime? until,
  AppLocalizations t,
) {
  switch (reason) {
    case PurchaseBlockReason.otherProviderActive:
      return until == null
          ? t.purchase_blocked_other_provider
          : t.purchase_blocked_other_provider_until(formatShortDate(until));
    case PurchaseBlockReason.orgManaged:
      return t.purchase_blocked_org_managed;
    case PurchaseBlockReason.iapDisabled:
      return t.purchase_blocked_iap_disabled;
    case PurchaseBlockReason.pendingCheckout:
      return t.purchase_blocked_pending_checkout;
    case PurchaseBlockReason.accountInactive:
      return t.purchase_blocked_account_inactive;
    case PurchaseBlockReason.unknown:
    case null:
      return t.purchase_blocked_generic;
  }
}

/// `dd.MM.yyyy` — ten sam format, którym posługują się banery kwoty.
String formatShortDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

// ── Kafelki ───────────────────────────────────────────────────────────────

class _CycleToggle extends StatelessWidget {
  const _CycleToggle({
    required this.cycles,
    required this.selected,
    required this.onChanged,
  });

  final List<String> cycles;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: EuphireColors.surfaceTeal,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final cycle in cycles)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(cycle),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: cycle == selected
                        ? EuphireColors.ember
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    cycle == 'ANNUAL'
                        ? t.plan_picker_cycle_annual
                        : t.plan_picker_cycle_monthly,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cycle == selected
                          ? EuphireColors.obsidianBlack
                          : EuphireColors.mist,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.offer,
    required this.details,
    required this.current,
    required this.busy,
    required this.enabled,
    required this.onBuy,
  });

  final StoreProductOffer offer;
  final ProductDetails details;
  final bool current;
  final bool busy;
  final bool enabled;
  final VoidCallback onBuy;

  String _tierLabel(AppLocalizations t) {
    switch (offer.planTier) {
      case 'SOLO':
        return t.subscription_tier_solo;
      case 'PRO':
        return t.subscription_tier_pro;
      case 'CLINIC':
        return t.subscription_tier_clinic;
      default:
        // Nowy poziom planu z serwera: lepiej pokazać nazwę produktu ze
        // sklepu niż surowy kod techniczny.
        return details.title.isNotEmpty ? details.title : offer.planTier;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: EuphireColors.surfaceTeal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current
              ? EuphireColors.ember.withValues(alpha: 0.6)
              : EuphireColors.glassBorder,
        ),
        boxShadow: EuphireColors.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current) ...[
            Text(
              t.plan_picker_current_plan,
              style: const TextStyle(
                fontFamily: _kFont,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: EuphireColors.ember,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            _tierLabel(t),
            style: const TextStyle(
              fontFamily: _kFont,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: EuphireColors.frostWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.plan_picker_sessions(offer.tokensPerPeriod),
            style: const TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 13,
              color: EuphireColors.mist,
            ),
          ),
          const SizedBox(height: 16),
          // Cena DOKŁADNIE tak, jak sformatował ją sklep — z walutą
          // storefrontu i lokalnym separatorem. Zero własnego formatowania.
          Text(
            details.price,
            style: const TextStyle(
              fontFamily: _kFont,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: EuphireColors.frostWhite,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: enabled ? onBuy : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: EuphireColors.ember,
                foregroundColor: EuphireColors.obsidianBlack,
                disabledBackgroundColor:
                    EuphireColors.ember.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            EuphireColors.obsidianBlack),
                      ),
                    )
                  : Text(
                      t.plan_picker_cta,
                      style: const TextStyle(
                        fontFamily: _kFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blok wymagany przez Apple 3.1.2 — okres, automatyczne odnawianie, sposób
/// anulowania i dwa klikalne dokumenty.
class _LegalBlock extends StatelessWidget {
  const _LegalBlock({
    required this.annual,
    required this.onTerms,
    required this.onPrivacy,
  });

  final bool annual;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final linkStyle = TextStyle(
      fontFamily: _kFont,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: EuphireColors.mist.withValues(alpha: 0.95),
      decoration: TextDecoration.underline,
      decorationColor: EuphireColors.mist.withValues(alpha: 0.6),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          annual ? t.plan_picker_legal_annual : t.plan_picker_legal_monthly,
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 11,
            height: 1.6,
            color: EuphireColors.mist.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: onTerms,
              child: Text(t.plan_picker_legal_terms, style: linkStyle),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: onPrivacy,
              child: Text(t.plan_picker_legal_privacy, style: linkStyle),
            ),
          ],
        ),
      ],
    );
  }
}

/// Stan „nie sprzedajemy tu i teraz". Zawsze z powodem i zawsze z wyjściem —
/// paywall bez drogi dalej byłby ślepą uliczką tuż po rejestracji.
class _Unavailable extends StatelessWidget {
  const _Unavailable({this.reason, this.onSkip});

  final String? reason;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined,
                color: EuphireColors.mist, size: 48),
            const SizedBox(height: 16),
            Text(
              t.plan_picker_unavailable_title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _kFont,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: EuphireColors.frostWhite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason ?? t.plan_picker_unavailable_body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 13,
                height: 1.6,
                color: EuphireColors.mist,
              ),
            ),
            if (onSkip != null) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: onSkip,
                child: Text(
                  t.plan_picker_skip,
                  style: const TextStyle(
                    fontFamily: _kFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: EuphireColors.ember,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
