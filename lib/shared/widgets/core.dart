import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const BaseColor = Color.fromARGB(255, 27, 71, 173);

class Core extends StatelessWidget {
  final Widget body;
  final String title;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;

  const Core({
    super.key,
    required this.body,
    this.title = 'DevMate',
    this.bottomNavigationBar,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            color: Theme.of(context).colorScheme.onPrimary,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: actions,
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'DevMate',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Welcome!',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: SvgPicture.asset(
                'images/docker/icons/docker.svg',
                width: 24,
                height: 24,
              ),
              title: const Text('Docker'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacementNamed(context, '/docker');
              },
            ),
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text('Terminal'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/terminal');
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_open_sharp),
              title: const Text('File Sharing'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/files');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
