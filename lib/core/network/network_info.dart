import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;
  NetworkInfoImpl(this.connectivity);

  @override
  Future<bool> get isConnected async {
    final raw = await connectivity.checkConnectivity();
    // connectivity_plus >=5 can return List<ConnectivityResult>
    final List<ConnectivityResult> results = raw is List<ConnectivityResult>
        ? raw
        : [raw as ConnectivityResult];
    final connected = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );
    print('[NetworkInfo] Raw connectivity: $raw -> connected=$connected');
    return connected;
  }
}
