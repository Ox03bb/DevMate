import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';
import 'package:devmate/docker/models/container.dart';
import 'package:devmate/docker/models/images.dart';
import 'package:devmate/docker/models/volumes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DockerApiService {
  final String baseUrl;
  final String imagesCacheKey = "images_cache";
  final String containerCacheKey = "container_cache";
  final String volumesCacheKey = "volumes_cache";

  Future<List<VolumeModel>> fetchVolumes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = Uri.parse('$baseUrl/volumes');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        prefs.setString(volumesCacheKey, response.body);
        final List<dynamic> volumes = data['Volumes'] ?? [];
        return volumes.map((json) => VolumeModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load volumes');
      }
    } catch (e) {
      if (e is http.ClientException ||
          e.toString().contains('SocketException')) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(volumesCacheKey);
        if (cached != null) {
          final Map<String, dynamic> data = json.decode(cached);
          final List<dynamic> volumes = data['Volumes'] ?? [];
          return volumes.map((json) => VolumeModel.fromJson(json)).toList();
        }
        throw Exception(
          'Failed to fetch volumes from network, and no valid cache available',
        );
      }
      rethrow;
    }
  }

  DockerApiService({this.baseUrl = 'http://$DOCKER_HOST:$DOCKER_PORT'});

  Future<List<ImageModel>> fetchImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final url = Uri.parse('$baseUrl/images/json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        prefs.setString(imagesCacheKey, response.body);

        return data.map((json) => ImageModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load images');
      }
    } catch (e) {
      if (e is http.ClientException ||
          e.toString().contains('SocketException')) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(imagesCacheKey);

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
        prefs.setString(containerCacheKey, response.body);

        return data.map((json) => ContainerModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load containers');
      }
    } catch (e) {
      if (e is http.ClientException ||
          e.toString().contains('SocketException')) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(containerCacheKey);

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
