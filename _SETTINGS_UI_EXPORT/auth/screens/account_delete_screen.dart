import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:labirynt_premium/src/core/theme/app_theme.dart';
import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';
import 'package:labirynt_premium/src/features/auth/data/auth_repository.dart';
import 'package:labirynt_premium/src/core/utils/app_haptics.dart';

class AccountDeleteScreen extends ConsumerStatefulWidget {
  const AccountDeleteScreen({super.key});

  @override
  ConsumerState<AccountDeleteScreen> createState() =>
      _AccountDeleteScreenState();
}

class _AccountDeleteScreenState extends ConsumerState<AccountDeleteScreen> {
  bool _agreed = false;
  bool _isLoading = false;

  Future<void> _handleDelete() async {
    if (!_agreed || _isLoading) return;

    setState(() => _isLoading = true);
    AppHaptics.heavyImpact(ref);

    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // On success, AuthGate will catch signed out state and show LoginScreen
    } catch (e) {
      if (mounted) {
        // Handle "requires-recent-login" specially
        if (e.toString().contains("requires-recent-login")) {
          EuSnackbar.error(
            context,
            context.l10n.accountDeleteRequiresRecentLogin,
          );
        } else {
          EuSnackbar.error(
            context,
            context.l10n.accountDeleteError(e.toString()),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a typed confirmation bottom sheet requiring user to type "USUŃ"
  void _showTypedConfirmationSheet() {
    AppHaptics.heavyImpact(ref);
    final confirmWord = context.l10n.accountDeleteConfirmWord;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _TypedConfirmationSheet(
        confirmWord: confirmWord,
        title: context.l10n.accountDeleteConfirmTitle,
        body: context.l10n.accountDeleteConfirmBody,
        buttonLabel: context.l10n.accountDeleteConfirmButton,
        cancelLabel: context.l10n.cancelButton,
        onConfirmed: () {
          Navigator.pop(sheetContext);
          _handleDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = Theme.of(context).colorScheme.onSurface;

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
                    onPressed: () => context.pop(),
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
                      context.l10n.accountDeleteTitle,
                      style: AppTheme.textTheme.displayLarge?.copyWith(
                        fontSize: 32,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildWarningItem(
                      context.l10n.accountDeleteWarning1,
                      isLight,
                    ),
                    const SizedBox(height: 20),
                    _buildWarningItem(
                      context.l10n.accountDeleteWarning2,
                      isLight,
                    ),
                    const SizedBox(height: 20),
                    _buildWarningItem(
                      context.l10n.accountDeleteWarning3,
                      isLight,
                    ),
                    const Spacer(),

                    // Agreement Switch
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.accountDeleteAgreement,
                            style: TextStyle(
                              fontFamily: 'Merriweather',
                              color: Colors.redAccent,
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

                    // Delete Button - now shows typed confirmation bottom sheet
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _agreed ? _showTypedConfirmationSheet : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _agreed
                              ? const Color(0xFFFF2E2E)
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
                                context.l10n.accountDeleteButton,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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

  Widget _buildWarningItem(String text, bool isLight) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Color(0xFFE91E63),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 12, color: Colors.white),
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
