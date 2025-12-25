import 'package:flutter/material.dart';
import 'package:devmate/docker/models/volumes.dart';

class VolumesList extends StatelessWidget {
  final VolumeModel volume;

  const VolumesList({super.key, required this.volume});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(volume.name),
      subtitle: Row(
        children: [
          Text("Driver: "),
          Text(volume.driver),
        ],
      ),
      leading: Icon(Icons.storage),
      trailing: Text(
        "${volume.createdAt.toLocal().toString().split(' ').first}",
        style: TextStyle(fontSize: 12),
      ),
      onTap: () {
        // Handle volume tap
      },
    );
  }
}
