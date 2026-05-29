// Cross-origin SSO handler — stub for non-web platforms.
//
// On iOS / Android the app is launched from the user's home-screen,
// not from a URL handoff, so there's no token to redeem. The web
// build swaps this stub for sso_handler_web.dart via conditional
// import (see main.dart).

Future<void> applySsoFromUrl() async {
  // no-op on mobile
}
