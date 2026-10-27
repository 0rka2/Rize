enum HabitType { build, quit }

enum TrackingMode { yesNo, count, measure }

enum TapAction { addOne, enterTotal }

enum GoalPeriod { none, daily, weekly, monthly }

class HabitSettings {
  const HabitSettings({
    required this.name,
    required this.description,
    required this.colorValue,
    required this.icon,
    required this.type,
    required this.trackingMode,
    required this.target,
    required this.unit,
    required this.tapAction,
    required this.goalPeriod,
    required this.weeklyGoalTarget,
    required this.monthlyGoalTarget,
  });

  final String name;
  final String description;
  final int colorValue;
  final String icon;
  final HabitType type;
  final TrackingMode trackingMode;
  final double target;
  final String unit;
  final TapAction tapAction;
  final GoalPeriod goalPeriod;
  final int weeklyGoalTarget;
  final int monthlyGoalTarget;
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    this.description = '',
    this.colorValue = 0xFFFF7A00,
    this.icon = 'spa',
    this.type = HabitType.build,
    this.trackingMode = TrackingMode.count,
    this.target = 1,
    this.unit = 'times',
    this.tapAction = TapAction.addOne,
    this.goalPeriod = GoalPeriod.none,
    this.weeklyGoalTarget = 1,
    this.monthlyGoalTarget = 1,
    this.dailyCounts = const {},
  });

  final String id;
  final String name;
  final String description;
  final int colorValue;
  final String icon;
  final HabitType type;
  final TrackingMode trackingMode;
  final double target;
  final String unit;
  final TapAction tapAction;
  final GoalPeriod goalPeriod;
  final int weeklyGoalTarget;
  final int monthlyGoalTarget;
  final Map<String, num> dailyCounts;

  double countOn(DateTime day) => (dailyCounts[dayKey(day)] ?? 0).toDouble();

  bool isCompleteOn(DateTime day) {
    final count = countOn(day);
    if (type == HabitType.quit) return count == 0;
    if (trackingMode == TrackingMode.yesNo) return count > 0;
    return count >= target;
  }

  Habit addCount(DateTime day) {
    final next = countOn(day) + 1;
    if (type == HabitType.build &&
        trackingMode != TrackingMode.yesNo &&
        next > target) {
      return setCount(day, target);
    }
    return setCount(day, next);
  }

  Habit removeCount(DateTime day) => setCount(day, countOn(day) - 1);

  Habit toggleDay(DateTime day) => setCount(day, countOn(day) > 0 ? 0 : 1);

  Habit setCount(DateTime day, double count) {
    final updatedCounts = Map<String, double>.from(dailyCounts);
    final key = dayKey(day);
    if (count <= 0) {
      updatedCounts.remove(key);
    } else {
      updatedCounts[key] = count;
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

  int successfulDaysInPeriod(DateTime date, GoalPeriod period) {
    if (period == GoalPeriod.none) return 0;

    final today = DateTime.now();
    final lastEligibleDay = DateTime(today.year, today.month, today.day);
    final selectedDay = DateTime(date.year, date.month, date.day);
    if (selectedDay.isAfter(lastEligibleDay)) return 0;

    if (period == GoalPeriod.daily) {
      return isCompleteOn(selectedDay) ? 1 : 0;
    }

    final firstDay =
        period == GoalPeriod.weekly
            ? selectedDay.subtract(Duration(days: selectedDay.weekday - 1))
            : DateTime(selectedDay.year, selectedDay.month);
    final lastDay =
        period == GoalPeriod.weekly
            ? firstDay.add(const Duration(days: 6))
            : DateTime(selectedDay.year, selectedDay.month + 1, 0);
    final endDay = lastDay.isAfter(lastEligibleDay) ? lastEligibleDay : lastDay;

    var completedDays = 0;
    for (
      var day = firstDay;
      !day.isAfter(endDay);
      day = day.add(const Duration(days: 1))
    ) {
      if (isCompleteOn(day)) completedDays++;
    }
    return completedDays;
  }

  bool periodGoalReached(DateTime date) {
    final progress = successfulDaysInPeriod(date, goalPeriod);
    return switch (goalPeriod) {
      GoalPeriod.none => false,
      GoalPeriod.daily => progress >= 1,
      GoalPeriod.weekly => progress >= weeklyGoalTarget,
      GoalPeriod.monthly => progress >= monthlyGoalTarget,
    };
  }

  Habit copyWith({
    String? name,
    String? description,
    int? colorValue,
    String? icon,
    HabitType? type,
    TrackingMode? trackingMode,
    double? target,
    String? unit,
    TapAction? tapAction,
    GoalPeriod? goalPeriod,
    int? weeklyGoalTarget,
    int? monthlyGoalTarget,
    Map<String, num>? dailyCounts,
  }) => Habit(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    colorValue: colorValue ?? this.colorValue,
    icon: icon ?? this.icon,
    type: type ?? this.type,
    trackingMode: trackingMode ?? this.trackingMode,
    target: target ?? this.target,
    unit: unit ?? this.unit,
    tapAction: tapAction ?? this.tapAction,
    goalPeriod: goalPeriod ?? this.goalPeriod,
    weeklyGoalTarget: weeklyGoalTarget ?? this.weeklyGoalTarget,
    monthlyGoalTarget: monthlyGoalTarget ?? this.monthlyGoalTarget,
    dailyCounts: dailyCounts ?? this.dailyCounts,
  );

  Habit withSettings(HabitSettings settings) => copyWith(
    name: settings.name,
    description: settings.description,
    colorValue: settings.colorValue,
    icon: settings.icon,
    type: settings.type,
    trackingMode: settings.trackingMode,
    target: settings.target,
    unit: settings.unit,
    tapAction: settings.tapAction,
    goalPeriod: settings.goalPeriod,
    weeklyGoalTarget: settings.weeklyGoalTarget,
    monthlyGoalTarget: settings.monthlyGoalTarget,
  );
}

String enumValue(Enum value) => value.name;

T enumFromName<T extends Enum>(List<T> values, Object? value, T fallback) =>
    values.firstWhere((item) => item.name == value, orElse: () => fallback);

String dayKey(DateTime day) {
  final localDay = DateTime(day.year, day.month, day.day);
  final year = localDay.year.toString().padLeft(4, '0');
  final month = localDay.month.toString().padLeft(2, '0');
  final date = localDay.day.toString().padLeft(2, '0');
  return '$year-$month-$date';
}
