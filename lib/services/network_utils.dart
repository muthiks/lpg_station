import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Returns true if device has an active internet connection
Future<bool> isOnline() async {
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) return false;

  try {
    final result = await InternetAddress.lookup(
      'google.com',
    ).timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
