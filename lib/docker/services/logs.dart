import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';
import 'package:devmate/docker/models/container.dart';
import 'package:devmate/docker/models/images.dart';
import 'package:devmate/docker/models/volumes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogsApiService {
  LogsApiService({this.baseUrl = 'http://$DOCKER_HOST:$DOCKER_PORT'});

  Stream<String> streamContainerLogs(String id) async* {
    try {
      final url = Uri.parse(
        '$baseUrl/containers/$id/logs?stdout=true&stderr=true&timestamps=true&follow=true',
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

  final String baseUrl;
}
