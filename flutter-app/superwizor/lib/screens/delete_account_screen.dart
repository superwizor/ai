// delete_account_screen.dart — usuwanie konta w aplikacji (Apple 5.1.1(v)).
//
// Przepływ:
//   1. Ekran z listą konsekwencji + toggle „rozumiem"
//   2. Bottom sheet: wpisz słowo potwierdzenia + opcjonalny powód
//   3. `identity.DeleteMyAccount` — to SERWER usuwa konto i całą
//      dokumentację; skasowanie samej tożsamości Firebase (co robił ten
//      ekran do 09/2026) zostawiało kartoteki, sesje i raporty w bazie,
//      a użytkownikowi odbierało jedyną drogę, żeby się o nie upomnieć.
//   4. Wylogowanie i powrót na ekran startowy.
//
// Aktywna subskrypcja sklepowa (docs/70 E5): App Store nie daje nam żadnego
// API do anulowania cudzej subskrypcji — może to zrobić wyłącznie właściciel
// konta Apple. Serwer odrzuca wtedy żądanie przez `FAILED_PRECONDITION
// STORE_SUBSCRIPTION_ACTIVE`, a my pokazujemy deep link do ustawień
// subskrypcji i dopiero po świadomym potwierdzeniu wysyłamy
// `acknowledged_subscription: true`. Bez tego kroku ludzie kasowaliby konto
// i płacili dalej.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:url_launcher/url_launcher.dart';

