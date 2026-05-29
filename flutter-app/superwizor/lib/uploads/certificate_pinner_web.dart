// F-09: Certificate pinning — Web stub.
//
// On Web, the browser manages TLS entirely. There is no API to
// pin certificates or override the trust store from JavaScript.
// The browser's built-in certificate validation provides equivalent
// security for non-jailbroken scenarios.
//
// This stub returns a plain http.Client.

import 'package:http/http.dart' as http;

/// On Web, returns a standard [http.Client]. Certificate pinning
/// is handled by the browser's TLS implementation.
http.Client createPinnedHttpClient() => http.Client();
