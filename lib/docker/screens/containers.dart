import 'package:flutter/material.dart';
import 'package:devmate/docker/widgets/containers_list.dart';
import 'package:devmate/docker/services/api.dart';
import 'package:devmate/docker/models/container.dart';

class ContainersBody extends StatefulWidget {
  const ContainersBody({super.key});

  @override
  State<ContainersBody> createState() => _ContainersBodyState();
}

class _ContainersBodyState extends State<ContainersBody> {
  late Future<List<ContainerModel>> containersFuture;
  final DockerApiService apiService = DockerApiService();

  @override
  void initState() {
    super.initState();
    containersFuture = apiService.fetchContainers();
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
        final containers = snapshot.data!;
        return ListView.builder(
          itemCount: containers.length,
          itemBuilder: (context, index) {
            final container = containers[index];
            return ContainersList(container: container);
          },
        );
      },
    );
  }
}
