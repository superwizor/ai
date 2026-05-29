// Upload error classification — conditional import.
//
// On mobile (dart:io available): classifies SocketException,
// HttpException, HandshakeException as retryable network errors.
//
// On Web (no dart:io): classifies http.ClientException and
// TimeoutException as retryable (dart:io types don't exist on Web).

export 'upload_error_web.dart' if (dart.library.io) 'upload_error_io.dart';
