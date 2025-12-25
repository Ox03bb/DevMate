import 'package:devmate/docker/models/container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
import 'package:devmate/docker/services/inspect_service.dart';

class ContainerInspectTab extends StatefulWidget {
  final ContainerModel container;
  const ContainerInspectTab({Key? key, required this.container})
    : super(key: key);

  @override
  State<ContainerInspectTab> createState() => _ContainerInspectTabState();
}

class _ContainerInspectTabState extends State<ContainerInspectTab> {
  late Future<Map<String, dynamic>> _inspectFuture;

  @override
  void initState() {
    super.initState();

    _inspectFuture = DockerInspectService().inspectContainer(
      widget.container.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _inspectFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        } else if (snapshot.hasData) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: JsonView.map(
                snapshot.data!,
                theme: JsonViewTheme(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  keyStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  doubleStyle: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 16,
                  ),
                  intStyle: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 16,
                  ),
                  stringStyle: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontSize: 16,
                  ),
                  boolStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  ),
                  closeIcon: Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  openIcon: Icon(
                    Icons.arrow_right,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  separator: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      ":",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const Center(child: Text('No data'));
        }
      },
    );
  }
}
