import 'package:flutter/material.dart';

import 'data/habit_repository.dart';
import 'presentation/home_screen.dart';
import 'theme/app_colors.dart';

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
      primary: AppColors.burntOrange,
      secondary: AppColors.successGreen,
      surface: AppColors.charcoalGrey,
      error: AppColors.burntOrange,
      onPrimary: AppColors.carbon,
      onSecondary: AppColors.carbon,
      onSurface: AppColors.offWhite,
    );

    return MaterialApp(
      title: 'Rize',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: AppColors.carbon,
        fontFamily: 'Roboto',
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.surface,
          contentTextStyle: const TextStyle(color: AppColors.offWhite),
        ),
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
