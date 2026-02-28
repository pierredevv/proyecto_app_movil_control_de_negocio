import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  /// Checks if the device has active internet connection
  static Future<bool> get hasConnection async {
    final ConnectivityResult connectivityResult =
        await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  static Stream<List<ConnectivityResult>> get onConnectivityChanged {
    // If the package returns a single ConnectivityResult, we wrap it in a list to match the new type signature
    return Connectivity().onConnectivityChanged.map((event) => [event]);
  }
}
