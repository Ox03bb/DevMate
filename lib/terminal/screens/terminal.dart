import 'package:flutter/material.dart';
import 'package:devmate/shared/widgets/core.dart';
import 'package:devmate/terminal/widgets/ssh_terminal_widget.dart';

/// Terminal screen that hosts the SSH client.
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const Core(
      body: SSHTerminalWidget(
        key: PageStorageKey<String>('ssh_terminal_widget'),
      ),
    );
  }
}
