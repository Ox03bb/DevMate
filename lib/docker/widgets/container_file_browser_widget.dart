import 'package:flutter/material.dart';
import 'package:devmate/docker/services/file_browser_service.dart';

class ContainerFileBrowserWidget extends StatefulWidget {
  final String containerId;

  const ContainerFileBrowserWidget({super.key, required this.containerId});

  @override
  State<ContainerFileBrowserWidget> createState() =>
      _ContainerFileBrowserWidgetState();
}

class _ContainerFileBrowserWidgetState extends State<ContainerFileBrowserWidget>
    with AutomaticKeepAliveClientMixin {
  final FileBrowserService _browserService = FileBrowserService();
  String _currentPath = '/';
  List<FileInfo> _files = [];
  bool _isLoading = false;
  String? _error;
  final List<String> _pathHistory = ['/'];
  int _historyIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await _browserService.listDirectory(
        widget.containerId,
        path,
      );
      setState(() {
        _files = files;
        _currentPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToDirectory(String dirName) {
    String newPath;
    if (dirName == '..') {
      // Go up one directory
      final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) {
        newPath = '/';
      } else {
        parts.removeLast();
        newPath = '/${parts.join('/')}';
      }
    } else {
      // Go into subdirectory
      newPath = _currentPath == '/' ? '/$dirName' : '$_currentPath/$dirName';
    }

    // Add to history
    if (_historyIndex < _pathHistory.length - 1) {
      _pathHistory.removeRange(_historyIndex + 1, _pathHistory.length);
    }
    _pathHistory.add(newPath);
    _historyIndex = _pathHistory.length - 1;

    _loadDirectory(newPath);
  }

  void _goBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _loadDirectory(_pathHistory[_historyIndex]);
    }
  }

  void _goForward() {
    if (_historyIndex < _pathHistory.length - 1) {
      _historyIndex++;
      _loadDirectory(_pathHistory[_historyIndex]);
    }
  }

  void _showFileContent(FileInfo file) async {
    final filePath = _currentPath == '/'
        ? '/${file.name}'
        : '$_currentPath/${file.name}';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insert_drive_file,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<String>(
                  future: _browserService.readFile(
                    widget.containerId,
                    filePath,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text('Error: ${snapshot.error}'),
                          ],
                        ),
                      );
                    } else {
                      return Container(
                        color: Colors.black,
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            snapshot.data ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Navigation bar
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _historyIndex > 0 ? _goBack : null,
                tooltip: 'Back',
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _historyIndex < _pathHistory.length - 1
                    ? _goForward
                    : null,
                tooltip: 'Forward',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadDirectory(_currentPath),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPath,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // File list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _loadDirectory(_currentPath),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _files.isEmpty
              ? const Center(child: Text('Empty directory'))
              : ListView.builder(
                  itemCount: _files.length + (_currentPath != '/' ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Add parent directory option
                    if (_currentPath != '/' && index == 0) {
                      return ListTile(
                        leading: const Icon(Icons.folder, color: Colors.blue),
                        title: const Text('..'),
                        subtitle: const Text('Parent directory'),
                        onTap: () => _navigateToDirectory('..'),
                      );
                    }

                    final fileIndex = _currentPath != '/' ? index - 1 : index;
                    final file = _files[fileIndex];

                    return ListTile(
                      leading: Icon(
                        file.isDirectory
                            ? Icons.folder
                            : Icons.insert_drive_file,
                        color: file.isDirectory ? Colors.blue : Colors.grey,
                      ),
                      title: Text(file.name),
                      subtitle: Text(
                        file.isDirectory
                            ? file.permissions
                            : '${file.size} • ${file.permissions}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: file.isDirectory
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: () {
                        if (file.isDirectory) {
                          _navigateToDirectory(file.name);
                        } else {
                          _showFileContent(file);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
