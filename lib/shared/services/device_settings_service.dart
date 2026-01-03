import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:devmate/shared/models/discovered_device.dart';

/// Service for persisting device settings in local storage.
class DeviceSettingsService {
  static const String _hostKey = 'device_host';
  static const String _portKey = 'device_port';
  static const String _deviceNameKey = 'device_name';
  static const String _selectedDeviceKey = 'selected_device';

  /// Saves the selected device settings to local storage.
  Future<void> saveDevice(DiscoveredDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, device.host);
    await prefs.setInt(_portKey, device.port);
    await prefs.setString(_deviceNameKey, device.name);
    await prefs.setString(_selectedDeviceKey, jsonEncode(device.toJson()));
  }

  /// Saves host and port manually (for manual configuration).
  Future<void> saveHostAndPort(String host, int port, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
    await prefs.setInt(_portKey, port);
    if (name != null) {
      await prefs.setString(_deviceNameKey, name);
    }
  }

  /// Retrieves the saved host from local storage.
  /// Returns null if no host has been saved.
  Future<String?> getHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hostKey);
  }

  /// Retrieves the saved port from local storage.
  /// Returns null if no port has been saved.
  Future<int?> getPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_portKey);
  }

  /// Retrieves the saved device name from local storage.
  Future<String?> getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceNameKey);
  }

  /// Retrieves the full saved device from local storage.
  /// Returns null if no device has been saved.
  Future<DiscoveredDevice?> getSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceJson = prefs.getString(_selectedDeviceKey);
    if (deviceJson != null) {
      try {
        return DiscoveredDevice.fromJson(jsonDecode(deviceJson));
      } catch (e) {
        // If parsing fails, try to construct from individual fields
        final host = prefs.getString(_hostKey);
        final port = prefs.getInt(_portKey);
        final name = prefs.getString(_deviceNameKey);
        if (host != null && port != null) {
          return DiscoveredDevice(
            name: name ?? 'Saved Device',
            host: host,
            port: port,
          );
        }
      }
    }
    return null;
  }

  /// Checks if a device has been configured.
  Future<bool> hasDeviceConfigured() async {
    final host = await getHost();
    final port = await getPort();
    return host != null && port != null;
  }

  /// Clears all saved device settings.
  Future<void> clearDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostKey);
    await prefs.remove(_portKey);
    await prefs.remove(_deviceNameKey);
    await prefs.remove(_selectedDeviceKey);
  }
}
