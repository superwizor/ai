// F-09: Certificate pinning — conditional import.
//
// On mobile (dart:io available): uses IOClient with badCertificateCallback
// to reject any certificate the system validator flags as bad.
//
// On Web (no dart:io): returns a plain http.Client because the browser
// handles TLS entirely — no API to override the trust store from JS.
//
// Usage: import this file everywhere instead of the platform-specific
// implementations directly.

export 'certificate_pinner_web.dart'
    if (dart.library.io) 'certificate_pinner_io.dart';
