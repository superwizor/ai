// Deep linki do zarządzania subskrypcją w sklepie (docs/70 §2.3).
//
// To JEDYNE wyjścia z aplikacji, jakie wolno pokazać przy trybie
// `web_link_mode == NONE`: prowadzą do ustawień subskrypcji tego samego
// sklepu, w którym zakup zrobiono. Zarządzanie własnym IAP jest dozwolone —
// zakazane jest kierowanie do innego mechanizmu zakupu (Apple 3.1.1).
//
// Nie ma tu i nie może się pojawić żadnego adresu superwizor.ai.

const String kAndroidPackageName = 'ai.superwizor.superwizor';

const String _kAppleSubscriptions =
    'https://apps.apple.com/account/subscriptions';

const String _kPlaySubscriptions =
    'https://play.google.com/store/account/subscriptions';

/// Adres ustawień subskrypcji dla [platform] ('IOS' | 'ANDROID').
///
/// Na Androidzie warto podać [productId] — Play otwiera wtedy konkretną
/// subskrypcję zamiast listy wszystkich.
String? storeSubscriptionsUrl(String platform, {String? productId}) {
  switch (platform) {
    case 'IOS':
      return _kAppleSubscriptions;
    case 'ANDROID':
      if (productId != null && productId.isNotEmpty) {
        return '$_kPlaySubscriptions?sku=$productId'
            '&package=$kAndroidPackageName';
      }
      return '$_kPlaySubscriptions?package=$kAndroidPackageName';
    default:
      return null;
  }
}
