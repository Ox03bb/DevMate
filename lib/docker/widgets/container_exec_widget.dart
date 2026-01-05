import 'package:flutter/material.dart';
import 'package:devmate/docker/services/exec_service.dart';

class ContainerExecWidget extends StatefulWidget {
  final String containerId;

  const ContainerExecWidget({super.key, required this.containerId});

  @override
  State<ContainerExecWidget> createState() => _ContainerExecWidgetState();
}

class _ContainerExecWidgetState extends State<ContainerExecWidget>
    with AutomaticKeepAliveClientMixin {
  final ContainerExecService _execService = ContainerExecService();
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _history = [];
  bool _isExecuting = false;
  String _currentWorkingDirectory = '/';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _executeCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty || _isExecuting) return;

    // Handle clear command locally
    if (command == 'clear') {
      setState(() {
        _history.clear();
      });
      _commandController.clear();
      return;
    }

    setState(() {
      _history.add({
        'type': 'command',
        'text': '$_currentWorkingDirectory \$ $command',
      });
      _isExecuting = true;
    });

    _commandController.clear();
    _scrollToBottom();

    try {
      String fullCommand;

      // Check if it's a cd command to update working directory
      if (command.startsWith('cd ')) {
        final cdPath = command.substring(3).trim();
        if (cdPath.isEmpty || cdPath == '~') {
          // cd or cd ~ - go to home
          fullCommand = 'cd && pwd';
        } else if (cdPath.startsWith('/')) {
          // Absolute path
          fullCommand = 'cd $cdPath && pwd';
        } else {
          // Relative path
          fullCommand = 'cd $_currentWorkingDirectory && cd $cdPath && pwd';
        }

        final output = await _execService.execCommand(
          widget.containerId,
          fullCommand,
        );

        // Update the current working directory
        final newDir = output.trim();
        if (newDir.isNotEmpty && newDir.startsWith('/')) {
          _currentWorkingDirectory = newDir;
          setState(() {
            _history.add({'type': 'output', 'text': ''});
            _isExecuting = false;
          });
        } else {
          throw Exception('Failed to change directory');
        }
      } else if (command == 'cd') {
        // cd without arguments - go to home
        fullCommand = 'cd && pwd';

        final output = await _execService.execCommand(
          widget.containerId,
          fullCommand,
        );

        final newDir = output.trim();
        if (newDir.isNotEmpty && newDir.startsWith('/')) {
          _currentWorkingDirectory = newDir;
          setState(() {
            _history.add({'type': 'output', 'text': ''});
            _isExecuting = false;
          });
        }
      } else {
        // Regular command - execute in current directory
        fullCommand = 'cd $_currentWorkingDirectory && $command';

        final output = await _execService.execCommand(
          widget.containerId,
          fullCommand,
        );
        setState(() {
          _history.add({
            'type': 'output',
            'text': output.isEmpty ? '(no output)' : output,
          });
          _isExecuting = false;
        });
      }
    } catch (e) {
      setState(() {
        _history.add({'type': 'error', 'text': 'Error: $e'});
        _isExecuting = false;
      });
    }

    _scrollToBottom();
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
      _currentWorkingDirectory = '/';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Terminal header with actions
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        //   decoration: BoxDecoration(
        //     color: Theme.of(context).colorScheme.surfaceContainerHighest,
        //     border: Border(
        //       bottom: BorderSide(
        //         color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        //       ),
        //     ),
        //   ),
        //   child: Row(
        //     children: [
        //       Icon(
        //         Icons.terminal,
        //         size: 20,
        //         color: Theme.of(context).colorScheme.primary,
        //       ),
        //       const SizedBox(width: 8),
        //       Text(
        //         'Exec Terminal',
        //         style: Theme.of(
        //           context,
        //         ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        //       ),
        //       const Spacer(),
        //       IconButton(
        //         icon: const Icon(Icons.clear_all, size: 20),
        //         tooltip: 'Clear',
        //         onPressed: _history.isEmpty ? null : _clearHistory,
        //       ),
        //     ],
        //   ),
        // ),

        // Terminal output area
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            child: _history.isEmpty
                ? Center(
                    child: Text(
                      'Type a command below to execute in the container',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final entry = _history[index];
                      final type = entry['type']!;
                      final text = entry['text']!;

                      Color textColor;
                      if (type == 'command') {
                        textColor = Colors.green[400]!;
                      } else if (type == 'error') {
                        textColor = Colors.red[400]!;
                      } else {
                        textColor = Colors.white;
                      }

                      return SelectableText(
                        text,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Command input area
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              // Show current directory
              Text(
                '$_currentWorkingDirectory ',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _commandController,
                  enabled: !_isExecuting,
                  decoration: InputDecoration(
                    hintText: 'Enter command',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  onSubmitted: (_) => _executeCommand(),
                ),
              ),
              const SizedBox(width: 8),
              _isExecuting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _executeCommand,
                      tooltip: 'Execute',
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
