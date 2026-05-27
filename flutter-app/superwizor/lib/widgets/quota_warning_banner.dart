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
// No upgrade CTA — the banner is informational only. Plan management lives
// in subscription_plan_screen reached from the menu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/billing_quota_provider.dart';
import '../services/billing_quota_listener.dart';
import '../theme/euphire_theme.dart';

/// Static dismiss-state. Session-scoped — reset przy hot reload/restart.
final _dismissedLevels = <QuotaWarningLevel>{};

class QuotaWarningBanner extends ConsumerWidget {
  const QuotaWarningBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingQuotaProvider);

    return state.maybeWhen(
      data: (q) => _build(context, q),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _build(BuildContext context, QuotaState? q) {
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
                      fontFamily: 'RobotoMono',
                      fontSize: 11,
                      letterSpacing: 0.5,
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
