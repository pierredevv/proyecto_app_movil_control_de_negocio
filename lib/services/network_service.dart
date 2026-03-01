import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  /// Checks if the device has active internet connection
  static Future<bool> get hasConnection async {
    final dynamic result = await Connectivity().checkConnectivity();
    if (result is List<ConnectivityResult>) {
      return result.any((r) => r != ConnectivityResult.none);
    } else if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    // Handle List<dynamic> case which might happen at runtime
    if (result is List) {
      return result.any((r) => r.toString() != 'ConnectivityResult.none');
    }
    return false;
  }

  static Stream<List<ConnectivityResult>> get onConnectivityChanged {
    // If the package returns a single ConnectivityResult, we wrap it in a list to match the new type signature
    return Connectivity().onConnectivityChanged.map((event) => [event]);
  }
}
