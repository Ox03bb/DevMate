import 'package:flutter/material.dart';
import 'package:devmate/files/models/file_item.dart';

/// A list item widget for displaying a file or directory.
class FileListItem extends StatelessWidget {
  final FileItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const FileListItem({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  IconData _getIcon() {
    if (item.isDirectory) {
      return Icons.folder;
    }

    final ext = item.extension?.toLowerCase() ?? '';
    switch (ext) {
      // Images
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'svg':
        return Icons.image;

      // Videos
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'wmv':
      case 'flv':
        return Icons.video_file;

      // Audio
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
      case 'm4a':
        return Icons.audio_file;

      // Documents
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
      case 'md':
      case 'rtf':
        return Icons.article;

      // Code
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'kt':
      case 'swift':
      case 'c':
      case 'cpp':
      case 'h':
      case 'go':
      case 'rs':
      case 'rb':
      case 'php':
        return Icons.code;

      // Web
      case 'html':
      case 'css':
      case 'scss':
      case 'less':
        return Icons.web;

      // Config
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
      case 'toml':
      case 'ini':
      case 'conf':
        return Icons.settings;

      // Archives
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return Icons.folder_zip;

      // Executables
      case 'exe':
      case 'msi':
      case 'apk':
      case 'dmg':
      case 'deb':
      case 'rpm':
        return Icons.install_desktop;

      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor(BuildContext context) {
    if (item.isDirectory) {
      return Colors.amber.shade700;
    }

    final ext = item.extension?.toLowerCase() ?? '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'svg':
        return Colors.green;

      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Colors.red;

      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Colors.purple;

      case 'pdf':
        return Colors.red.shade700;

      case 'dart':
        return Colors.blue;

      case 'py':
        return Colors.yellow.shade700;

      case 'js':
      case 'ts':
        return Colors.orange;

      case 'zip':
      case 'rar':
      case '7z':
        return Colors.brown;

      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _getIconColor(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getIcon(), color: _getIconColor(context), size: 28),
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        item.isDirectory
            ? 'Folder'
            : '${item.formattedSize} • ${_formatDate(item.modifiedAt)}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          fontSize: 12,
        ),
      ),
      trailing: item.isDirectory
          ? const Icon(Icons.chevron_right)
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                // Handle menu action
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('Download'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
