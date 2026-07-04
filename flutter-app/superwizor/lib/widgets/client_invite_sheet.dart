// ClientInviteSheet — "Zaproś klienta" from the kartoteka (docs/39).
// Shows the current invite status (NONE / PENDING / ACTIVE / INACTIVE)
// via IdentityService.GetClientInviteStatus and lets the therapist send
// (or re-send) the magic-link invitation via InviteClient. Same
// mechanism as the org-manager invite — token refresh on re-invite.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import 'package:intl/intl.dart';

import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import '../l10n/app_localizations.dart';
import '../models/patient.dart';
import '../providers/grpc_provider.dart';
import '../theme/euphire_theme.dart';

/// Live invite status for a kartoteka. autoDispose so re-opening the
/// sheet always re-checks (the status changes out-of-band when the
/// client accepts).
final clientInviteStatusProvider = FutureProvider.autoDispose
    .family<identity_pb.ClientInviteStatus, String>((ref, patientFileId) {
  final identity = ref.watch(grpcClientsProvider).identity;
  return identity.getClientInviteStatus(
    identity_pb.GetClientInviteStatusRequest(patientFileId: patientFileId),
  );
});

void showClientInviteSheet(
  BuildContext context, {
  required Patient patient,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ClientInviteSheet(patient: patient),
  );
}

class ClientInviteSheet extends ConsumerStatefulWidget {
  const ClientInviteSheet({super.key, required this.patient});
  final Patient patient;

  @override
  ConsumerState<ClientInviteSheet> createState() => _ClientInviteSheetState();
}

class _ClientInviteSheetState extends ConsumerState<ClientInviteSheet> {
  late final TextEditingController _emailCtrl;
  bool _sending = false;
  String? _error;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.patient.email);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final l = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = l.invite_client_email_missing);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final identity = ref.read(grpcClientsProvider).identity;
      await identity.inviteClient(identity_pb.InviteClientRequest(
        patientFileId: widget.patient.id,
        email: email,
      ));
      ref.invalidate(clientInviteStatusProvider(widget.patient.id));
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
      }
    } on GrpcError catch (e) {
      if (!mounted) return;
      final msg = e.message ?? '';
      setState(() {
        _sending = false;
        _error = msg.startsWith('CLIENT_EMAIL_TAKEN')
            ? l.invite_client_email_taken
            : msg.startsWith('CLIENT_EMAIL_MISSING')
                ? l.invite_client_email_missing
                : l.invite_client_error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = AppLocalizations.of(context).invite_client_error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statusAsync =
        ref.watch(clientInviteStatusProvider(widget.patient.id));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2326),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: EuphireColors.ember.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: EuphireColors.ember,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.invite_client_title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontStyle: FontStyle.italic,
                    fontSize: 20,
                    color: EuphireColors.frostWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.invite_client_desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    height: 1.5,
                    color: EuphireColors.mist.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 20),
                statusAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: EuphireColors.ember),
                    ),
                  ),
                  error: (err, _) => _statusChip(
                    icon: Icons.error_outline,
                    color: EuphireColors.magma,
                    text: l.invite_client_error,
                  ),
                  data: (status) => _buildBody(l, status),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l, identity_pb.ClientInviteStatus s) {
    switch (s.status) {
      case 'ACTIVE':
        return _statusChip(
          icon: Icons.verified_rounded,
          color: const Color(0xFF81C784),
          text: l.invite_client_status_active,
        );
      case 'INACTIVE':
        return _statusChip(
          icon: Icons.block_rounded,
          color: EuphireColors.magma,
          text: l.invite_client_status_inactive,
        );
      case 'PENDING':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusChip(
              icon: Icons.hourglass_top_rounded,
              color: EuphireColors.ember,
              text: l.invite_client_status_pending(
                s.email,
                s.hasExpiresAt()
                    ? DateFormat('d MMM yyyy')
                        .format(s.expiresAt.toDateTime().toLocal())
                    : '—',
              ),
            ),
            const SizedBox(height: 16),
            _sendButton(l, resend: true),
          ],
        );
      default: // NONE
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 15,
                color: EuphireColors.frostWhite,
              ),
              decoration: InputDecoration(
                labelText: l.invite_client_email_label,
                labelStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  color: EuphireColors.mist.withValues(alpha: 0.7),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: EuphireColors.ember,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sendButton(l, resend: false),
          ],
        );
    }
  }

  Widget _sendButton(AppLocalizations l, {required bool resend}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              color: EuphireColors.magma,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_sent) ...[
          Text(
            l.invite_client_sent,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF81C784),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: _sending ? null : _sendInvite,
          style: ElevatedButton.styleFrom(
            backgroundColor: EuphireColors.ember,
            foregroundColor: EuphireColors.obsidianBlack,
            disabledBackgroundColor:
                EuphireColors.ember.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: EuphireColors.obsidianBlack,
                  ),
                )
              : Text(
                  resend ? l.invite_client_resend : l.invite_client_send,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _statusChip({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                height: 1.4,
                color: EuphireColors.frostWhite.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
