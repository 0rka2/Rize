import 'package:flutter_test/flutter_test.dart';
import 'package:rize/domain/habit.dart';

void main() {
  group('Habit', () {
    test('count changes stay between zero and the daily target', () {
      final habit = Habit(id: 'walk', name: 'Take a walk', target: 2);
      final today = DateTime(2026, 10, 26);

      final once = habit.addCount(today);
      final complete = once.addCount(today);
      final capped = complete.addCount(today);
      final undone = capped
          .removeCount(today)
          .removeCount(today)
          .removeCount(today);

      expect(once.countOn(today), 1);
      expect(once.isCompleteOn(today), isFalse);
      expect(complete.isCompleteOn(today), isTrue);
      expect(capped.countOn(today), 2);
      expect(undone.isCompleteOn(today), isFalse);
      expect(undone.countOn(today), 0);
    });

    test('current streak counts consecutive days that reached the target', () {
      final today = DateTime(2026, 10, 26);
      final habit = Habit(
        id: 'walk',
        name: 'Take a walk',
        target: 2,
        dailyCounts: {
          dayKey(today): 2,
          dayKey(today.subtract(const Duration(days: 1))): 2,
          dayKey(today.subtract(const Duration(days: 2))): 2,
        },
      );

      expect(habit.currentStreak(today), 3);
    });

    test('a missed day breaks the current streak', () {
      final today = DateTime(2026, 10, 26);
      final habit = Habit(
        id: 'walk',
        name: 'Take a walk',
        dailyCounts: {dayKey(today.subtract(const Duration(days: 2))): 1},
      );

      expect(habit.currentStreak(today), 0);
    });

    test('current streak includes yesterday while today is still open', () {
      final today = DateTime(2026, 10, 26);
      final habit = Habit(
        id: 'walk',
        name: 'Take a walk',
        dailyCounts: {dayKey(today.subtract(const Duration(days: 1))): 1},
      );

      expect(habit.currentStreak(today), 1);
    });

    test(
      'partial progress does not complete a day or count toward streaks',
      () {
        final today = DateTime(2026, 10, 26);
        final habit = Habit(
          id: 'water',
          name: 'Drink water',
          target: 8,
          dailyCounts: {dayKey(today): 7},
        );

        expect(habit.isCompleteOn(today), isFalse);
        expect(habit.currentStreak(today), 0);
      },
    );

    test('measure tracking preserves fractional amounts', () {
      final today = DateTime(2026, 10, 27);
      final habit = Habit(
        id: 'walk',
        name: 'Walk',
        trackingMode: TrackingMode.measure,
        target: 7.5,
      ).setCount(today, 7.5);

      expect(habit.countOn(today), 7.5);
      expect(habit.isCompleteOn(today), isTrue);
    });

    test('quit habits are successful until a slip is recorded', () {
      final today = DateTime(2026, 10, 27);
      final habit = const Habit(
        id: 'soda',
        name: 'Quit soda',
        type: HabitType.quit,
        trackingMode: TrackingMode.measure,
      );

      expect(habit.isCompleteOn(today), isTrue);
      final slip = habit.setCount(today, 0.5);
      expect(slip.isCompleteOn(today), isFalse);
      expect(slip.removeCount(today).isCompleteOn(today), isTrue);
    });

    test('yes/no tracking toggles the selected day', () {
      final today = DateTime(2026, 10, 27);
      final habit = const Habit(
        id: 'read',
        name: 'Read',
        trackingMode: TrackingMode.yesNo,
      );

      final done = habit.toggleDay(today);
      expect(done.isCompleteOn(today), isTrue);
      expect(done.toggleDay(today).isCompleteOn(today), isFalse);
    });

    test('weekly and monthly goals count successful days in their periods', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final completedDays = <String, num>{
        for (
          var day = DateTime(today.year, today.month);
          !day.isAfter(today);
          day = day.add(const Duration(days: 1))
        )
          dayKey(day): 1,
      };
      final habit = Habit(
        id: 'read',
        name: 'Read',
        weeklyGoalTarget: 7,
        monthlyGoalTarget: 31,
        goalPeriod: GoalPeriod.weekly,
        dailyCounts: completedDays,
      );

      expect(
        habit.successfulDaysInPeriod(today, GoalPeriod.weekly),
        today.weekday,
      );
      expect(habit.periodGoalReached(today), today.weekday == 7);
      expect(
        habit.successfulDaysInPeriod(today, GoalPeriod.monthly),
        today.day,
      );
      expect(monday.weekday, DateTime.monday);
      expect(
        habit.copyWith(goalPeriod: GoalPeriod.monthly).periodGoalReached(today),
        today.day == 31,
      );
    });

    test('daily goals count completed Build days and slip-free Quit days', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final buildHabit = const Habit(
        id: 'read',
        name: 'Read',
        goalPeriod: GoalPeriod.daily,
      ).setCount(today, 1);
      final quitHabit = const Habit(
        id: 'soda',
        name: 'Quit soda',
        type: HabitType.quit,
        goalPeriod: GoalPeriod.daily,
      ).setCount(yesterday, 1);

      expect(buildHabit.periodGoalReached(today), isTrue);
      expect(quitHabit.successfulDaysInPeriod(yesterday, GoalPeriod.daily), 0);
      expect(quitHabit.periodGoalReached(yesterday), isFalse);
      expect(
        quitHabit.setCount(yesterday, 0).periodGoalReached(yesterday),
        isTrue,
      );
    });

    test('quit period progress counts slip-free dates only', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final slipDay =
          today.weekday == 1 ? today : today.subtract(const Duration(days: 1));
      final habit = const Habit(
        id: 'soda',
        name: 'Quit soda',
        type: HabitType.quit,
        goalPeriod: GoalPeriod.weekly,
        weeklyGoalTarget: 7,
      ).setCount(slipDay, 1);

      expect(
        habit.successfulDaysInPeriod(today, GoalPeriod.weekly),
        today.weekday - 1,
      );
      expect(monday.weekday, DateTime.monday);
    });
  });
}
