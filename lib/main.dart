import 'package:flutter/material.dart';

import 'data/habit_repository.dart';
import 'presentation/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = HabitRepository();
  runApp(RizeApp(repository: repository));
}

class RizeApp extends StatelessWidget {
  const RizeApp({required this.repository, super.key});

  final HabitRepository repository;

  @override
  Widget build(BuildContext context) {
    const colors = ColorScheme.dark(
      primary: Color(0xFF9188FF),
      secondary: Color(0xFFFF777B),
      surface: Color(0xFF17171C),
      error: Color(0xFFFF777B),
      onPrimary: Color(0xFF101014),
      onSecondary: Color(0xFF101014),
      onSurface: Color(0xFFF7F5FA),
    );

    return MaterialApp(
      title: 'Rize',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xFF101014),
        fontFamily: 'Roboto',
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.surface,
          contentTextStyle: const TextStyle(color: Color(0xFFF7F5FA)),
        ),
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
