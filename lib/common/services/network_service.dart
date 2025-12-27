import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      // Try to reach a reliable server
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if error is network related
  static bool isNetworkError(dynamic error) {
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (error is FormatException) return true;

    final errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('host lookup') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable');
  }

  /// Get user-friendly error message for network issues
  static String getNetworkErrorMessage(dynamic error) {
    if (isNetworkError(error)) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Stream of connectivity changes
  static Stream<List<ConnectivityResult>> get connectivityStream {
    return Connectivity().onConnectivityChanged;
  }
}