// EmailVerificationBanner — sticky przypomnienie po pominięciu weryfikacji
// adresu (docs/70 S1 krok 3).
//
// Świadomie NIE jest zamykalny: to jedyny ślad po nieblokującym ekranie
// „Sprawdź skrzynkę", a bez potwierdzonego adresu kolejka uploadów i tak
// zaparkuje nagrania. Znika sam, gdy adres zostanie potwierdzony.
//
// Nie blokuje niczego w UI — w szczególności nie dotyka nagrywania (UX-1).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/email_verification_provider.dart';
import '../screens/verify_email_screen.dart';
import '../theme/euphire_theme.dart';

class EmailVerificationBanner extends ConsumerWidget {
  const EmailVerificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(needsEmailVerificationProvider)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2418),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: EuphireColors.ember, width: 4),
        ),
        boxShadow: EuphireColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.mark_email_unread_outlined,
                color: EuphireColors.ember, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.verify_email_banner_title,
                    style: const TextStyle(
                      color: EuphireColors.frostWhite,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.verify_email_banner_body,
                    style: TextStyle(
                      color: EuphireColors.frostWhite.withValues(alpha: 0.85),
                      fontFamily: 'Merriweather',
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'VerifyEmailScreen'),
                  builder: (_) => const VerifyEmailScreen(),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.verify_email_banner_action,
                style: const TextStyle(
                  color: EuphireColors.ember,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
