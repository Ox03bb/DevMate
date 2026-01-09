import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';
import 'package:devmate/files/models/file_item.dart';

/// Service for interacting with the file sharing API.
class FileService {
  String? _baseUrl;

  FileService({String? baseUrl}) : _baseUrl = baseUrl;

  /// Gets the base URL for the file server (through proxy).
  Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    _baseUrl = await appConfig.getFileServerBaseUrl();
    return _baseUrl!;
  }

  /// Refreshes the base URL from config.
  Future<void> refreshBaseUrl() async {
    appConfig.invalidateCache();
    _baseUrl = null;
  }

  /// Lists files and directories at the given path.
  Future<List<FileItem>> listDirectory(String path) async {
    try {
      final base = await baseUrl;
      final encodedPath = Uri.encodeComponent(path);
      final url = Uri.parse('$base/api/files/list?path=$encodedPath');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> files = data['files'] ?? [];
        return files.map((json) => FileItem.fromJson(json)).toList();
      } else {
        throw Exception('Failed to list directory: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to list directory: $e');
    }
  }

  /// Downloads a file from the remote server.
  Future<Uint8List> downloadFile(String remotePath) async {
    try {
      final base = await baseUrl;
      final encodedPath = Uri.encodeComponent(remotePath);
      final url = Uri.parse('$base/api/files/download?path=$encodedPath');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }

  /// Downloads a file and saves it to the local path.
  Future<void> downloadFileToPath(String remotePath, String localPath) async {
    final bytes = await downloadFile(remotePath);
    final file = File(localPath);
    await file.writeAsBytes(bytes);
  }

  /// Uploads a file to the remote server.
  /// [fileName] can be provided to override the filename (useful when the local path contains cache directories).
  Future<bool> uploadFile(
    String localPath,
    String remotePath, {
    String? fileName,
  }) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/api/files/upload');

      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Local file does not exist');
      }

      final request = http.MultipartRequest('POST', url);
      request.fields['path'] = remotePath;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          localPath,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Uploads bytes directly to the remote server.
  Future<bool> uploadBytes(
    Uint8List bytes,
    String fileName,
    String remotePath,
  ) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/api/files/upload');

      final request = http.MultipartRequest('POST', url);
      request.fields['path'] = remotePath;
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Creates a new directory.
  Future<bool> createDirectory(String path) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/api/files/mkdir');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'path': path}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to create directory: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create directory: $e');
    }
  }

  /// Deletes a file or directory.
  Future<bool> delete(String path, {bool recursive = false}) async {
    try {
      final base = await baseUrl;
      final encodedPath = Uri.encodeComponent(path);
      final url = Uri.parse(
        '$base/api/files/delete?path=$encodedPath&recursive=$recursive',
      );
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete: $e');
    }
  }

  /// Renames a file or directory.
  Future<bool> rename(String oldPath, String newPath) async {
    try {
      final base = await baseUrl;
      final url = Uri.parse('$base/api/files/rename');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'oldPath': oldPath, 'newPath': newPath}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to rename: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to rename: $e');
    }
  }

  /// Gets file/directory info.
  Future<FileItem?> getInfo(String path) async {
    try {
      final base = await baseUrl;
      final encodedPath = Uri.encodeComponent(path);
      final url = Uri.parse('$base/api/files/info?path=$encodedPath');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return FileItem.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Searches for files matching the query.
  Future<List<FileItem>> search(String query, {String? basePath}) async {
    try {
      final base = await baseUrl;
      final encodedQuery = Uri.encodeComponent(query);
      final encodedBasePath = basePath != null
          ? Uri.encodeComponent(basePath)
          : '';
      final url = Uri.parse(
        '$base/api/files/search?query=$encodedQuery&basePath=$encodedBasePath',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> files = data['files'] ?? [];
        return files.map((json) => FileItem.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search: $e');
    }
  }
}
