import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';

/// Represents a Docker socket configuration
class DockerSocket {
  final String path;
  final bool available;
  final bool active;

  DockerSocket({
    required this.path,
    required this.available,
    required this.active,
  });

  factory DockerSocket.fromJson(Map<String, dynamic> json) {
    return DockerSocket(
      path: json['path'] as String,
      available: json['available'] as bool,
      active: json['active'] as bool,
    );
  }

  /// Returns a friendly name for the socket path
  String get displayName {
    if (path.contains('.docker/desktop')) {
      return 'Docker Desktop';
    } else if (path == '/var/run/docker.sock') {
      return 'System Docker';
    }
    return path.split('/').last;
  }
}

/// Service for managing Docker socket configuration on the backend
class DockerSocketService {
  String? _baseUrl;

  DockerSocketService({String? baseUrl}) : _baseUrl = baseUrl;

  /// Gets the base URL for the proxy server.
  Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    final host = await appConfig.getHost();
    final port = await appConfig.getPort();
    _baseUrl = 'http://$host:$port';
    return _baseUrl!;
  }

  /// Refreshes the base URL from config.
  void refreshBaseUrl() {
    _baseUrl = null;
  }

  /// Gets the list of available Docker sockets
  Future<List<DockerSocket>> getDockerSockets() async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/docker-sockets');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> socketsJson = data['sockets'] ?? [];
        return socketsJson.map((json) => DockerSocket.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get Docker sockets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get Docker sockets: $e');
    }
  }

  /// Gets the current active Docker socket path
  Future<String?> getCurrentSocket() async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/docker-sockets');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['currentSocket'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Selects a Docker socket to use
  Future<bool> selectSocket(String path) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/docker-sockets/select');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'path': path}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Failed to select socket');
      }
    } catch (e) {
      throw Exception('Failed to select Docker socket: $e');
    }
  }

  /// Gets proxy health status
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/health');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 503) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get health status');
    } catch (e) {
      return {
        'status': 'error',
        'services': {'docker': false, 'fileServer': false},
      };
    }
  }
}
