import 'package:flutter/material.dart';

import 'package:devmate/docker/services/api.dart';
import 'package:devmate/docker/models/images.dart';
import 'package:devmate/docker/widgets/images_list.dart';

class ImagesBody extends StatefulWidget {
  const ImagesBody({super.key});

  @override
  State<ImagesBody> createState() => _ImagesBodyState();
}

class _ImagesBodyState extends State<ImagesBody> {
  late Future<List<ImageModel>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = DockerApiService().fetchImages();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ImageModel>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No images found'));
        } else {
          final images = snapshot.data!;
          return ListView.builder(
            itemCount: images.length,
            itemBuilder: (context, index) {
              return ImagesList(image: images[index]);
            },
          );
        }
      },
    );
  }
}
