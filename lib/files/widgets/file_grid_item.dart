import 'package:flutter/material.dart';
import 'package:devmate/files/models/file_item.dart';

/// A grid item widget for displaying a file or directory.
class FileGridItem extends StatelessWidget {
  final FileItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const FileGridItem({
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
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'svg':
        return Icons.image;

      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file;

      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;

      case 'pdf':
        return Icons.picture_as_pdf;

      case 'doc':
      case 'docx':
        return Icons.description;

      case 'xls':
      case 'xlsx':
        return Icons.table_chart;

      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'go':
        return Icons.code;

      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
        return Icons.folder_zip;

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
        return Colors.green;

      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.red;

      case 'mp3':
      case 'wav':
      case 'flac':
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

      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _getIconColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getIcon(), color: _getIconColor(context), size: 36),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                item.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (!item.isDirectory)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.formattedSize,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
