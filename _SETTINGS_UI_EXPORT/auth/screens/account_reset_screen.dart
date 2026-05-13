import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';
import 'package:labirynt_premium/src/features/auth/data/auth_repository.dart';
import 'package:labirynt_premium/src/features/auth/data/user_repository.dart';
import 'package:labirynt_premium/src/core/utils/app_haptics.dart';
import 'package:labirynt_premium/src/core/ui/eu_components.dart';

class AccountResetScreen extends ConsumerStatefulWidget {
  const AccountResetScreen({super.key});

  @override
  ConsumerState<AccountResetScreen> createState() => _AccountResetScreenState();
}

class _AccountResetScreenState extends ConsumerState<AccountResetScreen> {
  bool _agreed = false;
  bool _isLoading = false;

  Future<void> _handleReset() async {
    if (!_agreed || _isLoading) return;

    setState(() => _isLoading = true);
    AppHaptics.heavyImpact(ref);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await ref.read(userRepositoryProvider).resetUser(user.uid);
        if (mounted) {
          EuSnackbar.success(context, context.l10n.accountResetSuccess);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        EuSnackbar.error(context, context.l10n.accountResetError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a typed confirmation bottom sheet requiring user to type "RESETUJ"
  void _showTypedConfirmationSheet() {
    AppHaptics.heavyImpact(ref);
    final confirmWord = context.l10n.accountResetConfirmWord;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _TypedConfirmationSheet(
        confirmWord: confirmWord,
        title: context.l10n.accountResetConfirmTitle,
        body: context.l10n.accountResetConfirmBody,
        buttonLabel: context.l10n.accountResetConfirmButton,
        cancelLabel: context.l10n.cancelButton,
        onConfirmed: () {
          Navigator.pop(sheetContext);
          _handleReset();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.accountResetTitle,
                      style: TextStyle(
                        fontFamily: 'Merriweather',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isLight ? Colors.black87 : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildWarningItem(
                      context.l10n.accountResetWarning1,
                      Icons.history_rounded,
                      isLight,
                    ),
                    _buildWarningItem(
                      context.l10n.accountResetWarning2,
                      Icons.person_off_rounded,
                      isLight,
                    ),
                    _buildWarningItem(
                      context.l10n.accountResetWarning3,
                      Icons.warning_amber_rounded,
                      isLight,
                    ),
                    const Spacer(),

                    // Agreement Switch
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.accountResetAgreement,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: isLight
                                  ? Colors.red.shade700
                                  : Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: _agreed,
                          onChanged: (v) {
                            AppHaptics.lightImpact(ref);
                            setState(() => _agreed = v);
                          },
                          activeThumbColor: Colors.redAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Reset Button - opens typed confirmation sheet
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _agreed ? _showTypedConfirmationSheet : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _agreed
                              ? const Color(0xFFFF0000)
                              : Colors.grey.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                context.l10n.accountResetButton,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem(String text, IconData icon, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFE91E63),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 14,
                color: isLight ? Colors.black87 : Colors.white70,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable typed confirmation bottom sheet.
/// User must type [confirmWord] exactly to enable the confirm button.
class _TypedConfirmationSheet extends StatefulWidget {
  final String confirmWord;
  final String title;
  final String body;
  final String buttonLabel;
  final String cancelLabel;
  final VoidCallback onConfirmed;

  const _TypedConfirmationSheet({
    required this.confirmWord,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.cancelLabel,
    required this.onConfirmed,
  });

  @override
  State<_TypedConfirmationSheet> createState() =>
      _TypedConfirmationSheetState();
}

class _TypedConfirmationSheetState extends State<_TypedConfirmationSheet> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches =
          _controller.text.trim().toUpperCase() ==
          widget.confirmWord.toUpperCase();
      if (matches != _matches) {
        setState(() => _matches = matches);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: EuDesignTokens.nocturne,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EuDesignTokens.frostWhite.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Warning icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EuDesignTokens.error.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: EuDesignTokens.error.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: EuDesignTokens.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              widget.title,
              style: EuTextStyles.h2.copyWith(
                color: EuDesignTokens.frostWhite,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              widget.body,
              style: EuTextStyles.bodyMedium.copyWith(
                color: EuDesignTokens.frostWhite.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Text input field
            TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              autocorrect: false,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                color: EuDesignTokens.frostWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
              decoration: InputDecoration(
                hintText: widget.confirmWord,
                hintStyle: TextStyle(
                  fontFamily: 'RobotoMono',
                  color: EuDesignTokens.frostWhite.withValues(alpha: 0.2),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
                filled: true,
                fillColor: EuDesignTokens.frostWhite.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _matches ? EuDesignTokens.error : Colors.transparent,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: EuDesignTokens.frostWhite.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _matches
                        ? EuDesignTokens.error
                        : EuDesignTokens.ember,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Confirm button (enabled only when typed word matches)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _matches ? widget.onConfirmed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _matches
                      ? const Color(0xFFFF0000)
                      : Colors.grey.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
                  disabledForegroundColor: Colors.white38,
                ),
                child: Text(
                  widget.buttonLabel,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                widget.cancelLabel,
                style: EuTextStyles.button.copyWith(
                  color: EuDesignTokens.frostWhite.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
