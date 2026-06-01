import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

enum ConnectivityStatus { isConnected, isDisconnected, isConnecting }

class ConnectivityProvider with ChangeNotifier {
  ConnectivityStatus _status = ConnectivityStatus.isConnecting;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;

  ConnectivityStatus get status => _status;

  ConnectivityProvider() {
    _init();
    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
  }

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (e) {
      _status = ConnectivityStatus.isDisconnected;
      notifyListeners();
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      _status = ConnectivityStatus.isDisconnected;
    } else {
      _status = ConnectivityStatus.isConnected;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
