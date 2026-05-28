package ai.superwizor.superwizor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom

class MainActivity : FlutterActivity() {

    private val CHANNEL = "ai.superwizor/secure_random"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // F-06: Hardware RNG MethodChannel.
        // Android's SecureRandom uses the Linux kernel CSPRNG which is
        // seeded by hardware entropy sources (HWRNG, jitter entropy).
        // This is equivalent to iOS's SecRandomCopyBytes for our
        // threat model.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "getRandomBytes") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val length = call.argument<Int>("length")
                if (length == null || length < 1 || length > 256) {
                    result.error("INVALID_ARGUMENT", "length must be 1..256", null)
                    return@setMethodCallHandler
                }

                try {
                    val bytes = ByteArray(length)
                    SecureRandom().nextBytes(bytes)
                    result.success(bytes)
                } catch (e: Exception) {
                    result.error("RNG_FAILED", e.message, null)
                }
            }
    }
}
