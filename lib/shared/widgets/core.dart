import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:devmate/shared/widgets/device_discovery_dialog.dart';
import 'package:devmate/shared/services/device_settings_service.dart';
import 'package:devmate/config.dart';

const BaseColor = Color.fromARGB(255, 27, 71, 173);

class Core extends StatelessWidget {
  final Widget body;
  final String title;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;
  final VoidCallback? onDeviceChanged;

  const Core({
    super.key,
    required this.body,
    this.title = 'DevMate',
    this.bottomNavigationBar,
    this.actions,
    this.onDeviceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            color: Theme.of(context).colorScheme.onPrimary,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          // Device discovery action button
          IconButton(
            icon: const Icon(Icons.wifi_find),
            color: Theme.of(context).colorScheme.onPrimary,
            tooltip: 'Discover Devices',
            onPressed: () async {
              final device = await DeviceDiscoveryDialog.show(
                context,
                serviceType: DEVMATE_MDNS_SERVICE_TYPE,
              );
              if (device != null) {
                appConfig.invalidateCache();
                onDeviceChanged?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Connected to ${device.name} (${device.host}:${device.port})',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
          ...?actions,
        ],
      ),
      drawer: _CoreDrawer(onDeviceChanged: onDeviceChanged),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class _CoreDrawer extends StatefulWidget {
  final VoidCallback? onDeviceChanged;

  const _CoreDrawer({this.onDeviceChanged});

  @override
  State<_CoreDrawer> createState() => _CoreDrawerState();
}

class _CoreDrawerState extends State<_CoreDrawer> {
  final DeviceSettingsService _settingsService = DeviceSettingsService();
  String? _currentHost;
  int? _currentPort;

  @override
  void initState() {
    super.initState();
    _loadCurrentDevice();
  }

  Future<void> _loadCurrentDevice() async {
    final host = await _settingsService.getHost();
    final port = await _settingsService.getPort();
    if (mounted) {
      setState(() {
        _currentHost = host ?? DEFAULT_HOST;
        _currentPort = port ?? DEFAULT_DOCKER_PORT;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  'DevMate',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Welcome!',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                // Show current device
                if (_currentHost != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.computer,
                          size: 14,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_currentHost:$_currentPort',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Device Discovery option
          ListTile(
            leading: const Icon(Icons.wifi_find),
            title: const Text('Discover Devices'),
            subtitle: _currentHost != null
                ? Text(
                    'Current: $_currentHost:$_currentPort',
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
            onTap: () async {
              Navigator.pop(context); // Close drawer first
              final device = await DeviceDiscoveryDialog.show(
                context,
                serviceType: DEVMATE_MDNS_SERVICE_TYPE,
              );
              if (device != null) {
                appConfig.invalidateCache();
                widget.onDeviceChanged?.call();
                _loadCurrentDevice();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Connected to ${device.name} (${device.host}:${device.port})',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: SvgPicture.asset(
              'images/docker/icons/docker.svg',
              width: 24,
              height: 24,
            ),
            title: const Text('Docker'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushReplacementNamed(context, '/docker');
            },
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Terminal'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/terminal');
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_open_sharp),
            title: const Text('File Sharing'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/files');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/settings');
            },
          ),
        ],
      ),
    );
  }
}
