class Habit {
  const Habit({
    required this.id,
    required this.name,
    this.target = 1,
    this.unit = 'times',
    this.dailyCounts = const {},
  });

  final String id;
  final String name;
  final int target;
  final String unit;
  final Map<String, int> dailyCounts;

  int countOn(DateTime day) => dailyCounts[dayKey(day)] ?? 0;

  bool isCompleteOn(DateTime day) => countOn(day) >= target;

  Habit addCount(DateTime day) => _withCount(day, countOn(day) + 1);

  Habit removeCount(DateTime day) => _withCount(day, countOn(day) - 1);

  Habit _withCount(DateTime day, int count) {
    final updatedCounts = Map<String, int>.from(dailyCounts);
    final key = dayKey(day);
    if (count <= 0) {
      updatedCounts.remove(key);
    } else {
      updatedCounts[key] = count > target ? target : count;
    }
    return copyWith(dailyCounts: updatedCounts);
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

  Habit copyWith({int? target, String? unit, Map<String, int>? dailyCounts}) =>
      Habit(
        id: id,
        name: name,
        target: target ?? this.target,
        unit: unit ?? this.unit,
        dailyCounts: dailyCounts ?? this.dailyCounts,
      );
}

String dayKey(DateTime day) {
  final localDay = DateTime(day.year, day.month, day.day);
  final year = localDay.year.toString().padLeft(4, '0');
  final month = localDay.month.toString().padLeft(2, '0');
  final date = localDay.day.toString().padLeft(2, '0');
  return '$year-$month-$date';
}
