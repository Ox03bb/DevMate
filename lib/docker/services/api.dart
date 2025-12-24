import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';
import 'package:devmate/docker/models/container.dart';
import 'package:devmate/docker/models/images.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DockerApiService {
  final String baseUrl;
  final String containercacheKey = "container_cache";
  final String imagescacheKey = "images_cache";

  DockerApiService({this.baseUrl = 'http://$DOCKER_HOST:$DOCKER_PORT'});

  Future<List<ImageModel>> fetchImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final url = Uri.parse('$baseUrl/images/json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        prefs.setString(imagescacheKey, response.body);

        return data.map((json) => ImageModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load images');
      }
    } catch (e) {
      if (e is http.ClientException ||
          e.toString().contains('SocketException')) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(imagescacheKey);
        if (cached != null) {
          final data = json.decode(cached);
          if (data is List) {
            return data.map((json) => ImageModel.fromJson(json)).toList();
          }
        }
        throw Exception(
          'Failed to fetch containers from network, and no valid cache available',
        );
      }
      rethrow;
    }
  }

  Future<List<ContainerModel>> fetchContainers({bool all = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = Uri.parse('$baseUrl/containers/json?all=$all');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        prefs.setString(containercacheKey, response.body);

        return data.map((json) => ContainerModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load containers');
      }
    } catch (e) {
      if (e is http.ClientException ||
          e.toString().contains('SocketException')) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(containercacheKey);
        if (cached != null) {
          final data = json.decode(cached);
          if (data is List) {
            return data.map((json) => ContainerModel.fromJson(json)).toList();
          }
        }
        throw Exception(
          'Failed to fetch containers from network, and no valid cache available',
        );
      }
      rethrow;
    }
  }
}
