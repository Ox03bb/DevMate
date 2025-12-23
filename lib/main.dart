import 'package:flutter/material.dart';
import 'package:devmate/docker/screens/docker.dart';
import 'package:devmate/shared/widgets/core.dart';

void main() {
  runApp(const MyApp());
}

const BaseColor = Color.fromARGB(255, 27, 71, 173);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: BaseColor,
          primary: BaseColor,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/docker',
      routes: {
        '/docker': (context) => const DockerScreen(),
        '/terminal': (context) => const PlaceholderScreen(title: 'Terminal'),
        '/files': (context) => const PlaceholderScreen(title: 'File Sharing'),
        '/settings': (context) => const PlaceholderScreen(title: 'Settings'),
      },
    );
  }
}

// Temporary placeholder for screens not yet implemented
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Core(body: Center(child: Text('$title - Coming Soon')));
  }
}
