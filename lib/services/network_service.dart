import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  /// Checks if the device has active internet connection
  static Future<bool> get hasConnection async {
    final ConnectivityResult connectivityResult =
        await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  static Stream<ConnectivityResult> get onConnectivityChanged {
    return Connectivity().onConnectivityChanged;
  }
}
