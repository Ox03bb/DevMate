import 'package:flutter/material.dart';
import 'package:devmate/docker/widgets/containers_list.dart';
import 'package:devmate/docker/widgets/composer.dart';
import 'package:devmate/docker/services/api.dart';
import 'package:devmate/docker/models/container.dart';

class ContainersBody extends StatefulWidget {
  const ContainersBody({super.key});

  @override
  State<ContainersBody> createState() => _ContainersBodyState();
}

class _ContainersBodyState extends State<ContainersBody> {
  final DockerApiService apiService = DockerApiService();
  late final Future<List<ContainerModel>> containersFuture = apiService
      .fetchContainers();
  final Map<String, List<ContainerModel>> composeGroups = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContainerModel>>(
      future: containersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No containers found'));
        }
        final containers = List<ContainerModel>.from(snapshot.data!);
        composeGroups.clear();
        final List<ContainerModel> singleContainers = [];

        for (var container in containers) {
          if (container.labels != null &&
              container.labels!.keys.any(
                (key) => key.startsWith('com.docker.compose.'),
              )) {
            final projectName =
                container.labels!['com.docker.compose.project'] ?? 'default';
            composeGroups.putIfAbsent(projectName, () => []);
            composeGroups[projectName]!.add(container);
          } else {
            singleContainers.add(container);
          }
        }

        final List<Widget> widgets = [];
        composeGroups.forEach((project, containers) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ComposerW(
                name: project,
                container: containers
                    .map((c) => ContainersList(container: c))
                    .toList(),
              ),
            ),
          );
        });
        // Add single containers
        for (var container in singleContainers) {
          widgets.add(ContainersList(container: container));
        }

        return ListView(children: widgets);
      },
    );
  }
}
