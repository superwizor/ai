// QuotaExhaustedDialog — non-blocking dialog when ingestion-svc / clinical-svc
// returns ResourceExhausted / QUOTA_EXHAUSTED.
//
// Reference: docs/16_BILLING_SERVICE_PHASE_3.md §16.4.1 + UX-1.
//
// Critical UX rule (UX-1, design doc): NIE wolno zablokować nagrywania.
// Three actions:
//   - Anuluj           → returns QuotaExhaustedChoice.cancel
//   - Rozszerz plan    → QuotaExhaustedChoice.upgrade (caller may navigate)
//   - Nagrywaj lokalnie → QuotaExhaustedChoice.recordLocally — caller
//                          continues recording into encrypted local store.
//                          Audio survives until tokens refresh.

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/euphire_theme.dart';

enum QuotaExhaustedChoice {
  cancel,
  upgrade,
  recordLocally,
}

Future<QuotaExhaustedChoice> showQuotaExhaustedDialog(BuildContext context) async {
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
      actionsAlignment: MainAxisAlignment.spaceBetween,
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
        TextButton(
          onPressed: () => Navigator.pop(ctx, QuotaExhaustedChoice.upgrade),
          child: Text(
            l.billing_expand_plan_cta,
            style: const TextStyle(
              color: EuphireColors.frostWhite,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, QuotaExhaustedChoice.recordLocally),
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
  return choice ?? QuotaExhaustedChoice.cancel;
}
