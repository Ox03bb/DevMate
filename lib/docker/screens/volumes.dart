import 'package:flutter/material.dart';
import 'package:devmate/docker/services/api.dart';
import 'package:devmate/docker/models/volumes.dart';
import 'package:devmate/docker/widgets/volumes_list.dart';

class VolumesBody extends StatefulWidget {
  const VolumesBody({super.key});

  @override
  State<VolumesBody> createState() => _VolumesBodyState();
}

class _VolumesBodyState extends State<VolumesBody> {
  late Future<List<VolumeModel>> _volumesFuture;

  @override
  void initState() {
    super.initState();
    _volumesFuture = DockerApiService().fetchVolumes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VolumeModel>>(
      future: _volumesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No volumes found'));
        } else {
          final volumes = snapshot.data!;
          return ListView.builder(
            itemCount: volumes.length,
            itemBuilder: (context, index) {
              return VolumesList(volume: volumes[index]);
            },
          );
        }
      },
    );
  }
}