import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import '../l10n/app_localizations.dart';
import '../providers/billing_surface_provider.dart';
import '../providers/grpc_provider.dart';
import '../services/store_links.dart';
import '../theme/euphire_theme.dart';
import '../widgets/euphire_toast.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _understands = false;

  Future<void> _onDeletePressed() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ConfirmDeleteSheet(),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: EuphireColors.nocturne,
      body: Container(
        decoration: const BoxDecoration(gradient: EuphireColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back + Title ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: EuphireColors.frostWhite, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                child: Text(
                  t.delete_account_title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: 'Merriweather',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                  ),
                ),
              ),

              // ── Lista konsekwencji ────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ConsequenceItem(t.delete_account_consequence_1),
                      const SizedBox(height: 20),
                      _ConsequenceItem(t.delete_account_consequence_2),
                      const SizedBox(height: 20),
                      _ConsequenceItem(t.delete_account_consequence_3),
                    ],
                  ),
                ),
              ),

              // ── Stopka sticky: toggle + przycisk ─────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wiersz toggle
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.delete_account_toggle_text,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: EuphireColors.magma,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _understands,
                          onChanged: (v) => setState(() => _understands = v),
                          activeThumbColor: Colors.white,
                          activeTrackColor: EuphireColors.magma,
                          inactiveThumbColor: EuphireColors.mist,
                          inactiveTrackColor: EuphireColors.mist.withValues(alpha: 0.2),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Przycisk — aktywny gdy toggle ON
                    AnimatedOpacity(
                      opacity: _understands ? 1.0 : 0.35,
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _understands ? _onDeletePressed : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EuphireColors.magma,
                            disabledBackgroundColor: EuphireColors.magma,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            t.delete_account_button,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Wiersz z czerwoną ikonką check ──────────────────────────

class _ConsequenceItem extends StatelessWidget {
  final String text;
  const _ConsequenceItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: EuphireColors.magma,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 15,
              color: EuphireColors.frostWhite,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom Sheet — wpisz USUWAM ─────────────────────────────

class _ConfirmDeleteSheet extends ConsumerStatefulWidget {
  const _ConfirmDeleteSheet();

  @override
  ConsumerState<_ConfirmDeleteSheet> createState() =>
      _ConfirmDeleteSheetState();
}

class _ConfirmDeleteSheetState extends ConsumerState<_ConfirmDeleteSheet> {
  final _ctrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _confirmed = false;
  bool _deleting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl.removeListener(_onTextChanged);
    _ctrl.addListener(_onTextChanged);
    _onTextChanged();
  }

  void _onTextChanged() {
    final expected = AppLocalizations.of(context).delete_account_confirm_word;
    final ok = _ctrl.text.trim().toLowerCase() == expected.toLowerCase();
    if (ok != _confirmed) setState(() => _confirmed = ok);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete({bool acknowledgedSubscription = false}) async {
    if (!_confirmed) return;
    setState(() => _deleting = true);
    final t = AppLocalizations.of(context);
    try {
      await ref.read(grpcClientsProvider).identity.deleteMyAccount(
            identity_pb.DeleteMyAccountRequest(
              confirmation: _ctrl.text.trim(),
              reason: _reasonCtrl.text.trim(),
              acknowledgedSubscription: acknowledgedSubscription,
            ),
          );
    } on grpc.GrpcError catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      // Aktywna subskrypcja sklepowa — nie odmowa, tylko brakujące
      // potwierdzenie od użytkownika (docs/70 E5).
      if (e.code == grpc.StatusCode.failedPrecondition &&
          (e.message ?? '').contains('STORE_SUBSCRIPTION_ACTIVE')) {
        await _showStoreSubscriptionWarning();
        return;
      }
      EuphireToast.error(context, message: t.delete_account_failed);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      EuphireToast.error(context, message: t.delete_account_failed);
      return;
    }

    // Konto po stronie serwera już nie istnieje — sesja Firebase musi
    // zniknąć razem z nim, inaczej aplikacja wróci do ekranu „nie znaleziono
    // konta" zamiast do logowania.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[delete-account] signOut: $e');
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Ostrzeżenie o aktywnej subskrypcji: deep link do sklepu i świadome
  /// „usuń mimo to". Deep link do WŁASNEJ subskrypcji jest dozwolony nawet
  /// przy `web_link_mode == NONE` — to zarządzanie IAP, nie steering.
  Future<void> _showStoreSubscriptionWarning() async {
    final t = AppLocalizations.of(context);
    final surface = ref.read(billingSurfaceProvider).value;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EuphireColors.surfaceTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          t.delete_account_store_sub_title,
          style: const TextStyle(
            color: EuphireColors.frostWhite,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        content: Text(
          t.delete_account_store_sub_body,
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
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t.common_cancel,
              style: const TextStyle(
                color: EuphireColors.mist,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final target = surface != null && surface.manageUrl.isNotEmpty
                  ? surface.manageUrl
                  : storeSubscriptionsUrl(currentStorePlatform());
              final uri = target == null ? null : Uri.tryParse(target);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              t.delete_account_store_sub_open,
              style: const TextStyle(
                color: EuphireColors.ember,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t.delete_account_store_sub_force,
              style: const TextStyle(
                color: EuphireColors.magma,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (proceed == true && mounted) {
      await _delete(acknowledgedSubscription: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Padding(
      // Przesuwa sheet nad klawiaturę
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A2326),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 24),

                // Ikona
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EuphireColors.magma.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: EuphireColors.magma.withValues(alpha: 0.3),
                        blurRadius: 28, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: EuphireColors.magma, size: 32),
                ),
                const SizedBox(height: 16),

                Text(
                  t.delete_account_sheet_title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Merriweather',
                    fontStyle: FontStyle.italic,
                    color: EuphireColors.frostWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  t.delete_account_sheet_subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(color: EuphireColors.mist),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  t.delete_account_confirm_word,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: 'Montserrat',
                    color: EuphireColors.magma,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),

                // Pole tekstowe
                TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: EuphireColors.frostWhite,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: t.delete_account_sheet_hint,
                    hintStyle: TextStyle(
                      fontFamily: 'Montserrat', fontSize: 14,
                      color: EuphireColors.mist.withValues(alpha: 0.4),
                      letterSpacing: 1,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _confirmed
                            ? EuphireColors.magma
                            : EuphireColors.mist.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    suffixIcon: _confirmed
                        ? const Icon(Icons.check_circle,
                            color: EuphireColors.magma, size: 22)
                        : null,
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                ),
                const SizedBox(height: 16),

                // Powód — opcjonalny, trafia do audytu (nie do CRM).
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 14,
                    color: EuphireColors.frostWhite,
                  ),
                  decoration: InputDecoration(
                    labelText: t.delete_account_reason_label,
                    labelStyle: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: EuphireColors.mist.withValues(alpha: 0.8),
                    ),
                    hintText: t.delete_account_reason_hint,
                    hintStyle: TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 12,
                      color: EuphireColors.mist.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),

                // Przycisk
                AnimatedOpacity(
                  opacity: _confirmed ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed:
                          _confirmed && !_deleting ? () => _delete() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EuphireColors.magma,
                        disabledBackgroundColor: EuphireColors.magma,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _deleting
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              t.delete_account_sheet_button,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    t.delete_account_sheet_cancel,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: EuphireColors.mist.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
