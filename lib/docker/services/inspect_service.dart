import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:devmate/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DockerInspectService {
  final String baseUrl;

  DockerInspectService({this.baseUrl = 'http://$DOCKER_HOST:$DOCKER_PORT'});

  Future<Map<String, dynamic>> inspectContainer(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (id.isEmpty) {
        throw Exception('Container ID cannot be empty');
      }

      if (prefs.getString(id) != null) {
        // Use compute to parse JSON off the main thread
        return await compute(_parseJson, prefs.getString(id)!);
      }

      final url = Uri.parse('$baseUrl/containers/$id/json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Use compute to parse JSON off the main thread
        final decoded = await compute(_parseJson, response.body);

        await prefs.setString(id, json.encode(decoded));
        return decoded;
      } else {
        throw Exception('Failed to inspect container');
      }
    } catch (e) {
      if (e is http.ClientException ||
          e.toString().contains('SocketException')) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(id) != null) {
          // Use compute to parse JSON off the main thread
          return await compute(_parseJson, prefs.getString(id)!);
        }
        throw Exception(
          'Failed to fetch container inspection from network, and no valid cache available',
        );
      }
      rethrow;
    }
  }

  // Top-level function for compute()
  Map<String, dynamic> _parseJson(String jsonStr) {
    return json.decode(jsonStr) as Map<String, dynamic>;
  }
}
