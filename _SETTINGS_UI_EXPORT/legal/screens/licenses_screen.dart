import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:labirynt_premium/src/core/ui/eu_components.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EuDesignTokens.nocturne,
      appBar: AppBar(
        title: Text(
          context.l10n.settingsLicensesTitle,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: EuDesignTokens.nocturne,
        elevation: 0,
      ),
      body: FutureBuilder<List<LicenseEntry>>(
        future: LicenseRegistry.licenses.toList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: EuDesignTokens.ember),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                context.l10n.settingsLicensesTitle, // Fallback for error.
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
              ),
            );
          }

          final licenses = snapshot.data ?? [];
          final packages = <String, List<LicenseEntry>>{};

          for (final license in licenses) {
            for (final package in license.packages) {
              packages.putIfAbsent(package, () => []).add(license);
            }
          }

          final packageNames = packages.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(EuDesignTokens.space16),
            itemCount: packageNames.length,
            itemBuilder: (context, index) {
              final package = packageNames[index];
              final packageLicenses = packages[package]!;

              return Padding(
                padding: const EdgeInsets.only(bottom: EuDesignTokens.space12),
                child: EuSection(
                  contentPadding: EdgeInsets.zero,
                  children: [
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        listTileTheme: const ListTileThemeData(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: EuDesignTokens.space16,
                          vertical: EuDesignTokens.space4,
                        ),
                        title: Text(
                          package,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${packageLicenses.length} license(s)',
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        iconColor: EuDesignTokens.ember,
                        collapsedIconColor: Colors.white60,
                        children: [
                          for (final license in packageLicenses)
                            Container(
                              padding: const EdgeInsets.all(
                                EuDesignTokens.space16,
                              ),
                              color: EuDesignTokens.glassDark,
                              width: double.infinity,
                              child: Text(
                                license.paragraphs
                                    .map((p) => p.text)
                                    .join('\n\n'),
                                style: TextStyle(
                                  fontFamily: 'RobotoMono',
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
