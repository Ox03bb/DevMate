import 'package:devmate/docker/screens/containers.dart';
import 'package:devmate/docker/screens/images.dart';
import 'package:devmate/shared/widgets/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DockerScreen extends StatefulWidget {
  const DockerScreen({super.key});

  @override
  State<DockerScreen> createState() => _DockerScreenState();
}

class _DockerScreenState extends State<DockerScreen> {
  int currentpage = 0;

  // Define the pages for each tab
  final List<Widget> _pages = const [
    ContainersBody(),
    ImagesBody(),
    Center(child: Text('Volumes')),
  ];

  @override
  Widget build(BuildContext context) {
    return Core(
      title: 'Docker',
      body: _pages[currentpage],
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(
            icon: SvgPicture.asset(
              'images/docker/icons/container.svg',
              width: 24,
              height: 24,
            ),
            label: "containers",
          ),
          NavigationDestination(
            icon: const Icon(Icons.document_scanner),
            label: "images",
          ),
          NavigationDestination(
            icon: SvgPicture.asset(
              'images/docker/icons/volumes.svg',
              width: 24,
              height: 24,
            ),
            label: "volumes",
          ),
        ],
        onDestinationSelected: (int index) {
          setState(() {
            currentpage = index;
          });
        },
        selectedIndex: currentpage,
      ),
    );
  }
}
