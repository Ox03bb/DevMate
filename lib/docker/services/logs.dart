import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';

class LogsApiService {
  String? _baseUrl;

  LogsApiService({String? baseUrl}) : _baseUrl = baseUrl;

  /// Gets the base URL, loading from config if not provided.
  Future<String> getBaseUrl() async {
    if (_baseUrl != null) return _baseUrl!;
    _baseUrl = await appConfig.getDockerBaseUrl();
    return _baseUrl!;
  }

  /// Refreshes the base URL from config.
  Future<void> refreshBaseUrl() async {
    appConfig.invalidateCache();
    _baseUrl = await appConfig.getDockerBaseUrl();
  }

  Stream<String> streamContainerLogs(String id) async* {
    try {
      final base = await getBaseUrl();
      final url = Uri.parse(
        '$base/containers/$id/logs?stdout=true&stderr=true&timestamps=true&follow=true',
      );
      final request = http.Request('GET', url)
        ..headers['Content-Type'] = 'application/vnd.docker.raw-stream';
      final client = http.Client();
      final response = await client.send(request);
      if (response.statusCode == 200) {
        // Docker multiplexed stream: [1 byte stream type][3 bytes 0][4 bytes length][payload]
        final stream = response.stream;
        await for (final chunk in stream) {
          int offset = 0;
          while (offset + 8 <= chunk.length) {
            // 8-byte header
            final int payloadLen =
                (chunk[offset + 4] << 24) |
                (chunk[offset + 5] << 16) |
                (chunk[offset + 6] << 8) |
                (chunk[offset + 7]);
            if (offset + 8 + payloadLen > chunk.length) {
              break;
            }
            final payload = chunk.sublist(offset + 8, offset + 8 + payloadLen);
            yield utf8.decode(payload);
            offset += 8 + payloadLen;
          }
        }
      }
    } catch (e) {
      if (e is http.ClientException ||
          e.toString().contains('SocketException')) {
        throw Exception('Failed to fetch container logs from network');
      }
      rethrow;
    }
  }
}
