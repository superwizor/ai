// Riverpod gateway to the CacheManager singleton.
//
// Why a singleton, not a fresh CacheManager per provider rebuild:
// Hive boxes are process-wide handles — opening the same box twice
// without closing in between throws. The singleton hands out the one
// CacheManager that owns lifecycle (open/close/clear) and the
// provider just slings it through Riverpod for testability + ref
// scoping.
//
// Lifecycle binding:
//   • currentUserProvider resolves to non-null  → openForUser(uid)
//   • currentUserProvider resolves to null     → close()
//   • therapist switch (uid_a → uid_b)         → close → open
//
// Hard logout (clear keychain + delete box files) is handled by the
// signOut action site, not here — see auth flow.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/current_user_provider.dart';
import 'cache_manager.dart';

final _cacheManagerSingleton = CacheManager();

/// Returns a ready-to-use CacheManager once the current therapist is
/// resolved and their box set is open. Returns null when there is no
/// authenticated user (callers should treat the cache as unavailable
/// and fall through to network).
final cacheManagerProvider = FutureProvider<CacheManager?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  final mgr = _cacheManagerSingleton;

  if (user == null) {
    await mgr.close();
    return null;
  }

  await mgr.openForUser(user.id);
  return mgr;
});

/// Direct handle for code paths that need to invoke clearForUser()
/// at sign-out time (auth flow) without going through the async
/// FutureProvider. Avoid using this from repositories — they should
/// always take a CacheManager parameter so they remain testable.
CacheManager cacheManagerInstance() => _cacheManagerSingleton;
