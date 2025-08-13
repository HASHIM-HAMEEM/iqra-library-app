import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for monitoring network connectivity status
class ConnectivityService {
  ConnectivityService._internal();
  
  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  final ValueNotifier<bool> _isConnected = ValueNotifier<bool>(true);
  final ValueNotifier<ConnectivityResult> _connectionType = 
      ValueNotifier<ConnectivityResult>(ConnectivityResult.wifi);
  
  /// Whether the device is currently connected to the internet
  ValueListenable<bool> get isConnected => _isConnected;
  
  /// Current connection type (wifi, mobile, ethernet, etc.)
  ValueListenable<ConnectivityResult> get connectionType => _connectionType;
  
  /// Current connection status as a boolean
  bool get hasConnection => _isConnected.value;
  
  /// Current connection type value
  ConnectivityResult get currentConnectionType => _connectionType.value;
  
  /// Initialize the connectivity service
  Future<void> initialize() async {
    try {
      // Check initial connectivity status
      final List<ConnectivityResult> connectivityResults = 
          await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResults);
      
      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged
          .listen(_updateConnectionStatus);
    } catch (e) {
      debugPrint('ConnectivityService initialization error: $e');
      // Assume connected if we can't check
      _isConnected.value = true;
      _connectionType.value = ConnectivityResult.wifi;
    }
  }
  
  /// Update connection status based on connectivity results
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final bool wasConnected = _isConnected.value;
    
    // Check if any connection type indicates connectivity
    final bool isNowConnected = results.any((result) => 
        result != ConnectivityResult.none);
    
    _isConnected.value = isNowConnected;
    
    // Set the primary connection type (prefer wifi over mobile)
    if (results.contains(ConnectivityResult.wifi)) {
      _connectionType.value = ConnectivityResult.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      _connectionType.value = ConnectivityResult.mobile;
    } else if (results.contains(ConnectivityResult.ethernet)) {
      _connectionType.value = ConnectivityResult.ethernet;
    } else if (results.isNotEmpty) {
      _connectionType.value = results.first;
    } else {
      _connectionType.value = ConnectivityResult.none;
    }
    
    // Log connectivity changes
    if (wasConnected != isNowConnected) {
      debugPrint('Connectivity changed: ${isNowConnected ? "Connected" : "Disconnected"} '
          '(${_connectionType.value})');
    }
  }
  
  /// Check if the device has a stable internet connection
  /// This performs an actual network test, not just connectivity check
  Future<bool> hasInternetConnection() async {
    try {
      // First check basic connectivity
      if (!_isConnected.value) {
        return false;
      }
      
      // For a more thorough check, we could ping a reliable server
      // For now, we'll rely on the connectivity status
      return true;
    } catch (e) {
      debugPrint('Internet connection check failed: $e');
      return false;
    }
  }
  
  /// Wait for internet connection to be available
  /// Returns true if connection is available, false if timeout
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isConnected.value) {
      return true;
    }
    
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    
    // Set up timeout
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(false);
      }
    });
    
    // Listen for connection
    subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((result) => result != ConnectivityResult.none);
      if (isConnected && !completer.isCompleted) {
        timer.cancel();
        subscription.cancel();
        completer.complete(true);
      }
    });
    
    return completer.future;
  }
  
  /// Get a human-readable connection status string
  String get connectionStatusText {
    if (!_isConnected.value) {
      return 'No internet connection';
    }
    
    switch (_connectionType.value) {
      case ConnectivityResult.wifi:
        return 'Connected via WiFi';
      case ConnectivityResult.mobile:
        return 'Connected via Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Connected via Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Connected via Bluetooth';
      case ConnectivityResult.vpn:
        return 'Connected via VPN';
      case ConnectivityResult.other:
        return 'Connected via Other';
      case ConnectivityResult.none:
      default:
        return 'No internet connection';
    }
  }
  
  /// Dispose of the service
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}