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
    return Connectivity().onConnectivityChanged.map((dynamic event) {
      if (event is List<ConnectivityResult>) return event;
      if (event is ConnectivityResult) return [event];
      return <ConnectivityResult>[];
    });
  }
}
