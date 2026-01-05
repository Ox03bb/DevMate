import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';

/// Service for executing commands inside Docker containers.
class ContainerExecService {
  String? _baseUrl;

  ContainerExecService({String? baseUrl}) : _baseUrl = baseUrl;

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

  /// Executes a command inside a container and returns the output.
  Future<String> execCommand(String containerId, String command) async {
    try {
      final base = await baseUrl;

      // Step 1: Create an exec instance
      final createUrl = Uri.parse('$base/containers/$containerId/exec');
      final createResponse = await http
          .post(
            createUrl,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'AttachStdout': true,
              'AttachStderr': true,
              'Tty': false,
              'Env': ['TERM=xterm'],
              'Cmd': ['/bin/sh', '-c', command],
            }),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (createResponse.statusCode != 201) {
        throw Exception(
          'Failed to create exec instance: ${createResponse.statusCode}',
        );
      }

      final execId = json.decode(createResponse.body)['Id'] as String;

      // Step 2: Start the exec instance
      final startUrl = Uri.parse('$base/exec/$execId/start');
      final startResponse = await http
          .post(
            startUrl,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'Detach': false, 'Tty': false}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Execution timeout'),
          );

      if (startResponse.statusCode == 200) {
        // Parse the Docker multiplexed stream
        return _parseDockerStream(startResponse.bodyBytes);
      } else {
        throw Exception(
          'Failed to execute command: ${startResponse.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to execute command: $e');
    }
  }

  /// Parses Docker's multiplexed stream format.
  String _parseDockerStream(List<int> data) {
    final output = StringBuffer();
    int offset = 0;

    while (offset + 8 <= data.length) {
      // Docker multiplexed stream: [1 byte stream type][3 bytes 0][4 bytes length][payload]
      final streamType = data[offset];
      final payloadLen =
          (data[offset + 4] << 24) |
          (data[offset + 5] << 16) |
          (data[offset + 6] << 8) |
          (data[offset + 7]);

      if (offset + 8 + payloadLen > data.length) {
        break;
      }

      final payload = data.sublist(offset + 8, offset + 8 + payloadLen);
      output.write(utf8.decode(payload));
      offset += 8 + payloadLen;
    }

    // If no multiplexed data found, try decoding the whole response
    if (output.isEmpty && data.isNotEmpty) {
      try {
        return utf8.decode(data);
      } catch (e) {
        return 'Error decoding output';
      }
    }

    return output.toString();
  }
}
