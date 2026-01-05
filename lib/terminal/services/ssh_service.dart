import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';

/// Service for managing SSH connections.
class SSHService {
  // Singleton pattern
  static final SSHService _instance = SSHService._internal();
  factory SSHService() => _instance;
  SSHService._internal();

  SSHClient? _client;
  SSHSession? _shell;
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();

  Stream<String> get outputStream => _outputController.stream;
  bool get isConnected => _client != null;

  /// Connect to SSH server with username and password.
  Future<void> connect({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      // Close existing connection if any
      await disconnect();

      // Create socket
      final socket = await SSHSocket.connect(host, port);

      // Create SSH client
      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      // Start interactive shell
      _shell = await _client!.shell(pty: SSHPtyConfig(width: 80, height: 24));

      // Listen to shell output
      _shell!.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(
            (data) {
              _outputController.add(data);
            },
            onError: (error) {
              _outputController.addError('Shell output error: $error');
            },
          );

      _shell!.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(
            (data) {
              _outputController.add(data);
            },
            onError: (error) {
              _outputController.addError('Shell error output: $error');
            },
          );
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  /// Send command to SSH shell.
  void sendCommand(String command) {
    if (_shell != null) {
      _shell!.stdin.add(utf8.encode('$command\n'));
    }
  }

  /// Disconnect from SSH server.
  Future<void> disconnect() async {
    _shell?.close();
    _shell = null;
    _client?.close();
    _client = null;
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    _outputController.close();
  }
}
