import 'package:shared_preferences/shared_preferences.dart';

/// Service for saving and loading SSH connection settings.
class SSHSettingsService {
  static const String _keyHost = 'ssh_host';
  static const String _keyPort = 'ssh_port';
  static const String _keyUsername = 'ssh_username';

  /// Save SSH connection settings.
  Future<void> saveSettings({
    required String host,
    required int port,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, host);
    await prefs.setInt(_keyPort, port);
    await prefs.setString(_keyUsername, username);
  }

  /// Load saved SSH connection settings.
  Future<Map<String, dynamic>?> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_keyHost);
    final port = prefs.getInt(_keyPort);
    final username = prefs.getString(_keyUsername);

    if (host != null && port != null && username != null) {
      return {'host': host, 'port': port, 'username': username};
    }
    return null;
  }

  /// Clear saved settings.
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHost);
    await prefs.remove(_keyPort);
    await prefs.remove(_keyUsername);
  }
}
