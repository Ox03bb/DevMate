import 'dart:async';
import 'package:flutter/material.dart';
import 'package:devmate/terminal/services/ssh_service.dart';
import 'package:devmate/terminal/services/ssh_settings_service.dart';
import 'package:devmate/shared/services/device_settings_service.dart';
import 'package:devmate/config.dart';
import 'package:devmate/terminal/widgets/ansi_text.dart';

/// SSH Terminal widget with connection form and terminal display.
class SSHTerminalWidget extends StatefulWidget {
  const SSHTerminalWidget({super.key});

  @override
  State<SSHTerminalWidget> createState() => _SSHTerminalWidgetState();
}

class _SSHTerminalWidgetState extends State<SSHTerminalWidget>
    with AutomaticKeepAliveClientMixin {
  final SSHService _sshService = SSHService(); // Now a singleton
  final SSHSettingsService _settingsService = SSHSettingsService();
  final DeviceSettingsService _deviceSettingsService = DeviceSettingsService();

  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '22',
  );
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _outputScrollController = ScrollController();

  final List<String> _output = [];
  bool _isConnecting = false;
  String? _connectionError;
  bool _obscurePassword = true;
  StreamSubscription? _outputSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupOutputStream();
  }

  void _setupOutputStream() {
    _outputSubscription = _sshService.outputStream.listen(
      (data) {
        if (mounted) {
          setState(() {
            _output.add(data);
          });
          _scrollToBottom();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _output.add('\x1b[31mError: $error\x1b[0m');
          });
          _scrollToBottom();
        }
      },
    );
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _commandController.dispose();
    _outputScrollController.dispose();
    // Don't dispose SSH service - it's a singleton
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Load device settings to get default host
    final device = await _deviceSettingsService.getSavedDevice();

    // Load SSH settings
    final sshSettings = await _settingsService.loadSettings();

    if (mounted) {
      setState(() {
        // Set host from device settings if available, otherwise from SSH settings
        if (device != null) {
          _hostController.text = sshSettings?['host'] ?? device.host;
        } else if (sshSettings != null) {
          _hostController.text = sshSettings['host'];
        } else {
          // Get default host from config
          _hostController.text = DEFAULT_HOST;
        }

        // Set port and username from SSH settings
        if (sshSettings != null) {
          _portController.text = sshSettings['port'].toString();
          _usernameController.text = sshSettings['username'];
        }
      });
    }
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (host.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        _connectionError = 'Please fill in all fields';
      });
      return;
    }

    final port = int.tryParse(portText);
    if (port == null || port <= 0 || port > 65535) {
      setState(() {
        _connectionError = 'Invalid port number';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionError = null;
      _output.clear();
    });

    try {
      await _sshService.connect(
        host: host,
        port: port,
        username: username,
        password: password,
      );

      // Save settings (without password)
      await _settingsService.saveSettings(
        host: host,
        port: port,
        username: username,
      );

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        // Clear initial output and switch to bash shell
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _output.clear();
          });
        }
        _sshService.sendCommand('bash');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError = 'Connection failed: $e';
        });
      }
    }
  }

  Future<void> _disconnect() async {
    await _sshService.disconnect();
    if (mounted) {
      setState(() {
        _output.clear();
      });
    }
  }

  void _sendCommand() {
    final command = _commandController.text.trim();
    if (command.isNotEmpty && _sshService.isConnected) {
      // Handle clear command locally
      if (command == 'clear') {
        setState(() {
          _output.clear();
        });
        _commandController.clear();
        return;
      }

      _sshService.sendCommand(command);
      _commandController.clear();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_outputScrollController.hasClients) {
        _outputScrollController.animateTo(
          _outputScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (!_sshService.isConnected) {
      return _buildConnectionForm();
    }
    return _buildTerminal();
  }

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  Widget _buildConnectionForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'SSH Connection',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'root',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    enabled: !_isConnecting,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    enabled: !_isConnecting,
                    onSubmitted: (_) => _connect(),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host',
                      hintText: '192.168.1.100',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns),
                    ),
                    enabled: !_isConnecting,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '22',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isConnecting,
                  ),
                  const SizedBox(height: 24),
                  if (_connectionError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _connectionError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.icon(
                    onPressed: _isConnecting ? null : _connect,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTerminal() {
    return Column(
      children: [
        // Terminal header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SSH Terminal - ${_usernameController.text}@${_hostController.text}',
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() {
                    _output.clear();
                  });
                },
                tooltip: 'Clear',
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _disconnect,
                tooltip: 'Disconnect',
              ),
            ],
          ),
        ),
        // Terminal output
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            child: _output.isEmpty
                ? Center(
                    child: Text(
                      'Terminal ready. Type commands below.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _outputScrollController,
                    itemCount: _output.length,
                    itemBuilder: (context, index) {
                      return AnsiText(
                        _output[index],
                        baseStyle: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
          ),
        ),
        // Command input
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commandController,
                  decoration: InputDecoration(
                    hintText: 'Enter command...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendCommand(),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _sendCommand,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
