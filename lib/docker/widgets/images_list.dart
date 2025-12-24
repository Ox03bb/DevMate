import 'package:flutter/material.dart';
import 'package:devmate/docker/models/images.dart';

class ImagesList extends StatefulWidget {
  final ImageModel image;

  const ImagesList({super.key, required this.image});

  @override
  State<ImagesList> createState() => _ImagesListState();
}

class _ImagesListState extends State<ImagesList> {
  String _formatSize(int size) {
    double mb = size / 1000000;
    if (mb > 1000) {
      double gb = mb / 1000;
      return '${gb.toStringAsFixed(2)} GB';
    } else {
      return '${mb.toStringAsFixed(2)} MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.image.name),
      subtitle: SizedBox(
        child: Row(children: [Text("Tag: "), Text(widget.image.tag)]),
      ),
      leading: Icon(Icons.file_copy),
      trailing: Text(_formatSize(widget.image.size)),

      onTap: () {
        // Handle container tap
      },
    );
  }
}
