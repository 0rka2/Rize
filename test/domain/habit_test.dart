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
  });
}
