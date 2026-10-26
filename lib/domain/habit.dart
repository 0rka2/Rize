class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.completedDays,
  });

  final String id;
  final String name;
  final Set<String> completedDays;

  bool isCompleteOn(DateTime day) => completedDays.contains(dayKey(day));

  Habit toggleCompletion(DateTime day) {
    final updatedDays = Set<String>.from(completedDays);
    final key = dayKey(day);
    if (!updatedDays.add(key)) {
      updatedDays.remove(key);
    }
    return copyWith(completedDays: updatedDays);
  }

  int currentStreak(DateTime today) {
    var day = DateTime(today.year, today.month, today.day);
    if (!isCompleteOn(day)) {
      day = day.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (isCompleteOn(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Habit copyWith({Set<String>? completedDays}) => Habit(
        id: id,
        name: name,
        completedDays: completedDays ?? this.completedDays,
      );
}

String dayKey(DateTime day) {
  final localDay = DateTime(day.year, day.month, day.day);
  final year = localDay.year.toString().padLeft(4, '0');
  final month = localDay.month.toString().padLeft(2, '0');
  final date = localDay.day.toString().padLeft(2, '0');
  return '$year-$month-$date';
}
