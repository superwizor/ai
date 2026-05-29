// Cross-origin SSO handler — web-only implementation.
//
// Reads the URL fragment for an `auth_token` (minted by
// identity-svc.MintAppLoginToken on the marketing origin), signs the
// user in via Firebase Auth's signInWithCustomToken, then strips the
// fragment so the token doesn't linger in browser history or get
// accidentally shared via the URL bar / referrer.
//
// Why the fragment (not query string): the hash is never sent to
// Firebase Hosting (no server logs), isn't included in the Referer
// header on outbound links, and is parsed locally before Flutter's
// router sees it. Defence-in-depth for a short-lived (~1h) custom
// token that's already single-use in practice.
//
// On failure (expired token / network blip / replay attempt) we
// silently fall through to the LoginScreen — the user can still log
// in with email+password. The fragment is stripped either way so
// reloading the page doesn't repeat the failed exchange.

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

Future<void> applySsoFromUrl() async {
  final hash = html.window.location.hash;
  if (hash.isEmpty) return;

  // Strip the leading '#' before parsing as a query-string-shaped
  // map. Supports both `#auth_token=...&email=...` and
  // `#/auth_token=...` (the latter shouldn't happen but is harmless).
  final cleaned = hash.startsWith('#') ? hash.substring(1) : hash;
  final Map<String, String> params;
  try {
    params = Uri.splitQueryString(cleaned);
  } catch (_) {
    return; // malformed fragment — leave it alone
  }
  final token = params['auth_token'];
  if (token == null || token.isEmpty) return;

  try {
    await FirebaseAuth.instance.signInWithCustomToken(token);
  } catch (e) {
    debugPrint('SSO custom-token sign-in failed: $e');
    // fall through — LoginScreen will render
  }

  // Strip the fragment regardless of outcome. Token is now spent
  // (Firebase rejects reuse) and clutter in the URL bar is bad UX.
  final loc = html.window.location;
  final cleanUrl = '${loc.pathname}${loc.search}';
  html.window.history.replaceState(null, '', cleanUrl);
}
