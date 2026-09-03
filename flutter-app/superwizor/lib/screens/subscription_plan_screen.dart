// SubscriptionPlanScreen — plan, pula sesji i zarządzanie subskrypcją.
//
// Dwa źródła danych, celowo rozdzielone:
//   • `billingQuotaProvider` — ile tokenów zostało (clinical-svc).
//   • `billingSurfaceProvider` — KTO sprzedał subskrypcję i co wolno z nią
//     zrobić na tej platformie (billing-svc, docs/70 §7.2).
//
// Zarządzanie zależy od dostawcy (docs/70 §2.3, S4, S5):
//   • APPLE_IAP / GOOGLE_IAP → „Zarządzaj subskrypcją" jako deep link do
//     ustawień sklepu. To jedyne dozwolone wyjście z aplikacji przy
//     `web_link_mode == NONE` — zarządzanie własnym IAP jest wprost
//     dozwolone, w przeciwieństwie do kierowania do innego sprzedawcy.
//   • STRIPE → sam TEKST „zarządzasz na superwizor.ai", BEZ klikalnego
//     linku, dopóki serwer trzyma `web_link_mode == NONE` (Apple 3.1.1).
//   • MANUAL / P24 (klinika, beta) → „Planem zarządza Twoja organizacja".
//
// Stany awaryjne sklepu mają własne komunikaty: `grace_until` (płatność się
// nie powiodła, dostęp trwa), PAST_DUE (dostęp wstrzymany) i PAUSED
// (Google Play, subskrypcja zapauzowana) prowadzą do sklepu, nie do
// ustawień płatności na webie.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/billing_quota_provider.dart';
import '../providers/billing_surface_provider.dart';
import '../services/billing_quota_state.dart';
import '../services/billing_surface_state.dart';
import '../services/store_links.dart';
import '../services/store_purchase_service.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_toast.dart';
import 'plan_picker_screen.dart';

class SubscriptionPlanScreen extends ConsumerWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final quota = ref.watch(billingQuotaProvider);
    final surface = ref.watch(billingSurfaceProvider).value ??
        const BillingSurfaceState.unavailable();

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
          await ref.read(billingSurfaceProvider.notifier).refresh();
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBanner(quota: q, surface: surface),
                  _PlanCard(quota: q),
                  const SizedBox(height: 24),
                  _ManagementSection(quota: q, surface: surface),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Otwiera ustawienia subskrypcji właściwego sklepu. Serwer może podać własny
/// `manage_url` (np. link do konkretnej subskrypcji w Play) — wtedy wygrywa on.
Future<void> _openStoreSubscriptions(
  BuildContext context,
  BillingSurfaceState surface, {
  String? productId,
}) async {
  final l = AppLocalizations.of(context);
  final target = surface.manageUrl.isNotEmpty
      ? surface.manageUrl
      : storeSubscriptionsUrl(currentStorePlatform(), productId: productId);
  final uri = target == null ? null : Uri.tryParse(target);
  if (uri == null) {
    EuphireToast.error(context, message: l.subscription_open_store_failed);
    return;
  }
  final opened =
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    EuphireToast.error(context, message: l.subscription_open_store_failed);
  }
}

