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
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/current_user_provider.dart';
import 'cache_manager.dart';

final _cacheManagerSingleton = CacheManager();

/// Returns a ready-to-use CacheManager once the current therapist is
/// resolved and their box set is open. Returns null when there is no
/// authenticated user (callers should treat the cache as unavailable
/// and fall through to network).
///
/// OFFLINE fast path (tryb samolotowy, live-fix 2026-07-23): the boxes
/// are keyed by the backend users.id, which historically arrived only
/// from the NETWORK lookup in currentUserProvider — so a cold start in
/// airplane mode never opened the cache and the kartoteka list spun
/// forever. currentUserProvider now persists a firebase-uid →
/// backend-id mapping on every successful fetch; when that mapping is
/// present we open the boxes from it immediately, no network needed.
/// First-ever login on a device still blocks on the network (there is
/// no cache to serve anyway).
final cacheManagerProvider = FutureProvider<CacheManager?>((ref) async {
  final fbUser = await ref.watch(firebaseUserProvider.future);
  final mgr = _cacheManagerSingleton;

  if (fbUser == null) {
    await mgr.close();
    return null;
  }

  final prefs = await SharedPreferences.getInstance();
  final mappingKey = 'backend_user_id_${fbUser.uid}';
  final knownId = prefs.getString(mappingKey);

  if (knownId != null) {
    await mgr.openForUser(knownId);
    // Background reconciliation: if the account was deleted and
    // re-registered under the same firebase uid, the backend id
    // changes — refresh the mapping and reopen with the new boxes
    // once the network lookup lands.
    ref.listen(currentUserProvider, (prev, next) {
      final freshId = next.value?.id;
      if (freshId != null && freshId != knownId) {
        prefs.setString(mappingKey, freshId);
        ref.invalidateSelf();
      }
    });
    return mgr;
  }

  // No local mapping yet — first login here; the network lookup is
  // unavoidable (and also persists the mapping for next time).
  final user = await ref.watch(currentUserProvider.future);
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
