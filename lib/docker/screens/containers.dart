import 'package:flutter/material.dart';
import 'package:devmate/docker/widgets/containers_list.dart';
import 'package:devmate/docker/widgets/composer.dart';
import 'package:devmate/docker/services/api.dart';
import 'package:devmate/docker/models/container.dart';
import 'package:devmate/shared/widgets/device_discovery_dialog.dart';
import 'package:devmate/config.dart';

class ContainersBody extends StatefulWidget {
  const ContainersBody({super.key});

  @override
  State<ContainersBody> createState() => _ContainersBodyState();
}

class _ContainersBodyState extends State<ContainersBody> {
  final DockerApiService apiService = DockerApiService();
  late Future<List<ContainerModel>> containersFuture;
  final Map<String, List<ContainerModel>> composeGroups = {};

  @override
  void initState() {
    super.initState();
    containersFuture = apiService.fetchContainers();
  }

  void _refreshContainers() {
    setState(() {
      containersFuture = apiService.fetchContainers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContainerModel>>(
      future: containersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          final errorMessage = snapshot.error.toString();
          final isConnectionError =
              errorMessage.contains('network') ||
              errorMessage.contains('SocketException') ||
              errorMessage.contains('Connection') ||
              errorMessage.contains('cache available');

          if (isConnectionError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Connection',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to connect to the Docker service.\nPlease check your connection.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () async {
                        final device = await DeviceDiscoveryDialog.show(
                          context,
                          serviceType: DEVMATE_MDNS_SERVICE_TYPE,
                        );
                        if (device != null && context.mounted) {
                          appConfig.invalidateCache();
                          _refreshContainers();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Connected to ${device.name} (${device.host}:${device.port})',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.wifi_find),
                      label: const Text('Discover Devices'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refreshContainers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(child: Text('Error: $errorMessage'));
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
                    .map(
                      (c) => ContainersList(
                        container: c,
                        onContainerAction: _refreshContainers,
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        });
        for (var container in singleContainers) {
          widgets.add(
            ContainersList(
              container: container,
              onContainerAction: _refreshContainers,
            ),
          );
        }

        return ListView(children: widgets);
      },
    );
  }
}
