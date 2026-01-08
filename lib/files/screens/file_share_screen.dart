import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:devmate/files/models/file_item.dart';
import 'package:devmate/files/services/file_service.dart';
import 'package:devmate/files/widgets/file_list_item.dart';
import 'package:devmate/files/widgets/file_grid_item.dart';
import 'package:devmate/files/widgets/path_breadcrumb.dart';
import 'package:devmate/shared/widgets/core.dart';

/// Main screen for file sharing functionality.
class FileShareScreen extends StatefulWidget {
  const FileShareScreen({super.key});

  @override
  State<FileShareScreen> createState() => _FileShareScreenState();
}

class _FileShareScreenState extends State<FileShareScreen> {
  final FileService _fileService = FileService();
  final TextEditingController _searchController = TextEditingController();

  List<FileItem> _files = [];
  List<FileItem> _filteredFiles = [];
  String _currentPath = '/';
  bool _isLoading = true;
  bool _isGridView = false;
  String? _error;
  Set<String> _selectedFiles = {};
  bool _isSelectionMode = false;
  SortOption _sortOption = SortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await _fileService.listDirectory(_currentPath);
      setState(() {
        _files = files;
        _filteredFiles = _sortFiles(files);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<FileItem> _sortFiles(List<FileItem> files) {
    final sorted = List<FileItem>.from(files);

    // First, separate directories and files
    final dirs = sorted.where((f) => f.isDirectory).toList();
    final regularFiles = sorted.where((f) => !f.isDirectory).toList();

    // Sort each group
    switch (_sortOption) {
      case SortOption.nameAsc:
        dirs.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        regularFiles.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case SortOption.nameDesc:
        dirs.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        regularFiles.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case SortOption.sizeAsc:
        dirs.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        regularFiles.sort((a, b) => a.size.compareTo(b.size));
        break;
      case SortOption.sizeDesc:
        dirs.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        regularFiles.sort((a, b) => b.size.compareTo(a.size));
        break;
      case SortOption.dateAsc:
        dirs.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
        regularFiles.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
        break;
      case SortOption.dateDesc:
        dirs.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        regularFiles.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
    }

    // Directories first, then files
    return [...dirs, ...regularFiles];
  }

  void _filterFiles(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredFiles = _sortFiles(_files);
      });
    } else {
      setState(() {
        _filteredFiles = _sortFiles(
          _files
              .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
              .toList(),
        );
      });
    }
  }

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path;
      _selectedFiles.clear();
      _isSelectionMode = false;
    });
    _loadFiles();
  }

  void _openItem(FileItem item) {
    if (item.isDirectory) {
      final newPath = _currentPath == '/'
          ? '/${item.name}'
          : '$_currentPath/${item.name}';
      _navigateTo(newPath);
    } else {
      _showFileOptions(item);
    }
  }

  void _toggleSelection(FileItem item) {
    setState(() {
      if (_selectedFiles.contains(item.path)) {
        _selectedFiles.remove(item.path);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(item.path);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedFiles = _filteredFiles.map((f) => f.path).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;

      for (final file in result.files) {
        if (file.path != null) {
          await _fileService.uploadFile(
            file.path!,
            '$_currentPath/${file.name}',
          );
        } else if (file.bytes != null) {
          await _fileService.uploadBytes(file.bytes!, file.name, _currentPath);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${result.files.length} file(s)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(FileItem item) async {
    try {
      final bytes = await _fileService.downloadFile(item.path);

      // Get downloads directory
      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        downloadDir = await getApplicationDocumentsDirectory();
      } else {
        downloadDir = await getDownloadsDirectory();
      }

      if (downloadDir == null) {
        throw Exception('Could not access downloads directory');
      }

      final file = File('${downloadDir.path}/${item.name}');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to ${file.path}'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => Share.shareXFiles([XFile(file.path)]),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteItems() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Items'),
        content: Text('Delete ${_selectedFiles.length} item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final path in _selectedFiles) {
        await _fileService.delete(path, recursive: true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${_selectedFiles.length} item(s)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _clearSelection();
      _loadFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'Enter folder name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final newPath = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
      await _fileService.createDirectory(newPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Folder created'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create folder: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFileOptions(FileItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                _downloadFile(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final bytes = await _fileService.downloadFile(item.path);
                  final tempDir = await getTemporaryDirectory();
                  final file = File('${tempDir.path}/${item.name}');
                  await file.writeAsBytes(bytes);
                  await Share.shareXFiles([XFile(file.path)]);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Share failed: $e'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.pop(context);
                final controller = TextEditingController(text: item.name);
                final newName = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Rename'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'New name'),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text),
                        child: const Text('Rename'),
                      ),
                    ],
                  ),
                );

                if (newName != null &&
                    newName.isNotEmpty &&
                    newName != item.name) {
                  try {
                    final parentPath = item.path.substring(
                      0,
                      item.path.lastIndexOf('/'),
                    );
                    final newPath = parentPath.isEmpty
                        ? '/$newName'
                        : '$parentPath/$newName';
                    await _fileService.rename(item.path, newPath);
                    _loadFiles();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Rename failed: $e'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Info'),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo(item);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete File'),
                    content: Text('Delete "${item.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    await _fileService.delete(item.path);
                    _loadFiles();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Delete failed: $e'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(FileItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Type', value: item.displayExtension),
            _InfoRow(label: 'Size', value: item.formattedSize),
            _InfoRow(
              label: 'Modified',
              value:
                  '${item.modifiedAt.day}/${item.modifiedAt.month}/${item.modifiedAt.year} ${item.modifiedAt.hour}:${item.modifiedAt.minute.toString().padLeft(2, '0')}',
            ),
            _InfoRow(label: 'Path', value: item.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sort by',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const Divider(),
            _SortOptionTile(
              title: 'Name (A-Z)',
              icon: Icons.sort_by_alpha,
              isSelected: _sortOption == SortOption.nameAsc,
              onTap: () {
                setState(() => _sortOption = SortOption.nameAsc);
                _filteredFiles = _sortFiles(_filteredFiles);
                Navigator.pop(context);
              },
            ),
            _SortOptionTile(
              title: 'Name (Z-A)',
              icon: Icons.sort_by_alpha,
              isSelected: _sortOption == SortOption.nameDesc,
              onTap: () {
                setState(() => _sortOption = SortOption.nameDesc);
                _filteredFiles = _sortFiles(_filteredFiles);
                Navigator.pop(context);
              },
            ),
            _SortOptionTile(
              title: 'Size (Smallest first)',
              icon: Icons.data_usage,
              isSelected: _sortOption == SortOption.sizeAsc,
              onTap: () {
                setState(() => _sortOption = SortOption.sizeAsc);
                _filteredFiles = _sortFiles(_filteredFiles);
                Navigator.pop(context);
              },
            ),
            _SortOptionTile(
              title: 'Size (Largest first)',
              icon: Icons.data_usage,
              isSelected: _sortOption == SortOption.sizeDesc,
              onTap: () {
                setState(() => _sortOption = SortOption.sizeDesc);
                _filteredFiles = _sortFiles(_filteredFiles);
                Navigator.pop(context);
              },
            ),
            _SortOptionTile(
              title: 'Date (Oldest first)',
              icon: Icons.calendar_today,
              isSelected: _sortOption == SortOption.dateAsc,
              onTap: () {
                setState(() => _sortOption = SortOption.dateAsc);
                _filteredFiles = _sortFiles(_filteredFiles);
                Navigator.pop(context);
              },
            ),
            _SortOptionTile(
              title: 'Date (Newest first)',
              icon: Icons.calendar_today,
              isSelected: _sortOption == SortOption.dateDesc,
              onTap: () {
                setState(() => _sortOption = SortOption.dateDesc);
                _filteredFiles = _sortFiles(_filteredFiles);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Core(
      title: 'File Sharing',
      onDeviceChanged: () {
        _fileService.refreshBaseUrl();
        _loadFiles();
      },
      actions: [
        if (_isSelectionMode) ...[
          IconButton(
            icon: const Icon(Icons.select_all),
            color: Theme.of(context).colorScheme.onPrimary,
            tooltip: 'Select All',
            onPressed: _selectAll,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: Theme.of(context).colorScheme.onPrimary,
            tooltip: 'Cancel Selection',
            onPressed: _clearSelection,
          ),
        ] else ...[
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            color: Theme.of(context).colorScheme.onPrimary,
            tooltip: _isGridView ? 'List View' : 'Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            color: Theme.of(context).colorScheme.onPrimary,
            tooltip: 'Sort',
            onPressed: _showSortOptions,
          ),
        ],
      ],
      body: Column(
        children: [
          // Path breadcrumb
          PathBreadcrumb(currentPath: _currentPath, onPathTap: _navigateTo),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterFiles('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _filterFiles,
            ),
          ),

          const SizedBox(height: 8),

          // Selection bar
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Text(
                    '${_selectedFiles.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteItems,
                  ),
                ],
              ),
            ),

          // File list
          Expanded(child: _buildFileList()),
        ],
      ),
      bottomNavigationBar: _isSelectionMode
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploadFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _createFolder,
                      icon: const Icon(Icons.create_new_folder),
                      label: const Text('New Folder'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFileList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load files',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No files match your search'
                  : 'This folder is empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Upload files or create a new folder',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_isGridView) {
      return RefreshIndicator(
        onRefresh: _loadFiles,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _filteredFiles.length,
          itemBuilder: (context, index) {
            final item = _filteredFiles[index];
            return FileGridItem(
              item: item,
              isSelected: _selectedFiles.contains(item.path),
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(item);
                } else {
                  _openItem(item);
                }
              },
              onLongPress: () => _toggleSelection(item),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _filteredFiles.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _filteredFiles[index];
          return FileListItem(
            item: item,
            isSelected: _selectedFiles.contains(item.path),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item);
              } else {
                _openItem(item);
              }
            },
            onLongPress: () => _toggleSelection(item),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOptionTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: onTap,
    );
  }
}

enum SortOption { nameAsc, nameDesc, sizeAsc, sizeDesc, dateAsc, dateDesc }
