import 'package:flutter/material.dart';
import 'package:devmate/docker/models/container.dart';
import 'package:devmate/docker/screens/container_details.dart';
import 'package:devmate/docker/services/container_service.dart';

class ContainersList extends StatefulWidget {
  final ContainerModel container;
  final VoidCallback? onContainerAction;

  const ContainersList({
    super.key,
    required this.container,
    this.onContainerAction,
  });

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
        onSelected: (value) async {
          try {
            final containerService = ContainerService();
            switch (value) {
              case 'Start':
                await containerService.startContainer(widget.container.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Container ${widget.container.name} started',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                  widget.onContainerAction?.call();
                }
                break;
              case 'Stop':
                await containerService.stopContainer(widget.container.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Container ${widget.container.name} stopped',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  widget.onContainerAction?.call();
                }
                break;
              case 'Restart':
                await containerService.restartContainer(widget.container.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Container ${widget.container.name} restarted',
                      ),
                      backgroundColor: Colors.blue,
                    ),
                  );
                  widget.onContainerAction?.call();
                }
                break;
            }
            // Refresh the parent widget to update the container state
            if (context.mounted) {
              setState(() {});
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        itemBuilder: (context) {
          final state = widget.container.state.toLowerCase();
          final isRunning = state == 'running';
          final isStopped =
              state.contains('exited') ||
              state == 'dead' ||
              state == 'created' ||
              state == 'removing' ||
              state == 'paused';
          List<PopupMenuEntry<String>> items = [];
          if (isRunning) {
            items.add(
              PopupMenuItem(
                value: 'Stop',
                child: Row(
                  children: [
                    Icon(Icons.stop, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Stop'),
                  ],
                ),
              ),
            );
          } else if (isStopped) {
            items.add(
              PopupMenuItem(
                value: 'Start',
                child: Row(
                  children: [
                    Icon(Icons.play_arrow, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Start'),
                  ],
                ),
              ),
            );
          }
          items.add(
            PopupMenuItem(
              value: 'Restart',
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Restart'),
                ],
              ),
            ),
          );
          return items;
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContainerDetails(container: widget.container),
          ),
        );
      },
    );
  }
}
