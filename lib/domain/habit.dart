enum HabitType { build, quit }

enum TrackingMode { yesNo, count, measure }

enum TapAction { addOne, enterTotal }

enum GoalPeriod { none, daily, weekly, monthly, specificDays, everyFewDays }

enum RepeatMark { free, filled }

typedef BuildRepeatOptions =
    ({
      int weekdays,
      int gapDays,
      bool countWeeks,
      bool countMonths,
      bool fillWeeks,
      bool fillMonths,
      bool fillGaps,
    });

const repeatWeekdays = 0x1f;
const repeatWeekends = 0x60;
const repeatAllDays = repeatWeekdays | repeatWeekends;
const BuildRepeatOptions defaultBuildRepeat = (
  weekdays: repeatWeekdays,
  gapDays: 5,
  countWeeks: false,
  countMonths: false,
  fillWeeks: false,
  fillMonths: false,
  fillGaps: false,
);

class HabitSettings {
  const HabitSettings({
    required this.name,
    required this.description,
    required this.colorValue,
    required this.icon,
    required this.type,
    required this.trackingMode,
    required this.target,
    this.quitLimit = 0,
    required this.unit,
    required this.tapAction,
    required this.goalPeriod,
    required this.weeklyGoalTarget,
    required this.monthlyGoalTarget,
    this.buildRepeat = defaultBuildRepeat,
  });

