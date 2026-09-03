// QuotaWarningBanner — sticky banner driven by billingQuotaProvider.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §16.4.3.
//
// Rendering rules (from design §16.4.3):
//   - level=none:       hidden
//   - level=warning:    yellow accent, dismissible per session
//   - level=critical:   orange accent, dismissible
//   - level=exhausted:  red accent, NOT dismissible (sticky until renewal)
//
// CTA „Rozszerz plan" (docs/70 §7.4): wraca po dodaniu zakupów w aplikacji,
// ale WYŁĄCZNIE gdy serwer potwierdzi `can_purchase` w `GetBillingSurface`.
// Przycisk prowadzi do paywalla ze StoreKit/Play — nigdy poza aplikację.
// Terapeuta z planem kliniki, z aktywnym Stripe albo z wyłączoną flagą IAP
// widzi baner bez przycisku: informacja tak, ślepa zachęta nie.
//
// Wcześniejszy komentarz mówił „Reader App" (Apple 3.1.3(f)) — to już
// nieaktualne. Aplikacja sprzedaje przez IAP, więc obowiązuje 3.1.3(b)
// Multiplatform Services i przyciski zakupu są dozwolone.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/billing_quota_provider.dart';
import '../providers/billing_surface_provider.dart';
import '../screens/plan_picker_screen.dart';
import '../services/billing_quota_state.dart';
import '../theme/euphire_theme.dart';

/// Static dismiss-state. Session-scoped — reset przy hot reload/restart.
final _dismissedLevels = <QuotaWarningLevel>{};

class QuotaWarningBanner extends ConsumerWidget {
  const QuotaWarningBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingQuotaProvider);
    final canPurchase = ref.watch(canPurchaseProvider);

    return state.maybeWhen(
      data: (q) => _build(context, q, canPurchase),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _build(BuildContext context, QuotaState? q, bool canPurchase) {
    if (q == null || q.warningLevel == QuotaWarningLevel.none) {
      return const SizedBox.shrink();
    }
    final canDismiss = q.warningLevel != QuotaWarningLevel.exhausted;
    if (canDismiss && _dismissedLevels.contains(q.warningLevel)) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context);
    final (bg, fg, accentColor) = _palette(q.warningLevel);

    String headline;
    String? subtitle;
    switch (q.warningLevel) {
      case QuotaWarningLevel.warning:
        headline = l.billing_quota_warning_short(q.tokensRemaining);
        break;
      case QuotaWarningLevel.critical:
        headline = l.billing_quota_critical_short;
        break;
      case QuotaWarningLevel.exhausted:
        headline = l.billing_quota_exhausted_short;
        subtitle = l.billing_quota_exhausted_subtitle;
        break;
      case QuotaWarningLevel.none:
        return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: accentColor, width: 4)),
          boxShadow: EuphireColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(_iconFor(q.warningLevel), color: accentColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      headline,
                      style: TextStyle(
                        color: fg,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (canDismiss)
                    IconButton(
                      icon: Icon(Icons.close, color: fg.withValues(alpha: 0.6), size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _dismissedLevels.add(q.warningLevel);
                        // Trigger rebuild — best-effort via Element marker.
                        // Acceptable: next provider tick will hide it anyway.
                        (context as Element).markNeedsBuild();
                      },
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.85),
                      fontFamily: 'Merriweather',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (q.periodEnd != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    l.billing_period_end_label(_formatDate(q.periodEnd!)),
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.7),
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              if (canPurchase) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings:
                              const RouteSettings(name: 'PlanPickerScreen'),
                          builder: (_) => const PlanPickerScreen(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l.billing_expand_plan_cta,
                        style: TextStyle(
                          color: accentColor,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color, Color) _palette(QuotaWarningLevel level) {
    switch (level) {
      case QuotaWarningLevel.warning:
        return (
          const Color(0xFF2A2418), // dim amber bg
          EuphireColors.frostWhite,
          EuphireColors.ember,
        );
      case QuotaWarningLevel.critical:
        return (
          const Color(0xFF2E1810), // deeper orange bg
          EuphireColors.frostWhite,
          const Color(0xFFE07A2C), // sunset orange
        );
      case QuotaWarningLevel.exhausted:
        return (
          const Color(0xFF2A0E08), // deep magma bg
          EuphireColors.frostWhite,
          EuphireColors.magma,
        );
      case QuotaWarningLevel.none:
        return (
          EuphireColors.surfaceTeal,
          EuphireColors.frostWhite,
          EuphireColors.mist,
        );
    }
  }

  IconData _iconFor(QuotaWarningLevel level) {
    switch (level) {
      case QuotaWarningLevel.warning:
        return Icons.info_outline;
      case QuotaWarningLevel.critical:
        return Icons.warning_amber_outlined;
      case QuotaWarningLevel.exhausted:
        return Icons.block;
      case QuotaWarningLevel.none:
        return Icons.check_circle_outline;
    }
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }
}
