import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'patient_provider.dart';
import 'current_user_provider.dart';

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged.map((results) => results.first);
});

void setupConnectivityListener(ProviderContainer container) {
  ConnectivityResult? previousResult;
  container.listen(
    connectivityProvider,
    (previous, next) {
      if (next is AsyncData) {
        final currentResult = next.value!;
        if (previousResult == ConnectivityResult.none && currentResult != ConnectivityResult.none) {
          // Internet restored -> trigger refresh
          container.invalidate(patientsProvider);
          container.invalidate(currentUserProvider);
        }
        previousResult = currentResult;
      }
    },
  );
}
