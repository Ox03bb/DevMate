/// Represents a file or directory in the file system.
class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedAt;
  final String? extension;
  final String? mimeType;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedAt,
    this.extension,
    this.mimeType,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      isDirectory: json['isDirectory'] as bool? ?? false,
      size: json['size'] as int? ?? 0,
      modifiedAt:
          DateTime.tryParse(json['modifiedAt'] as String? ?? '') ??
          DateTime.now(),
      extension: json['extension'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'isDirectory': isDirectory,
      'size': size,
      'modifiedAt': modifiedAt.toIso8601String(),
      'extension': extension,
      'mimeType': mimeType,
    };
  }

  /// Returns a human-readable file size string.
  String get formattedSize {
    if (isDirectory) return '-';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Returns the file extension or 'folder' for directories.
  String get displayExtension {
    if (isDirectory) return 'Folder';
    return extension?.toUpperCase() ?? 'FILE';
  }
}

/// Represents a file transfer operation.
class FileTransfer {
  final String id;
  final String fileName;
  final String localPath;
  final String remotePath;
  final TransferType type;
  final TransferStatus status;
  final int totalBytes;
  final int transferredBytes;
  final DateTime startedAt;
  final String? error;

  FileTransfer({
    required this.id,
    required this.fileName,
    required this.localPath,
    required this.remotePath,
    required this.type,
    required this.status,
    required this.totalBytes,
    required this.transferredBytes,
    required this.startedAt,
    this.error,
  });

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;

  FileTransfer copyWith({
    TransferStatus? status,
    int? transferredBytes,
    String? error,
  }) {
    return FileTransfer(
      id: id,
      fileName: fileName,
      localPath: localPath,
      remotePath: remotePath,
      type: type,
      status: status ?? this.status,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      startedAt: startedAt,
      error: error ?? this.error,
    );
  }
}

enum TransferType { upload, download }

enum TransferStatus { pending, inProgress, completed, failed, cancelled }
