// SubscriptionPlanScreen — pokazuje tier / cycle / sessions left.
//
// Data source: billingQuotaProvider (Firestore mirror z lokalnym
// offsetem rezerwacji). Refresh: ręczny przez "Odśwież" (re-invalidates
// provider, triggeruje nowe subscribe) lub automatyczny gdy backend
// emituje quota event który zmienia mirror doc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/billing_quota_provider.dart';
import '../services/billing_quota_listener.dart';
import '../theme/euphire_theme.dart';

class SubscriptionPlanScreen extends ConsumerWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final quota = ref.watch(billingQuotaProvider);

    return Scaffold(
      backgroundColor: EuphireColors.deepTealBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l.subscription_screen_title,
          style: const TextStyle(
            color: EuphireColors.frostWhite,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: EuphireColors.frostWhite),
      ),
      body: RefreshIndicator(
        color: EuphireColors.ember,
        onRefresh: () async {
          // ignore: unused_result
          ref.invalidate(billingQuotaProvider);
          // Wait briefly for the new subscription to deliver first snapshot.
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: quota.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator(color: EuphireColors.ember)),
            ),
            error: (e, _) => _NoDataCard(message: e.toString()),
            data: (q) {
              if (q == null) return const _NoDataCard();
              return _PlanCard(quota: q);
            },
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.quota});

  final QuotaState quota;

  String _tierLabel(AppLocalizations l) {
    switch (quota.planTier) {
      case 'SOLO': return l.subscription_tier_solo;
      case 'PRO': return l.subscription_tier_pro;
      case 'CLINIC': return l.subscription_tier_clinic;
      default: return quota.planTier;
    }
  }

  String _cycleLabel(AppLocalizations l) {
    switch (quota.planCycle) {
      case 'MONTHLY': return l.subscription_cycle_monthly;
      case 'SEMI_ANNUAL': return l.subscription_cycle_semi_annual;
      case 'ANNUAL': return l.subscription_cycle_annual;
      default: return quota.planCycle;
    }
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  Color _accentForLevel() {
    switch (quota.warningLevel) {
      case QuotaWarningLevel.exhausted:
        return EuphireColors.magma;
      case QuotaWarningLevel.critical:
        return const Color(0xFFE07A2C);
      case QuotaWarningLevel.warning:
        return EuphireColors.ember;
      case QuotaWarningLevel.none:
        return EuphireColors.mist;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = _accentForLevel();
    final tier = _tierLabel(l);
    final cycle = _cycleLabel(l);
    final headline = cycle.isNotEmpty ? '$tier · $cycle' : tier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.subscription_plan_section_header,
          style: const TextStyle(
            color: EuphireColors.mist,
            fontFamily: 'RobotoMono',
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: EuphireColors.surfaceTeal,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: accent, width: 4)),
            boxShadow: EuphireColors.cardShadow,
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: const TextStyle(
                  color: EuphireColors.frostWhite,
                  fontFamily: 'Montserrat',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.subscription_sessions_per_period(quota.tokensLimit),
                style: const TextStyle(
                  color: EuphireColors.mist,
                  fontFamily: 'Merriweather',
                  fontSize: 13,
                ),
              ),
              const Divider(color: EuphireColors.glassBorder, height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    quota.tokensRemaining.toString(),
                    style: TextStyle(
                      color: accent,
                      fontFamily: 'Montserrat',
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l.subscription_sessions_left(quota.tokensRemaining).split(' ').sublist(1).join(' '),
                      style: const TextStyle(
                        color: EuphireColors.frostWhite,
                        fontFamily: 'Merriweather',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.subscription_sessions_used(quota.tokensUsed, quota.tokensLimit),
                style: TextStyle(
                  color: EuphireColors.mist,
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              if (quota.tokensReserved > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '+ ${quota.tokensReserved} zarezerwowane',
                  style: TextStyle(
                    color: EuphireColors.ember.withValues(alpha: 0.85),
                    fontFamily: 'RobotoMono',
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              if (quota.periodEnd != null) ...[
                const SizedBox(height: 4),
                Text(
                  l.subscription_period_ends(_formatDate(quota.periodEnd!)),
                  style: TextStyle(
                    color: EuphireColors.mist.withValues(alpha: 0.85),
                    fontFamily: 'RobotoMono',
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NoDataCard extends StatelessWidget {
  const _NoDataCard({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            const Icon(Icons.help_outline, color: EuphireColors.mist, size: 48),
            const SizedBox(height: 16),
            Text(
              l.subscription_no_data_title,
              style: const TextStyle(
                color: EuphireColors.frostWhite,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l.subscription_no_data_body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EuphireColors.mist,
                  fontFamily: 'Merriweather',
                  fontSize: 13,
                ),
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                  color: EuphireColors.magma,
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
