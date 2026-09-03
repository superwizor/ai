// QuotaExhaustedDialog — nieblokujący dialog, gdy ingestion-svc / clinical-svc
// zwróci ResourceExhausted / QUOTA_EXHAUSTED.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §16.4.1 + UX-1, docs/70 S2.
//
// REGUŁA NADRZĘDNA (UX-1): nie wolno zablokować nagrywania. „Nagrywaj
// lokalnie" jest tu zawsze — niezależnie od tego, czy da się kupić plan,
// czy nie. Audio szyfruje się na urządzeniu i czeka na wolny token.
//
// Zgodność ze sklepami — stan po dodaniu IAP (docs/70 §2.1):
// aplikacja opiera się na wytycznej Apple **3.1.3(b) Multiplatform
// Services**, nie na 3.1.3(f). Do 09/2026 był tu komentarz „Reader App"
// i zero przycisków zakupu, bo aplikacja nie sprzedawała niczego. Teraz
// sprzedaje przez IAP, więc przycisk „Wybierz plan" jest DOZWOLONY —
// prowadzi do paywalla ze StoreKit/Play, nigdy poza aplikację. Pokazujemy
// go wyłącznie, gdy serwer potwierdzi `can_purchase` (klinika z alokacją
// miejsc, aktywny Stripe czy wyłączona flaga IAP muszą zobaczyć dialog bez
// tego przycisku).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/billing_surface_provider.dart';
import '../screens/plan_picker_screen.dart';
import '../theme/euphire_theme.dart';

enum QuotaExhaustedChoice {
  cancel,
  recordLocally,

  /// Użytkownik wybrał paywall. Wywołujący nic nie musi robić — dialog sam
  /// otwiera `PlanPickerScreen`; wynik jest tu po to, żeby nie potraktować
  /// tego jak anulowania.
  choosePlan,
}

Future<QuotaExhaustedChoice> showQuotaExhaustedDialog(
    BuildContext context) async {
  final l = AppLocalizations.of(context);
  final choice = await showDialog<QuotaExhaustedChoice>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: EuphireColors.surfaceTeal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.block, color: EuphireColors.magma, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.billing_exhausted_dialog_title,
              style: const TextStyle(
                color: EuphireColors.frostWhite,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        l.billing_exhausted_dialog_body,
        style: const TextStyle(
          color: EuphireColors.mist,
          fontFamily: 'Merriweather',
          fontSize: 13,
          height: 1.5,
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, QuotaExhaustedChoice.cancel),
          child: Text(
            l.common_cancel,
            style: const TextStyle(
              color: EuphireColors.mist,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // „Wybierz plan" tylko za zgodą serwera. Brak zgody = brak przycisku,
        // NIE przycisk prowadzący do komunikatu o odmowie.
        Consumer(
          builder: (consumerCtx, widgetRef, _) {
            if (!widgetRef.watch(canPurchaseProvider)) {
              return const SizedBox.shrink();
            }
            return TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, QuotaExhaustedChoice.choosePlan),
              child: Text(
                l.billing_choose_plan_cta,
                style: const TextStyle(
                  color: EuphireColors.ember,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
        // UX-1: zostaje zawsze i zawsze jako akcja główna.
        FilledButton(
          onPressed: () =>
              Navigator.pop(ctx, QuotaExhaustedChoice.recordLocally),
          style: FilledButton.styleFrom(
            backgroundColor: EuphireColors.ember,
            foregroundColor: EuphireColors.obsidianBlack,
          ),
          child: Text(
            l.billing_exhausted_dialog_record_locally,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  if (choice == QuotaExhaustedChoice.choosePlan && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'PlanPickerScreen'),
      builder: (_) => const PlanPickerScreen(),
    ));
    return QuotaExhaustedChoice.choosePlan;
  }
  return choice ?? QuotaExhaustedChoice.cancel;
}
