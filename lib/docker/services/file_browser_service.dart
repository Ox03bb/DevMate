import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:devmate/config.dart';

class FileInfo {
  final String name;
  final bool isDirectory;
  final String permissions;
  final String size;
  final String modified;

  FileInfo({
    required this.name,
    required this.isDirectory,
    required this.permissions,
    required this.size,
    required this.modified,
  });

  factory FileInfo.fromLsOutput(String line) {
    // Parse ls -lAh output
    // Example: drwxr-xr-x 2 root root 4.0K Jan  1 12:00 dirname
    final parts = line.trim().split(RegExp(r'\s+'));

    if (parts.length < 9) {
      return FileInfo(
        name: line,
        isDirectory: false,
        permissions: '',
        size: '',
        modified: '',
      );
    }

    final permissions = parts[0];
    final isDirectory = permissions.startsWith('d');
    final size = parts[4];
    final modified = '${parts[5]} ${parts[6]} ${parts[7]}';
    final name = parts.sublist(8).join(' ');

    return FileInfo(
      name: name,
      isDirectory: isDirectory,
      permissions: permissions,
      size: size,
      modified: modified,
    );
  }
}

/// Service for browsing files inside Docker containers.
class FileBrowserService {
  String? _baseUrl;

  FileBrowserService({String? baseUrl}) : _baseUrl = baseUrl;

  /// Gets the base URL, loading from config if not provided.
  Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    _baseUrl = await appConfig.getDockerBaseUrl();
    return _baseUrl!;
  }

  /// Lists files in a directory inside a container.
  Future<List<FileInfo>> listDirectory(String containerId, String path) async {
    try {
      final base = await baseUrl;

      // Create exec instance
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
              'Cmd': [
                '/bin/sh',
                '-c',
                'ls -lAh "$path" 2>/dev/null || echo "ERROR"',
              ],
            }),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (createResponse.statusCode != 201) {
        throw Exception('Failed to create exec instance');
      }

      final execId = json.decode(createResponse.body)['Id'] as String;

      // Start exec instance
      final startUrl = Uri.parse('$base/exec/$execId/start');
      final startResponse = await http
          .post(
            startUrl,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'Detach': false, 'Tty': false}),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Execution timeout'),
          );

      if (startResponse.statusCode == 200) {
        final output = _parseDockerStream(startResponse.bodyBytes);

        if (output.trim() == 'ERROR' || output.isEmpty) {
          throw Exception('Failed to read directory');
        }

        return _parseFileList(output);
      } else {
        throw Exception('Failed to list directory');
      }
    } catch (e) {
      throw Exception('Failed to list directory: $e');
    }
  }

  /// Reads file content from a container.
  Future<String> readFile(String containerId, String filePath) async {
    try {
      final base = await baseUrl;

      // Create exec instance
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
              'Cmd': ['/bin/sh', '-c', 'cat "$filePath"'],
            }),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (createResponse.statusCode != 201) {
        throw Exception('Failed to create exec instance');
      }

      final execId = json.decode(createResponse.body)['Id'] as String;

      // Start exec instance
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
        return _parseDockerStream(startResponse.bodyBytes);
      } else {
        throw Exception('Failed to read file');
      }
    } catch (e) {
      throw Exception('Failed to read file: $e');
    }
  }

  List<FileInfo> _parseFileList(String output) {
    final lines = output.split('\n');
    final files = <FileInfo>[];

    for (var line in lines) {
      if (line.trim().isEmpty || line.startsWith('total ')) continue;

      try {
        final fileInfo = FileInfo.fromLsOutput(line);
        // Skip . and ..
        if (fileInfo.name != '.' && fileInfo.name != '..') {
          files.add(fileInfo);
        }
      } catch (e) {
        // Skip malformed lines
        continue;
      }
    }

    // Sort: directories first, then alphabetically
    files.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return files;
  }

  String _parseDockerStream(List<int> data) {
    final output = StringBuffer();
    int offset = 0;

    while (offset + 8 <= data.length) {
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

    if (output.isEmpty && data.isNotEmpty) {
      try {
        return utf8.decode(data);
      } catch (e) {
        return '';
      }
    }

    return output.toString();
  }
}
