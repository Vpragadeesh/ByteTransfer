import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:byte_transfer/models/models.dart';
import 'network_service.dart';

/// Implementation of NetworkService using network_info_plus
class NetworkServiceImpl implements NetworkService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final Connectivity _connectivity = Connectivity();

  /// Get device's local IP address on LAN
  @override
  Future<String?> getLocalIPAddress() async {
    try {
      // Get the list of all network interfaces
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Filter for IPv4 addresses on local networks
          if (addr.type == InternetAddressType.IPv4 &&
              isLocalNetworkAddress(addr.address)) {
            return addr.address;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get current WiFi SSID
  @override
  Future<String?> getWiFiSSID() async {
    try {
      return await _networkInfo.getWifiName();
    } catch (e) {
      return null;
    }
  }

  /// Check if connected to WiFi
  @override
  Future<bool> isConnectedToWiFi() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity() as dynamic;
      
      // Handle List<ConnectivityResult>
      if (connectivityResults is List) {
        for (final result in connectivityResults) {
          if (result == ConnectivityResult.wifi) {
            return true;
          }
        }
        return false;
      } else {
        // Handle single ConnectivityResult
        return connectivityResults == ConnectivityResult.wifi;
      }
    } catch (e) {
      return false;
    }
  }

  /// Stream of network connectivity changes
  @override
  Stream<NetworkStatus> get networkStatusStream async* {
    await for (final connectivityResult in _connectivity.onConnectivityChanged) {
      NetworkType type = NetworkType.none;
      bool isConnected = false;

      // Cast to list and iterate through results
      final results = connectivityResult is List ? (connectivityResult as List).cast() : [connectivityResult];
      
      for (final result in results) {
        if (result == ConnectivityResult.wifi) {
          type = NetworkType.wifi;
          isConnected = true;
          break;
        } else if (result == ConnectivityResult.mobile) {
          type = NetworkType.mobile;
          isConnected = true;
          break;
        } else if (result == ConnectivityResult.ethernet) {
          type = NetworkType.ethernet;
          isConnected = true;
          break;
        }
      }

      final ipAddress = type == NetworkType.wifi || type == NetworkType.ethernet 
          ? await getLocalIPAddress() 
          : null;
      final ssid = type == NetworkType.wifi ? await getWiFiSSID() : null;

      yield NetworkStatus(
        isConnected: isConnected,
        ipAddress: ipAddress,
        ssid: ssid,
        type: type,
      );
    }
  }

  /// Validate IP address is on local network (private ranges)
  @override
  bool isLocalNetworkAddress(String ip) {
    // Localhost
    if (isLocalhost(ip)) {
      return true;
    }

    // Parse IP address
    try {
      final parts = ip.split('.');
      if (parts.length != 4) {
        return false;
      }

      final octets = parts.map((p) => int.parse(p)).toList();

      // 192.168.x.x
      if (octets[0] == 192 && octets[1] == 168) {
        return true;
      }

      // 10.x.x.x
      if (octets[0] == 10) {
        return true;
      }

      // 172.16.x.x to 172.31.x.x
      if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) {
        return true;
      }

      // 169.254.x.x (link-local)
      if (octets[0] == 169 && octets[1] == 254) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if address is localhost
  @override
  bool isLocalhost(String ip) {
    return ip == '127.0.0.1' || ip == '::1' || ip == 'localhost';
  }
}

