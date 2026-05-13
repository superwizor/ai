import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';
import 'package:labirynt_premium/src/models/deck.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:labirynt_premium/src/core/ui/eu_components.dart';

// Widget imports
import 'package:labirynt_premium/src/features/settings/widgets/settings_header.dart';
import 'package:labirynt_premium/src/features/settings/widgets/account_section.dart';
import 'package:labirynt_premium/src/features/settings/widgets/premium_section.dart';
import 'package:labirynt_premium/src/features/settings/widgets/preferences_section.dart';
import 'package:labirynt_premium/src/features/settings/widgets/notifications_section.dart';
import 'package:labirynt_premium/src/features/settings/widgets/duo_mode_section.dart';
import 'package:labirynt_premium/src/features/settings/widgets/categories_section.dart';
import 'package:labirynt_premium/src/features/settings/widgets/support_section.dart';
import 'package:labirynt_premium/src/features/settings/widgets/marketing_section.dart';
import 'package:labirynt_premium/src/features/settings/widgets/legal_section.dart';
import 'package:labirynt_premium/src/features/settings/widgets/account_management_section.dart';

import 'package:labirynt_premium/src/features/duo/data/party_session_repository.dart';
import 'package:labirynt_premium/src/core/extensions/l10n_extension.dart';

/// Settings screen with modular section widgets
///
/// Refactored from 1444 LOC to ~100 LOC composition.
/// All logic moved to individual section widgets.
/// Guest users see a simplified version (sounds, haptics, support, social, account).
class SettingsScreen extends ConsumerStatefulWidget {
  /// If provided, shows only categories for this specific deck
  final DeckId? targetedDeckId;

  /// If true, category sections will be expanded by default
  final bool initExpanded;

  /// Optional party session data to show players at the top
  final List<String>? partyParticipants;
  final Map<String, dynamic>? partyNames;
  final Map<String, dynamic>? partyPhotos;
  final String? partyJoinCode;
  final String? partySessionId;

  const SettingsScreen({
    super.key,
    this.targetedDeckId,
    this.initExpanded = false,
    this.partyParticipants,
    this.partyNames,
    this.partyPhotos,
    this.partyJoinCode,
    this.partySessionId,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      debugPrint("Could not load app version: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? EuDesignTokens.nocturne
          : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (Logo + Title + Close button)
            const SettingsHeader(),

            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  EuDesignTokens.space24,
                  EuDesignTokens.space8,
                  EuDesignTokens.space24,
                  110, // Bottom padding for safe area
                ),
                children: [
                  // ── Party Players Header (if provided) ──
                  if (widget.partyParticipants != null &&
                      widget.partyParticipants!.isNotEmpty) ...[
                    _PartyPlayersHeader(
                      participants: widget.partyParticipants!,
                      names: widget.partyNames ?? {},
                      photos: widget.partyPhotos ?? {},
                      joinCode: widget.partyJoinCode,
                      sessionId: widget.partySessionId,
                    ),
                    const SizedBox(height: EuDesignTokens.space24),
                  ],

                  // ── Guest-only: Premium first ──
                  if (!isGuest) ...[
                    // 1. Premium status card
                    const PremiumSection(),
                    const SizedBox(height: EuDesignTokens.space32),
                  ],

                  // 2. Account / Profile
                  const AccountSection(),
                  const SizedBox(height: EuDesignTokens.space32),

                  // 3. Visual and game preferences (guests see sounds & haptics)
                  const PreferencesSection(),
                  const SizedBox(height: EuDesignTokens.space32),

                  if (!isGuest) ...[
                    // 4. Notifications
                    const NotificationsSection(),
                    const SizedBox(height: EuDesignTokens.space32),

                    // 5. Duo Mode (paired partners)
                    const DuoModeSection(),
                    const SizedBox(height: EuDesignTokens.space32),

                    // 6. Categories and topics
                    CategoriesSection(
                      targetedDeckId: widget.targetedDeckId,
                      initExpanded: widget.initExpanded,
                    ),
                    const SizedBox(height: EuDesignTokens.space32),
                  ],

                  // 7. Help and support
                  const SupportSection(),
                  const SizedBox(height: EuDesignTokens.space32),

                  // 8. Legal Information
                  const LegalSection(),
                  const SizedBox(height: EuDesignTokens.space32),

                  // 9. Marketing and social
                  const MarketingSection(),
                  const SizedBox(height: EuDesignTokens.space32),

                  if (!isGuest) ...[
                    // 10. Account Management (Reset, Delete & Logout)
                    const AccountManagementSection(),
                    const SizedBox(height: EuDesignTokens.space16),
                  ],

                  // App Version Footer
                  if (_appVersion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: EuDesignTokens.space16,
                      ),
                      child: Center(
                        child: Text(
                          context.l10n.settingsAppVersion(_appVersion),
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: EuDesignTokens.space32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal list of party players shown at the top of settings
class _PartyPlayersHeader extends StatelessWidget {
  final List<String> participants;
  final Map<String, dynamic> names;
  final Map<String, dynamic> photos;
  final String? joinCode;
  final String? sessionId;

  const _PartyPlayersHeader({
    required this.participants,
    required this.names,
    required this.photos,
    this.joinCode,
    this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                context.l10n.settingsPlayersInSession,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (joinCode != null)
              Consumer(
                builder: (context, ref, _) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.settingsJoinCode(joinCode!),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: EuDesignTokens.ember,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.5,
                                fontFamily: 'RobotoMono',
                              ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: () async {
                            if (sessionId != null) {
                              try {
                                await ref
                                    .read(partySessionRepositoryProvider)
                                    .refreshJoinCode(sessionId: sessionId!);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.l10n.settingsCodeRefreshed,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.l10n.settingsCodeRefreshFailed,
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          color: EuDesignTokens.ember,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: context.l10n.settingsRefreshTooltip,
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: participants.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final uid = participants[index];
              final name =
                  names[uid]?.toString() ?? context.l10n.settingsGuestPlayer;
              final photoUrl = photos[uid]?.toString() ?? '';

              return Column(
                children: [
                  if (photoUrl.isNotEmpty)
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(photoUrl),
                      onBackgroundImageError: (_, _) {},
                    )
                  else
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: EuDesignTokens.ember,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
