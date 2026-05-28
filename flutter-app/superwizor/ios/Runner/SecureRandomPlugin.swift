import Foundation
import Security

/// F-06 — Hardware RNG MethodChannel plugin.
///
/// Provides cryptographically secure random bytes via the OS hardware
/// random number generator:
///   - iOS/macOS: `SecRandomCopyBytes` (Common Crypto / Secure Enclave)
///
/// Dart's `Random.secure()` typically delegates to /dev/urandom which is
/// a CSPRNG seeded by hardware entropy. On most modern devices this is
/// fine, but SecRandomCopyBytes is guaranteed to use the Secure Enclave
/// hardware RNG directly, making it the gold standard for IV generation
/// in clinical-grade encryption.
///
/// Channel: `ai.superwizor/secure_random`
/// Method:  `getRandomBytes` → takes `length` (Int), returns `FlutterStandardTypedData`
class SecureRandomPlugin {

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "ai.superwizor/secure_random",
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { (call, result) in
            guard call.method == "getRandomBytes" else {
                result(FlutterMethodNotImplemented)
                return
            }

            guard let args = call.arguments as? [String: Any],
                  let length = args["length"] as? Int,
                  length > 0, length <= 256 else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "length must be 1..256",
                    details: nil
                ))
                return
            }

            var bytes = [UInt8](repeating: 0, count: length)
            let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)

            if status == errSecSuccess {
                result(FlutterStandardTypedData(bytes: Data(bytes)))
            } else {
                result(FlutterError(
                    code: "RNG_FAILED",
                    message: "SecRandomCopyBytes returned \(status)",
                    details: nil
                ))
            }
        }
    }
}
