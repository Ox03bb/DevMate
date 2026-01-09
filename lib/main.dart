import 'package:flutter/material.dart';
import 'package:devmate/docker/screens/docker.dart';
import 'package:devmate/terminal/screens/terminal.dart';
import 'package:devmate/files/screens/file_share_screen.dart';
import 'package:devmate/shared/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-initialize SharedPreferences
  await SharedPreferences.getInstance();
  runApp(const MyApp());
}

const BaseColor = Color.fromARGB(255, 27, 71, 173);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: BaseColor,
          primary: BaseColor,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: BaseColor,
          primary: BaseColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/docker',
      routes: {
        '/docker': (context) => const DockerScreen(),
        '/terminal': (context) => const TerminalScreen(),
        '/files': (context) => const FileShareScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
