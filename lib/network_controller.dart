import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NetworkController extends GetxController {
  final Connectivity _connectivity = Connectivity();

  final _connectionStatus = ConnectivityResult.none.obs;
  final _isConnected = false.obs;

  ConnectivityResult get connectionStatus => _connectionStatus.value;
  bool get isConnected => _isConnected.value;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    _initializeNetworkListener();
    _checkInitialConnectivity();
  }

  void _initializeNetworkListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        // Take the first result from the list
        final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
        _updateConnectionStatus(result);
      },
    );
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _updateConnectionStatus(result);
    } catch (e) {
      print('Failed to check connectivity: $e');
      _updateConnectionStatus(ConnectivityResult.none);
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) async {
    _connectionStatus.value = result;

    if (result == ConnectivityResult.none) {
      _isConnected.value = false;
    } else {
      // Additional check with actual internet connectivity
      _isConnected.value = await _hasInternetConnection();
    }

    _showConnectionStatus();
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _showConnectionStatus() {
    if (!_isConnected.value) {
      Get.rawSnackbar(
        messageText: const Text(
          'No Internet Connection',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        isDismissible: false,
        duration: const Duration(days: 1),
        backgroundColor: Colors.red[400]!,
        icon: const Icon(Icons.wifi_off, color: Colors.white, size: 35),
        margin: EdgeInsets.zero,
        snackStyle: SnackStyle.GROUNDED,
      );
    } else {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
      Get.rawSnackbar(
        messageText: const Text(
          'Back Online',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        isDismissible: true,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green[400]!,
        icon: const Icon(Icons.wifi, color: Colors.white, size: 35),
        margin: EdgeInsets.zero,
        snackStyle: SnackStyle.GROUNDED,
      );
    }
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }
}
