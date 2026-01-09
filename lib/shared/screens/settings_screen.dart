import 'package:flutter/material.dart';
import 'package:devmate/shared/widgets/core.dart';
import 'package:devmate/shared/services/device_settings_service.dart';
import 'package:devmate/shared/services/docker_socket_service.dart';
import 'package:devmate/files/services/download_manager.dart';
import 'package:devmate/files/screens/downloads_screen.dart';
import 'package:devmate/config.dart';

/// Settings screen for configuring app preferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DeviceSettingsService _deviceService = DeviceSettingsService();
  final DockerSocketService _dockerSocketService = DockerSocketService();
  final DownloadManager _downloadManager = DownloadManager.instance;

  // Device settings
  String? _deviceName;
  String? _deviceHost;
  int? _devicePort;

  // Docker socket settings
  List<DockerSocket> _dockerSockets = [];
  String? _currentSocketPath;
  bool _dockerAvailable = false;

  // Download stats
  int _downloadCount = 0;
  int _downloadSize = 0;

  // App settings
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // Load device settings
      final device = await _deviceService.getSavedDevice();
      final downloadFiles = await _downloadManager.getDownloadedFiles();
      final downloadSize = await _downloadManager.getTotalDownloadSize();

      // Load Docker socket settings
      List<DockerSocket> sockets = [];
      String? currentSocket;
      bool dockerOk = false;

      try {
        sockets = await _dockerSocketService.getDockerSockets();
        currentSocket = await _dockerSocketService.getCurrentSocket();
        final health = await _dockerSocketService.getHealthStatus();
        dockerOk = health['services']?['docker'] == true;
      } catch (e) {
        // Docker socket service not available, ignore
      }

      setState(() {
        _deviceName = device?.name;
        _deviceHost = device?.host;
        _devicePort = device?.port;
        _downloadCount = downloadFiles.length;
        _downloadSize = downloadSize;
        _dockerSockets = sockets;
        _currentSocketPath = currentSocket;
        _dockerAvailable = dockerOk;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearDeviceSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Device Settings'),
        content: const Text(
          'This will remove the saved device configuration. You will need to select a device again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deviceService.clearDevice();
      appConfig.invalidateCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device settings cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadSettings();
    }
  }

  Future<void> _editDeviceSettings() async {
    final hostController = TextEditingController(text: _deviceHost ?? '');
    final portController = TextEditingController(
      text: _devicePort?.toString() ?? '2375',
    );
    final nameController = TextEditingController(text: _deviceName ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Device Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  hintText: 'My Computer',
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: 'Host / IP Address',
                  hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.computer),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '2375',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final host = hostController.text.trim();
      final port = int.tryParse(portController.text.trim()) ?? 2375;
      final name = nameController.text.trim();

      if (host.isNotEmpty) {
        await _deviceService.saveHostAndPort(
          host,
          port,
          name: name.isNotEmpty ? name : null,
        );
        appConfig.invalidateCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device settings saved'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadSettings();
      }
    }
  }

  Future<void> _clearDownloads() async {
    if (_downloadCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No downloads to clear'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Downloads'),
        content: Text(
          'Delete all $_downloadCount downloaded file(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final count = await _downloadManager.clearAllDownloads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count file(s)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadSettings();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _showDockerSocketSelector() async {
    if (_dockerSockets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Docker sockets available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Docker Socket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _dockerSockets.map((socket) {
            return RadioListTile<String>(
              title: Text(socket.displayName),
              subtitle: Text(
                socket.path,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              secondary: Icon(
                socket.available ? Icons.check_circle : Icons.error,
                color: socket.available ? Colors.green : Colors.red,
              ),
              value: socket.path,
              groupValue: _currentSocketPath,
              onChanged: socket.available
                  ? (value) => Navigator.pop(context, value)
                  : null,
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && selected != _currentSocketPath) {
      try {
        await _dockerSocketService.selectSocket(selected);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Docker socket changed'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadSettings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to change socket: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getDockerSocketDisplayName() {
    if (_currentSocketPath == null) return 'Not connected';
    final socket = _dockerSockets.firstWhere(
      (s) => s.path == _currentSocketPath,
      orElse: () => DockerSocket(
        path: _currentSocketPath!,
        available: false,
        active: true,
      ),
    );
    return socket.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return Core(
      title: 'Settings',
      onDeviceChanged: () {
        _dockerSocketService.refreshBaseUrl();
        _loadSettings();
      },
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Device Section
                  _buildSectionHeader('Device Connection'),
                  _buildSettingsTile(
                    icon: Icons.computer,
                    iconColor: Colors.blue,
                    title: 'Connected Device',
                    subtitle: _deviceHost != null
                        ? '${_deviceName ?? 'Device'} (${_deviceHost}:${_devicePort})'
                        : 'No device configured',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: _editDeviceSettings,
                          tooltip: 'Edit',
                        ),
                        if (_deviceHost != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _clearDeviceSettings,
                            tooltip: 'Clear',
                          ),
                      ],
                    ),
                  ),

                  const Divider(height: 32),

                  // Docker Section
                  _buildSectionHeader('Docker'),
                  _buildSettingsTile(
                    icon: Icons.storage,
                    iconColor: Colors.cyan,
                    title: 'Docker Socket',
                    subtitle: _getDockerSocketDisplayName(),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _dockerAvailable ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: _showDockerSocketSelector,
                  ),

                  const Divider(height: 32),

                  // Storage Section
                  _buildSectionHeader('Storage'),
                  _buildSettingsTile(
                    icon: Icons.folder,
                    iconColor: Colors.orange,
                    title: 'Downloads',
                    subtitle:
                        '$_downloadCount files • ${_formatSize(_downloadSize)}',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DownloadsScreen(),
                      ),
                    ).then((_) => _loadSettings()),
                  ),
                  _buildSettingsTile(
                    icon: Icons.delete_sweep,
                    iconColor: Colors.red,
                    title: 'Clear Downloads',
                    subtitle: 'Delete all downloaded files',
                    onTap: _clearDownloads,
                  ),

                  const Divider(height: 32),

                  // About Section
                  _buildSectionHeader('About'),
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    iconColor: Colors.purple,
                    title: 'DevMate',
                    subtitle: 'Version 0.1 • Ox03bb',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
