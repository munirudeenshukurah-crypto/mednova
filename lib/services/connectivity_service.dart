import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._privateConstructor();

  static final ConnectivityService instance =
  ConnectivityService._privateConstructor();

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>?
  _subscription;

  final StreamController<bool> _connectionController =
  StreamController<bool>.broadcast();

  Stream<bool> get connectionStream =>
      _connectionController.stream;

  bool _isOnline = false;

  bool get isOnline => _isOnline;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<bool> initialize() async {
    final result = await _connectivity.checkConnectivity();

    _isOnline = _hasConnection(result);

    _listenForChanges();

    return _isOnline;
  }

  // ============================================================
  // LISTEN FOR CONNECTION CHANGES
  // ============================================================

  void _listenForChanges() {
    _subscription?.cancel();

    _subscription =
        _connectivity.onConnectivityChanged.listen(
              (results) {
            final online = _hasConnection(results);

            if (_isOnline != online) {
              _isOnline = online;

              _connectionController.add(
                _isOnline,
              );
            }
          },
        );
  }

  // ============================================================
  // CHECK CONNECTION
  // ============================================================

  bool _hasConnection(
      List<ConnectivityResult> results,
      ) {
    return results.contains(
      ConnectivityResult.wifi,
    ) ||
        results.contains(
          ConnectivityResult.mobile,
        ) ||
        results.contains(
          ConnectivityResult.ethernet,
        ) ||
        results.contains(
          ConnectivityResult.vpn,
        );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await _subscription?.cancel();

    await _connectionController.close();
  }
}