/// Banery stanów awaryjnych. Każdy z nich ma inny komunikat, bo każdy wymaga
/// od użytkownika czegoś innego — sklejenie ich w jedno „problem z płatnością"
/// wysyłałoby połowę osób do naprawiania karty, która działa.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.quota, required this.surface});

  final QuotaState quota;
  final BillingSurfaceState surface;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    // PAUSED (Google Play): świadoma pauza użytkownika, nie awaria płatności.
    if (quota.status == 'PAUSED') {
      return _Banner(
        icon: Icons.pause_circle_outline,
        accent: EuphireColors.ember,
        title: l.subscription_paused_title,
        body: l.subscription_paused_body,
        actionLabel:
            quota.isStoreProvider ? l.subscription_resume_in_store : null,
        onAction: () => _openStoreSubscriptions(context, surface),
      );
    }

    // PAST_DUE: dostęp wstrzymany, opłata nie przeszła.
    if (quota.status == 'PAST_DUE') {
      return _Banner(
        icon: Icons.error_outline,
        accent: EuphireColors.magma,
        title: l.billing_past_due_title,
        body: l.subscription_past_due_body,
        // Dla Stripe świadomie BEZ przycisku — link poza aplikację byłby
        // kierowaniem do innego sprzedawcy (Apple 3.1.1). Dunning idzie
        // e-mailem, poza aplikacją, i to jest legalne.
        actionLabel: quota.isStoreProvider ? l.subscription_fix_payment : null,
        onAction: () => _openStoreSubscriptions(context, surface),
      );
    }

    // Okres łaski: dostęp DZIAŁA, ale zaraz przestanie (docs/70 E13).
    if (quota.inGracePeriod) {
      return _Banner(
        icon: Icons.schedule,
        accent: EuphireColors.ember,
        title: l.subscription_grace_title,
        body: l.subscription_grace_body(_formatDate(quota.graceUntil!)),
        actionLabel: quota.isStoreProvider ? l.subscription_fix_payment : null,
        onAction: () => _openStoreSubscriptions(context, surface),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.onAction,
    this.actionLabel,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: EuphireColors.surfaceTeal,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: EuphireColors.frostWhite,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              body,
              style: const TextStyle(
                color: EuphireColors.mist,
                fontFamily: 'Merriweather',
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          if (actionLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      color: accent,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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

/// Dostawca + wszystko, co da się z subskrypcją zrobić na tej platformie.
class _ManagementSection extends ConsumerStatefulWidget {
  const _ManagementSection({required this.quota, required this.surface});

  final QuotaState quota;
  final BillingSurfaceState surface;

  @override
  ConsumerState<_ManagementSection> createState() => _ManagementSectionState();
}

class _ManagementSectionState extends ConsumerState<_ManagementSection> {
  bool _restoring = false;

  String? _providerLabel(AppLocalizations l) {
    switch (widget.quota.billingProvider) {
      case 'APPLE_IAP':
        return l.subscription_provider_apple;
      case 'GOOGLE_IAP':
        return l.subscription_provider_google;
      case 'STRIPE':
        return l.subscription_provider_stripe;
      case 'MANUAL':
      case 'P24':
        return l.subscription_provider_manual;
      default:
        return null;
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final result = await ref.read(storePurchaseServiceProvider).restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    final l = AppLocalizations.of(context);
    if (result.isSuccess) {
      EuphireToast.success(context, message: l.purchase_restore_success);
    } else if (result.outcome == StorePurchaseOutcome.nothingToRestore) {
      EuphireToast.info(context, message: l.purchase_restore_none);
    } else if (result.outcome == StorePurchaseOutcome.foreignAccount) {
      EuphireToast.error(context, message: l.purchase_error_foreign_account);
    } else {
      EuphireToast.error(context, message: l.purchase_error_generic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final quota = widget.quota;
    final surface = widget.surface;
    final providerLabel = _providerLabel(l);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (providerLabel != null) ...[
          _InfoRow(label: l.subscription_provider_label, value: providerLabel),
          const SizedBox(height: 12),
        ],
        if (quota.cancelAtPeriodEnd && quota.periodEnd != null) ...[
          Text(
            l.subscription_cancel_at_period_end(_formatDate(quota.periodEnd!)),
            style: const TextStyle(
              color: EuphireColors.mist,
              fontFamily: 'Merriweather',
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Subskrypcja sklepowa → deep link. Dozwolone i wymagane.
        if (quota.isStoreProvider)
          _ActionButton(
            icon: Icons.open_in_new,
            label: l.subscription_manage_button,
            onPressed: () => _openStoreSubscriptions(context, surface),
          ),

        // Stripe → sam tekst. Klikalny link byłby kierowaniem do innego
        // sprzedawcy; wolno go pokazać dopiero, gdy serwer podniesie
        // `web_link_mode` (analiza DMA — docs/70 R6).
        if (quota.billingProvider == 'STRIPE')
          Text(
            l.subscription_manage_stripe_note,
            style: const TextStyle(
              color: EuphireColors.mist,
              fontFamily: 'Merriweather',
              fontSize: 13,
              height: 1.5,
            ),
          ),

        // Plan przydzielony przez organizację — paywall ukryty z definicji.
        if (quota.billingProvider == 'MANUAL' ||
            quota.billingProvider == 'P24')
          Text(
            l.subscription_manage_org_note,
            style: const TextStyle(
              color: EuphireColors.mist,
              fontFamily: 'Merriweather',
              fontSize: 13,
              height: 1.5,
            ),
          ),

        // Zakup / zmiana planu — wyłącznie za zgodą serwera.
        if (surface.commerceEnabled) ...[
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.workspace_premium_outlined,
            label: l.subscription_choose_plan,
            primary: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'PlanPickerScreen'),
                builder: (_) => const PlanPickerScreen(),
              ),
            ),
          ),
        ],

        // „Przywróć zakupy" — wymóg Apple 3.1.2, sterowany przez serwer.
        if (surface.showRestore) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: _restoring ? null : _restore,
            child: _restoring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: EuphireColors.mist),
                  )
                : Text(
                    l.plan_picker_restore,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: EuphireColors.mist,
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: EuphireColors.mist,
            fontFamily: 'Montserrat',
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: EuphireColors.frostWhite,
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: primary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label, style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              )),
              style: ElevatedButton.styleFrom(
                backgroundColor: EuphireColors.ember,
                foregroundColor: EuphireColors.obsidianBlack,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label, style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
              style: OutlinedButton.styleFrom(
                foregroundColor: EuphireColors.frostWhite,
                side: const BorderSide(color: EuphireColors.glassBorder),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }
}

String _formatDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.quota});

  final QuotaState quota;

  String _tierLabel(AppLocalizations l) {
    switch (quota.planTier) {
      case 'SOLO': return l.subscription_tier_solo;
      case 'PRO': return l.subscription_tier_pro;
      case 'CLINIC': return l.subscription_tier_clinic;
      case 'TRIAL': return l.subscription_tier_trial;
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
            fontFamily: 'Montserrat',
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
                  fontFamily: 'Montserrat',
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
                    fontFamily: 'Montserrat',
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
                    fontFamily: 'Montserrat',
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
                  fontFamily: 'Montserrat',
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
