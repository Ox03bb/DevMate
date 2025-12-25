import 'dart:convert';
import 'package:devmate/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DockerInspectService {
  final String baseUrl;

  DockerInspectService({this.baseUrl = 'http://$DOCKER_HOST:$DOCKER_PORT'});

  Future<Map<String, dynamic>> inspectContainer(String id) async {
    final prefs = await SharedPreferences.getInstance();

    if (id.isEmpty) {
      throw Exception('Container ID cannot be empty');
    }

    if (prefs.getString(id) != null) {
      return json.decode(prefs.getString(id)!);
    }

    final url = Uri.parse('$baseUrl/containers/$id/json');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      await prefs.setString(id, json.encode(decoded));
      return decoded;
    } else {
      throw Exception('Failed to inspect container');
    }
  }
}
