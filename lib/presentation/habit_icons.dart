import 'package:flutter/material.dart';

const habitIcons = <String, IconData>{
  'spa': Icons.spa_outlined,
  'favorite': Icons.favorite_outline_rounded,
  'fitness': Icons.fitness_center_rounded,
  'water': Icons.water_drop_outlined,
  'book': Icons.menu_book_rounded,
  'walk': Icons.directions_walk_rounded,
  'meditate': Icons.self_improvement_rounded,
  'sleep': Icons.bedtime_outlined,
  'music': Icons.music_note_rounded,
  'food': Icons.restaurant_outlined,
  'work': Icons.work_outline_rounded,
  'check': Icons.check_circle_outline_rounded,
};

IconData habitIcon(String name) => habitIcons[name] ?? Icons.spa_outlined;
