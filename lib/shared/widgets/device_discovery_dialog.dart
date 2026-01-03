import 'package:flutter/material.dart';
import 'package:devmate/shared/models/discovered_device.dart';
import 'package:devmate/shared/services/mdns_discovery_service.dart';
import 'package:devmate/shared/services/device_settings_service.dart';

/// A dialog widget for discovering and selecting devices via mDNS.
class DeviceDiscoveryDialog extends StatefulWidget {
  /// The mDNS service type to search for.
  final String serviceType;

  /// Callback when a device is selected.
  final Function(DiscoveredDevice device)? onDeviceSelected;

  const DeviceDiscoveryDialog({
    super.key,
    this.serviceType = MdnsDiscoveryService.defaultServiceType,
    this.onDeviceSelected,
  });

  /// Shows the device discovery dialog.
  static Future<DiscoveredDevice?> show(
    BuildContext context, {
    String serviceType = MdnsDiscoveryService.defaultServiceType,
  }) {
    return showDialog<DiscoveredDevice>(
      context: context,
      builder: (context) => DeviceDiscoveryDialog(serviceType: serviceType),
    );
  }

  @override
  State<DeviceDiscoveryDialog> createState() => _DeviceDiscoveryDialogState();
}

class _DeviceDiscoveryDialogState extends State<DeviceDiscoveryDialog> {
  final MdnsDiscoveryService _discoveryService = MdnsDiscoveryService();
  final DeviceSettingsService _settingsService = DeviceSettingsService();
  final List<DiscoveredDevice> _devices = [];
  bool _isSearching = false;
  String? _error;
  DiscoveredDevice? _selectedDevice;

  // Controllers for manual entry
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool _showManualEntry = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDevice();
    _startDiscovery();
  }

  @override
  void dispose() {
    _discoveryService.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDevice() async {
    final savedDevice = await _settingsService.getSavedDevice();
    if (savedDevice != null && mounted) {
      setState(() {
        _selectedDevice = savedDevice;
        _hostController.text = savedDevice.host;
        _portController.text = savedDevice.port.toString();
      });
    }
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isSearching = true;
      _error = null;
      _devices.clear();
    });

    try {
      await for (final device in _discoveryService.discoverDevicesStream(
        serviceType: widget.serviceType,
        timeout: const Duration(seconds: 10),
      )) {
        if (mounted) {
          setState(() {
            if (!_devices.contains(device)) {
              _devices.add(device);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Discovery error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectDevice(DiscoveredDevice device) async {
    await _settingsService.saveDevice(device);
    if (mounted) {
      widget.onDeviceSelected?.call(device);
      Navigator.of(context).pop(device);
    }
  }

  Future<void> _saveManualEntry() async {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a host address')),
      );
      return;
    }

    final port = int.tryParse(portText);
    if (port == null || port <= 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid port (1-65535)')),
      );
      return;
    }

    final device = DiscoveredDevice(
      name: 'Manual: $host',
      host: host,
      port: port,
    );

    await _selectDevice(device);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.wifi_find),
          const SizedBox(width: 8),
          const Expanded(child: Text('Discover Devices')),
          if (_isSearching)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle between discovered devices and manual entry
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showManualEntry = false),
                    icon: const Icon(Icons.search),
                    label: const Text('Discovered'),
                    style: TextButton.styleFrom(
                      backgroundColor: !_showManualEntry
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showManualEntry = true),
                    icon: const Icon(Icons.edit),
                    label: const Text('Manual'),
                    style: TextButton.styleFrom(
                      backgroundColor: _showManualEntry
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Content area
            Expanded(
              child: _showManualEntry
                  ? _buildManualEntry()
                  : _buildDeviceList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_showManualEntry)
          TextButton.icon(
            onPressed: _isSearching ? null : _startDiscovery,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        if (_showManualEntry)
          FilledButton(
            onPressed: _saveManualEntry,
            child: const Text('Connect'),
          ),
      ],
    );
  }

  Widget _buildDeviceList() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startDiscovery,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty && !_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Make sure the service is running\nand advertising via mDNS',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _startDiscovery,
              child: const Text('Search Again'),
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty && _isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching for devices...'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isSelected =
            _selectedDevice != null &&
            _selectedDevice!.host == device.host &&
            _selectedDevice!.port == device.port;

        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.computer,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(device.name),
            subtitle: Text('${device.host}:${device.port}'),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => _selectDevice(device),
          ),
        );
      },
    );
  }

  Widget _buildManualEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter device details manually:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _hostController,
          decoration: const InputDecoration(
            labelText: 'Host / IP Address',
            hintText: '192.168.1.100',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.dns),
          ),
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _portController,
          decoration: const InputDecoration(
            labelText: 'Port',
            hintText: '2375',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.numbers),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        if (_selectedDevice != null) ...[
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Currently saved:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${_selectedDevice!.host}:${_selectedDevice!.port}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}