  final String name;
  final String description;
  final int colorValue;
  final String icon;
  final HabitType type;
  final TrackingMode trackingMode;
  final double target;
  final double quitLimit;
  final String unit;
  final TapAction tapAction;
  final GoalPeriod goalPeriod;
  final int weeklyGoalTarget;
  final int monthlyGoalTarget;
  final BuildRepeatOptions buildRepeat;
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
    this.quitLimit = 0,
    this.unit = 'times',
    this.tapAction = TapAction.addOne,
    this.goalPeriod = GoalPeriod.none,
    this.weeklyGoalTarget = 1,
    this.monthlyGoalTarget = 1,
    this.buildRepeat = defaultBuildRepeat,
    this.startDate,
    this.dailyCounts = const {},
    this.noteSlipDays = const {},
  });

  final String id;
  final String name;
  final String description;
  final int colorValue;
  final String icon;
  final HabitType type;
  final TrackingMode trackingMode;
  final double target;
  final double quitLimit;
  final String unit;
  final TapAction tapAction;
  final GoalPeriod goalPeriod;
  final int weeklyGoalTarget;
  final int monthlyGoalTarget;
  final BuildRepeatOptions buildRepeat;
  final DateTime? startDate;
  final Map<String, num> dailyCounts;
  final Set<String> noteSlipDays;

  double countOn(DateTime day) => (dailyCounts[dayKey(day)] ?? 0).toDouble();

  double get dailyTrackingThreshold =>
      type == HabitType.quit ? quitLimit : target;

  bool get hasQuitLimit => trackingMode != TrackingMode.yesNo && quitLimit > 0;

  bool meetsQuitLimit(num count) =>
      hasQuitLimit ? count < quitLimit : count == 0;

  bool hasNoteSlipOn(DateTime day) => noteSlipDays.contains(dayKey(day));

  bool isQuitSlipOn(DateTime day) =>
      type == HabitType.quit &&
      (hasNoteSlipOn(day) || !meetsQuitLimit(countOn(day)));

  Habit setNoteSlip(DateTime day, bool isSlip) {
    if (type != HabitType.quit || isQuitSlipOn(day) == isSlip) return this;

    final key = dayKey(day);
    if (isSlip) return copyWith(noteSlipDays: {...noteSlipDays, key});
    if (noteSlipDays.contains(key)) {
      return copyWith(noteSlipDays: {...noteSlipDays}..remove(key));
    }
    return setCount(day, 0);
  }

  bool isSlipFreeOn(DateTime day) => countOn(day) == 0 && isCompleteOn(day);

  bool isCompleteOn(DateTime day) {
    if (type == HabitType.quit) {
      final started = startDate ?? DateTime.now();
      final startedDay = DateTime(started.year, started.month, started.day);
      final checkedDay = DateTime(day.year, day.month, day.day);
      return !isQuitSlipOn(day) &&
          (!checkedDay.isBefore(startedDay) ||
              dailyCounts.containsKey(dayKey(day)));
    }
    final count = countOn(day);
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

  Habit toggleDay(DateTime day) =>
      hasNoteSlipOn(day)
          ? setNoteSlip(day, false)
          : setCount(day, countOn(day) > 0 ? 0 : 1);

  Habit setCount(DateTime day, double count) {
    final updatedCounts = {
      for (final entry in dailyCounts.entries)
        entry.key: entry.value.toDouble(),
    };
    final key = dayKey(day);
    if (count <= 0) {
      if (type == HabitType.quit) {
        updatedCounts[key] = 0;
      } else {
        updatedCounts.remove(key);
      }
    } else {
      updatedCounts[key] = count;
    }
    return copyWith(
      dailyCounts: updatedCounts,
      noteSlipDays:
          noteSlipDays.contains(key) ? ({...noteSlipDays}..remove(key)) : null,
    );
  }

  int currentStreak(DateTime today) {
    if (type == HabitType.build) {
      switch (goalPeriod) {
        case GoalPeriod.specificDays:
          return _scheduledStreak(today);
        case GoalPeriod.everyFewDays:
          return _rollingStreak(today);
        case GoalPeriod.weekly:
        case GoalPeriod.monthly:
          final streak = quotaStreak(today);
          return countsPeriods ? streak.periods : streak.days;
        case GoalPeriod.none:
        case GoalPeriod.daily:
          break;
      }
    }

    return _countConsecutiveDays(today, allowIncompleteToday: true);
  }

  int calendarDayStreak(DateTime today) => _countConsecutiveDays(
    today,
    allowIncompleteToday: type == HabitType.build,
  );

  int _countConsecutiveDays(
    DateTime today, {
    required bool allowIncompleteToday,
  }) {
    var day = shiftHabitDay(today, 0);
    if (allowIncompleteToday && !isCompleteOn(day)) {
      day = shiftHabitDay(day, -1);
    }

    var streak = 0;
    while (isCompleteOn(day)) {
      streak++;
      day = shiftHabitDay(day, -1);
    }
    return streak;
  }

  int successfulDaysInPeriod(
    DateTime date,
    GoalPeriod period, {
    DateTime? today,
  }) {
    if (period == GoalPeriod.none) return 0;

    final lastEligibleDay = shiftHabitDay(today ?? DateTime.now(), 0);
    final selectedDay = shiftHabitDay(date, 0);
    if (selectedDay.isAfter(lastEligibleDay)) return 0;

    if (period == GoalPeriod.specificDays && !isScheduledOn(selectedDay)) {
      return 0;
    }
    if (period != GoalPeriod.weekly && period != GoalPeriod.monthly) {
      return isCompleteOn(selectedDay) ? 1 : 0;
    }

    final firstDay = _periodStart(selectedDay, period);
    final lastDay =
        period == GoalPeriod.weekly
            ? shiftHabitDay(firstDay, 6)
            : DateTime(selectedDay.year, selectedDay.month + 1, 0);
    final endDay = lastDay.isAfter(lastEligibleDay) ? lastEligibleDay : lastDay;

    var completedDays = 0;
    for (
      var day = firstDay;
      !day.isAfter(endDay);
      day = shiftHabitDay(day, 1)
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
      GoalPeriod.specificDays || GoalPeriod.everyFewDays => progress >= 1,
    };
  }

  bool get countsPeriods => switch (goalPeriod) {
    GoalPeriod.weekly => buildRepeat.countWeeks,
    GoalPeriod.monthly => buildRepeat.countMonths,
    _ => false,
  };

  bool isScheduledOn(DateTime day) =>
      (buildRepeat.weekdays & (1 << (day.weekday - 1))) != 0;

  ({int days, int periods}) quotaStreak(DateTime today) {
    final weekly = goalPeriod == GoalPeriod.weekly;
    if (!weekly && goalPeriod != GoalPeriod.monthly) {
      return (days: 0, periods: 0);
    }
    final target = weekly ? weeklyGoalTarget : monthlyGoalTarget;
    final totals = _quotaTotals(_completedDates(today));
    final current = _periodStart(today, goalPeriod);
    var period = current;
    var days = 0;
    var periods = 0;
    while (true) {
      final completed = totals[period] ?? 0;
      if (completed >= target && completed > 0) {
        days += completed;
        periods++;
      } else if (period != current) {
        break;
      }
      period =
          weekly
              ? shiftHabitDay(period, -7)
              : DateTime(period.year, period.month - 1);
    }
    return (days: days, periods: periods);
  }

  DateTime? nextCheckInDue(DateTime today) {
    final completed = _completedDates(today);
    return completed.isEmpty
        ? null
        : shiftHabitDay(completed.last, buildRepeat.gapDays);
  }

  Map<String, RepeatMark> repeatMarks(
    DateTime start,
    DateTime end, {
    required DateTime today,
  }) {
    if (type != HabitType.build) return const {};
    final fillQuota = switch (goalPeriod) {
      GoalPeriod.weekly => buildRepeat.fillWeeks,
      GoalPeriod.monthly => buildRepeat.fillMonths,
      _ => false,
    };
    final rolling = goalPeriod == GoalPeriod.everyFewDays;
    final scheduled = goalPeriod == GoalPeriod.specificDays;
    if (!scheduled && !rolling && !fillQuota) return const {};

    final lastDay = shiftHabitDay(today, 0);
    final completed = _completedDates(lastDay);
    final totals =
        fillQuota ? _quotaTotals(completed) : const <DateTime, int>{};
    final quota =
        goalPeriod == GoalPeriod.weekly ? weeklyGoalTarget : monthlyGoalTarget;
    var activeSince = shiftHabitDay(startDate ?? lastDay, 0);
    if (completed.isNotEmpty && completed.first.isBefore(activeSince)) {
      activeSince = completed.first;
    }
    final first =
        start.isAfter(activeSince) ? shiftHabitDay(start, 0) : activeSince;
    final marks = <String, RepeatMark>{};
    var next = 0;
    DateTime? previous;
    for (
      var day = first;
      !day.isAfter(end) && !day.isAfter(lastDay);
      day = shiftHabitDay(day, 1)
    ) {
      while (rolling &&
          next < completed.length &&
          !completed[next].isAfter(day)) {
        previous = completed[next++];
      }
      if (countOn(day) > 0 || isCompleteOn(day)) continue;
      if (scheduled && !isScheduledOn(day)) {
        marks[dayKey(day)] = RepeatMark.free;
      } else if (rolling &&
          previous != null &&
          day.isBefore(shiftHabitDay(previous, buildRepeat.gapDays))) {
        marks[dayKey(day)] =
            buildRepeat.fillGaps ? RepeatMark.filled : RepeatMark.free;
      } else if (fillQuota &&
          (totals[_periodStart(day, goalPeriod)] ?? 0) >= quota) {
        marks[dayKey(day)] = RepeatMark.filled;
      }
    }
    return marks;
  }

  int _scheduledStreak(DateTime today) {
    var day = shiftHabitDay(today, 0);
    if (!isCompleteOn(day)) day = shiftHabitDay(day, -1);
    var streak = 0;
    // A validated schedule always contains at least one weekday.
    if (buildRepeat.weekdays & repeatAllDays == 0) return 0;
    while (true) {
      if (isScheduledOn(day)) {
        if (!isCompleteOn(day)) return streak;
        streak++;
      }
      day = shiftHabitDay(day, -1);
    }
  }

  int _rollingStreak(DateTime today) {
    final completed = _completedDates(today);
    if (completed.isEmpty ||
        shiftHabitDay(
          today,
          0,
        ).isAfter(shiftHabitDay(completed.last, buildRepeat.gapDays))) {
      return 0;
    }
    var streak = 1;
    for (var i = completed.length - 1; i > 0; i--) {
      if (completed[i].isAfter(
        shiftHabitDay(completed[i - 1], buildRepeat.gapDays),
      )) {
        break;
      }
      streak++;
    }
    return streak;
  }

  List<DateTime> _completedDates(DateTime today) {
    final lastKey = dayKey(today);
    final dates = <DateTime>[];
    for (final key in dailyCounts.keys) {
      if (key.compareTo(lastKey) > 0) continue;
      final day = DateTime.tryParse(key);
      if (day != null && isCompleteOn(day)) dates.add(day);
    }
    return dates..sort();
  }

  Map<DateTime, int> _quotaTotals(List<DateTime> completed) {
    final totals = <DateTime, int>{};
    for (final day in completed) {
      final period = _periodStart(day, goalPeriod);
      totals.update(period, (count) => count + 1, ifAbsent: () => 1);
    }
    return totals;
  }

  Habit copyWith({
    String? name,
    String? description,
    int? colorValue,
    String? icon,
    HabitType? type,
    TrackingMode? trackingMode,
    double? target,
    double? quitLimit,
    String? unit,
    TapAction? tapAction,
    GoalPeriod? goalPeriod,
    int? weeklyGoalTarget,
    int? monthlyGoalTarget,
    BuildRepeatOptions? buildRepeat,
    DateTime? startDate,
    Map<String, num>? dailyCounts,
    Set<String>? noteSlipDays,
  }) => Habit(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    colorValue: colorValue ?? this.colorValue,
    icon: icon ?? this.icon,
    type: type ?? this.type,
    trackingMode: trackingMode ?? this.trackingMode,
    target: target ?? this.target,
    quitLimit: quitLimit ?? this.quitLimit,
    unit: unit ?? this.unit,
    tapAction: tapAction ?? this.tapAction,
    goalPeriod: goalPeriod ?? this.goalPeriod,
    weeklyGoalTarget: weeklyGoalTarget ?? this.weeklyGoalTarget,
    monthlyGoalTarget: monthlyGoalTarget ?? this.monthlyGoalTarget,
    buildRepeat: buildRepeat ?? this.buildRepeat,
    startDate: startDate ?? this.startDate,
    dailyCounts: dailyCounts ?? this.dailyCounts,
    noteSlipDays: noteSlipDays ?? this.noteSlipDays,
  );

  Habit withSettings(HabitSettings settings) => copyWith(
    name: settings.name,
    description: settings.description,
    colorValue: settings.colorValue,
    icon: settings.icon,
    type: settings.type,
    noteSlipDays: settings.type == HabitType.build ? const {} : null,
    trackingMode: settings.trackingMode,
    target: settings.target,
    quitLimit: settings.quitLimit,
    unit: settings.unit,
    tapAction: settings.tapAction,
    goalPeriod: settings.goalPeriod,
    weeklyGoalTarget: settings.weeklyGoalTarget,
    monthlyGoalTarget: settings.monthlyGoalTarget,
    buildRepeat: settings.buildRepeat,
  );
}

DateTime shiftHabitDay(DateTime day, int offset) =>
    DateTime(day.year, day.month, day.day + offset);

DateTime _periodStart(DateTime day, GoalPeriod period) =>
    period == GoalPeriod.weekly
        ? shiftHabitDay(day, 1 - day.weekday)
        : DateTime(day.year, day.month);

String enumValue(Enum value) => value.name;

T enumFromName<T extends Enum>(List<T> values, Object? value, T fallback) =>
    values.firstWhere((item) => item.name == value, orElse: () => fallback);

bool canCreateHabitNoteOn(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  return !day.isAfter(today);
}

String dayKey(DateTime day) {
  final localDay = DateTime(day.year, day.month, day.day);
  final year = localDay.year.toString().padLeft(4, '0');
  final month = localDay.month.toString().padLeft(2, '0');
  final date = localDay.day.toString().padLeft(2, '0');
  return '$year-$month-$date';
}
