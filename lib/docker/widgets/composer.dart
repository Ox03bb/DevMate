import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:devmate/docker/widgets/containers_list.dart';
import 'package:devmate/docker/models/container.dart';
import 'package:devmate/docker/services/container_service.dart';

class ComposerW extends StatefulWidget {
  final String name;
  final List<ContainersList> container;
  final List<ContainerModel> containerModels;
  final VoidCallback? onContainerAction;

  const ComposerW({
    super.key,
    required this.name,
    required this.container,
    required this.containerModels,
    this.onContainerAction,
  });

  @override
  State<ComposerW> createState() => _ComposerWState();
}

class _ComposerWState extends State<ComposerW> {
  bool _isExpanded = false;
  bool _isLoading = false;
  final ContainerService _containerService = ContainerService();

  int get _runningCount => widget.containerModels
      .where((c) => c.state.toLowerCase() == 'running')
      .length;

  int get _totalCount => widget.containerModels.length;

  Future<void> _startAll() async {
    setState(() => _isLoading = true);
    try {
      for (var container in widget.containerModels) {
        if (container.state.toLowerCase() != 'running') {
          await _containerService.startContainer(container.id);
        }
      }
      widget.onContainerAction?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start containers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stopAll() async {
    setState(() => _isLoading = true);
    try {
      for (var container in widget.containerModels) {
        if (container.state.toLowerCase() == 'running') {
          await _containerService.stopContainer(container.id);
        }
      }
      widget.onContainerAction?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop containers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restartAll() async {
    setState(() => _isLoading = true);
    try {
      for (var container in widget.containerModels) {
        await _containerService.restartContainer(container.id);
      }
      widget.onContainerAction?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restart containers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'start',
          child: Row(
            children: [
              Icon(Icons.play_arrow, color: Colors.green),
              SizedBox(width: 8),
              Text('Start All'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'stop',
          child: Row(
            children: [
              Icon(Icons.stop, color: Colors.red),
              SizedBox(width: 8),
              Text('Stop All'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'restart',
          child: Row(
            children: [
              Icon(Icons.refresh, color: Colors.orange),
              SizedBox(width: 8),
              Text('Restart All'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'start':
          _startAll();
          break;
        case 'stop':
          _stopAll();
          break;
        case 'restart':
          _restartAll();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isExpanded = isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (context, isExpanded) {
              return ListTile(
                leading: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) =>
                      _showContextMenu(context, details.globalPosition),
                  child: SvgPicture.asset(
                    'images/docker/icons/composer.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
                title: Text('${widget.name}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) =>
                          _showContextMenu(context, details.globalPosition),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _runningCount > 0
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_runningCount / $_totalCount',
                          style: TextStyle(
                            color: _runningCount > 0
                                ? Colors.green
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              );
            },
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [...widget.container],
              ),
            ),
            isExpanded: _isExpanded,
          ),
        ],
      ),
    );
  }
}
