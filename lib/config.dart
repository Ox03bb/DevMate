import 'package:devmate/shared/services/device_settings_service.dart';

/// Default host when no device has been configured.
const String DEFAULT_HOST = '192.168.72.122';

/// Default Docker API port.
const int DEFAULT_DOCKER_PORT = 2375;

/// Default mDNS service type for Docker daemon discovery.
const String DEVMATE_MDNS_SERVICE_TYPE = '_devmate._tcp';

/// Manages application configuration including device settings.
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  final DeviceSettingsService _settingsService = DeviceSettingsService();

  String? _cachedHost;
  int? _cachedPort;

  /// Gets the configured host, falling back to default if not set.
  Future<String> getHost() async {
    if (_cachedHost != null) return _cachedHost!;
    _cachedHost = await _settingsService.getHost() ?? DEFAULT_HOST;
    return _cachedHost!;
  }

  /// Gets the configured port, falling back to default if not set.
  Future<int> getPort() async {
    if (_cachedPort != null) return _cachedPort!;
    _cachedPort = await _settingsService.getPort() ?? DEFAULT_DOCKER_PORT;
    return _cachedPort!;
  }

  /// Gets the full base URL for the Docker API.
  Future<String> getDockerBaseUrl() async {
    final host = await getHost();
    final port = await getPort();
    return 'http://$host:$port';
  }

  /// Updates the cached configuration (call after selecting a new device).
  void invalidateCache() {
    _cachedHost = null;
    _cachedPort = null;
  }

  /// Checks if a device has been configured.
  Future<bool> hasDeviceConfigured() async {
    return await _settingsService.hasDeviceConfigured();
  }
}

/// Global app configuration instance.
final appConfig = AppConfig();
