import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';
import 'package:devmate/docker/models/container.dart';

class DockerApiService {
  final String baseUrl;

  DockerApiService({this.baseUrl = 'http://$DOCKER_HOST:$DOCKER_PORT'});

  Future<List<ContainerModel>> fetchContainers({bool all = true}) async {
    final url = Uri.parse('$baseUrl/containers/json?all=$all');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print("===============================================");
      print(data);
      print("===============================================");

      return data.map((json) => ContainerModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load containers');
    }
  }
}
