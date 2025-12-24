import 'package:flutter/material.dart';
import 'package:devmate/docker/models/container.dart';

class ContainersList extends StatefulWidget {
  final ContainerModel container;

  const ContainersList({super.key, required this.container});

  @override
  State<ContainersList> createState() => _ContainersListState();
}

class _ContainersListState extends State<ContainersList> {
  Color _getStateColor(String state) {
    switch (state.toLowerCase()) {
      case 'running':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'restarting':
        return Colors.blue;
      case var s when s.contains('exited'):
      case 'dead':
        return Colors.red;
      case 'created':
      case 'removing':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.container.name),
      subtitle: SizedBox(
        child: Row(
          children: [
            Text("State: "),
            Text(
              widget.container.state,
              style: TextStyle(color: _getStateColor(widget.container.state)),
            ),
          ],
        ),
      ),
      leading: Icon(Icons.dns),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert),
        onSelected: (value) {
          // Handle selected action
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'Start', child: Text('Start')),
          PopupMenuItem(value: 'Stop', child: Text('Stop')),
          PopupMenuItem(value: 'Restart', child: Text('Restart')),
          PopupMenuItem(value: 'Remove', child: Text('Remove')),
        ],
      ),
      onTap: () {
        // Handle container tap
      },
    );
  }
}
