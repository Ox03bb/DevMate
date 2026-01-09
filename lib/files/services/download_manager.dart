import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Manages downloaded files in a dedicated DevMate folder.
class DownloadManager {
  static const String _folderName = 'DevMate';
  static DownloadManager? _instance;

  DownloadManager._();

  static DownloadManager get instance {
    _instance ??= DownloadManager._();
    return _instance!;
  }

  /// Gets the DevMate downloads directory, creating it if needed.
  Future<Directory> getDownloadDirectory() async {
    Directory? baseDir;

    if (Platform.isAndroid) {
      // Use external storage Downloads folder on Android
      baseDir = Directory('/storage/emulated/0/Download');
      if (!await baseDir.exists()) {
        baseDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      baseDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isLinux || Platform.isMacOS) {
      baseDir = await getDownloadsDirectory();
    } else if (Platform.isWindows) {
      baseDir = await getDownloadsDirectory();
    }

    if (baseDir == null) {
      throw Exception('Could not access downloads directory');
    }

    // Create DevMate subfolder
    final devmateDir = Directory('${baseDir.path}/$_folderName');
    if (!await devmateDir.exists()) {
      await devmateDir.create(recursive: true);
    }

    return devmateDir;
  }

  /// Saves bytes to a file in the DevMate folder.
  /// Returns the saved file.
  Future<File> saveFile(String fileName, List<int> bytes) async {
    final dir = await getDownloadDirectory();
    final file = File('${dir.path}/$fileName');

    // Handle duplicate file names
    final savedFile = await _getUniqueFile(file);
    await savedFile.writeAsBytes(bytes);

    return savedFile;
  }

  /// Gets a unique file path if file already exists.
  Future<File> _getUniqueFile(File file) async {
    if (!await file.exists()) {
      return file;
    }

    final dir = file.parent.path;
    final name = file.uri.pathSegments.last;
    final dotIndex = name.lastIndexOf('.');
    final baseName = dotIndex != -1 ? name.substring(0, dotIndex) : name;
    final extension = dotIndex != -1 ? name.substring(dotIndex) : '';

    int counter = 1;
    File newFile;
    do {
      newFile = File('$dir/$baseName ($counter)$extension');
      counter++;
    } while (await newFile.exists());

    return newFile;
  }

  /// Gets all downloaded files in the DevMate folder.
  Future<List<DownloadedFile>> getDownloadedFiles() async {
    try {
      final dir = await getDownloadDirectory();
      final entities = await dir.list().toList();

      final files = <DownloadedFile>[];
      for (final entity in entities) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add(
            DownloadedFile(
              name: entity.uri.pathSegments.last,
              path: entity.path,
              size: stat.size,
              downloadedAt: stat.modified,
            ),
          );
        }
      }

      // Sort by download date, newest first
      files.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
      return files;
    } catch (e) {
      return [];
    }
  }

  /// Deletes a downloaded file.
  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Deletes all downloaded files.
  Future<int> clearAllDownloads() async {
    try {
      final dir = await getDownloadDirectory();
      final entities = await dir.list().toList();
      int count = 0;

      for (final entity in entities) {
        if (entity is File) {
          await entity.delete();
          count++;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Gets total size of downloaded files.
  Future<int> getTotalDownloadSize() async {
    try {
      final files = await getDownloadedFiles();
      return files.fold<int>(0, (sum, file) => sum + file.size);
    } catch (e) {
      return 0;
    }
  }
}

/// Represents a downloaded file.
class DownloadedFile {
  final String name;
  final String path;
  final int size;
  final DateTime downloadedAt;

  DownloadedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.downloadedAt,
  });

  String get extension {
    final dotIndex = name.lastIndexOf('.');
    return dotIndex != -1 ? name.substring(dotIndex + 1).toLowerCase() : '';
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
