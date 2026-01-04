import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';

/// Service for managing Docker container lifecycle operations.
class ContainerService {
  String? _baseUrl;

  ContainerService({String? baseUrl}) : _baseUrl = baseUrl;

  /// Gets the base URL, loading from config if not provided.
  Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    _baseUrl = await appConfig.getDockerBaseUrl();
    return _baseUrl!;
  }

  /// Refreshes the base URL from config.
  Future<void> refreshBaseUrl() async {
    appConfig.invalidateCache();
    _baseUrl = await appConfig.getDockerBaseUrl();
  }

  /// Starts a stopped container.
  Future<void> startContainer(String containerId) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/containers/$containerId/start');
      final response = await http.post(url);

      if (response.statusCode != 204 && response.statusCode != 304) {
        throw Exception('Failed to start container: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to start container: $e');
    }
  }

  /// Stops a running container.
  Future<void> stopContainer(String containerId) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/containers/$containerId/stop');
      final response = await http.post(url);

      if (response.statusCode != 204 && response.statusCode != 304) {
        throw Exception('Failed to stop container: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to stop container: $e');
    }
  }

  /// Restarts a container.
  Future<void> restartContainer(String containerId) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/containers/$containerId/restart');
      final response = await http.post(url);

      if (response.statusCode != 204) {
        throw Exception('Failed to restart container: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to restart container: $e');
    }
  }

  /// Pauses a running container.
  Future<void> pauseContainer(String containerId) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/containers/$containerId/pause');
      final response = await http.post(url);

      if (response.statusCode != 204) {
        throw Exception('Failed to pause container: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to pause container: $e');
    }
  }

  /// Unpauses a paused container.
  Future<void> unpauseContainer(String containerId) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/containers/$containerId/unpause');
      final response = await http.post(url);

      if (response.statusCode != 204) {
        throw Exception('Failed to unpause container: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to unpause container: $e');
    }
  }

  /// Removes a container.
  Future<void> removeContainer(String containerId, {bool force = false}) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/containers/$containerId?force=$force');
      final response = await http.delete(url);

      if (response.statusCode != 204) {
        throw Exception('Failed to remove container: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to remove container: $e');
    }
  }
}
