import 'package:flutter/material.dart';
import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';

/// EUPHIRE Standard Scaffold
///
/// Enforces the 'Royal Evergreen' background gradient and consistent safety areas.
class EuScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  final bool extendBodyBehindAppBar;
  final bool safeArea;
  final bool resizeToAvoidBottomInset;

  const EuScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.appBar,
    this.extendBodyBehindAppBar = false,
    this.safeArea = true,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = body;
    if (safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark ? EuDesignTokens.gradientBackground : null,
                color: isDark ? null : EuDesignTokens.frostWhite,
              ),
            ),
          ),
          // Content
          Positioned.fill(child: content),
        ],
      ),
    );
  }
}
