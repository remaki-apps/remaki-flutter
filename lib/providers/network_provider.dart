import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/env_config.dart';

class NetworkProvider with ChangeNotifier {
  static NetworkProvider? _instance;
  static NetworkProvider get instance => _instance ??= NetworkProvider._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOffline = false;
  bool _isChecking = false;
  VoidCallback? onRestored;
  final List<VoidCallback> _onRestoredListeners = [];
  bool get isOffline => _isOffline;
  bool get isChecking => _isChecking;

  void addRestoredListener(VoidCallback listener) {
    if (!_onRestoredListeners.contains(listener)) {
      _onRestoredListeners.add(listener);
    }
  }

  void removeRestoredListener(VoidCallback listener) {
    _onRestoredListeners.remove(listener);
  }

  NetworkProvider._internal() {
    _init();
  }

  void _init() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final bool hasNoInterface = results.isEmpty ||
          (results.length == 1 && results.first == ConnectivityResult.none);

      if (hasNoInterface) {
        setOffline(true);
      } else {
        // Network interface became active, verify actual internet connection
        checkConnection();
      }
    });
  }

  void setOffline(bool offline) {
    if (_isOffline == offline) return;
    _isOffline = offline;
    notifyListeners();

    if (!offline) {
      try {
        onRestored?.call();
      } catch (e) {
        debugPrint('[NetworkProvider] onRestored error: $e');
      }

      for (final listener in List<VoidCallback>.from(_onRestoredListeners)) {
        try {
          listener();
        } catch (e) {
          debugPrint('[NetworkProvider] restored listener error: $e');
        }
      }
    }
  }

  Future<bool> checkConnection() async {
    if (_isChecking) return !_isOffline;
    _isChecking = true;
    notifyListeners();

    bool online = false;
    try {
      final results = await _connectivity.checkConnectivity();
      final bool hasNoInterface = results.isEmpty ||
          (results.length == 1 && results.first == ConnectivityResult.none);

      if (!hasNoInterface) {
        online = await _probe();
      }
    } catch (_) {
      online = false;
    } finally {
      _isChecking = false;
      setOffline(!online);
      notifyListeners();
    }

    return online;
  }

  Future<bool> _probe() async {
    final targets = <Uri>[
      Uri.parse('https://www.google.com/generate_204'),
      Uri.parse('https://1.1.1.1'),
      Uri.parse(EnvConfig.warmupUrl),
    ];

    try {
      final futures = targets.map((target) async {
        try {
          final response = await http
              .get(target)
              .timeout(const Duration(milliseconds: 2500));
          return response.statusCode > 0;
        } catch (_) {
          return false;
        }
      });

      final results = await Future.wait(futures);
      return results.any((success) => success);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _onRestoredListeners.clear();
    super.dispose();
  }
}
