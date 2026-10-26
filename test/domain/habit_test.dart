import 'package:flutter_test/flutter_test.dart';
import 'package:rize/domain/habit.dart';

void main() {
  group('Habit', () {
    test('toggleCompletion adds and removes a local day check-in', () {
      final habit = Habit(
        id: 'walk',
        name: 'Take a walk',
        completedDays: const {},
      );
      final today = DateTime(2026, 10, 26);

      final completed = habit.toggleCompletion(today);
      final undone = completed.toggleCompletion(today);

      expect(completed.isCompleteOn(today), isTrue);
      expect(undone.isCompleteOn(today), isFalse);
    });

    test('currentStreak counts consecutive completed days through today', () {
      final today = DateTime(2026, 10, 26);
      final habit = Habit(
        id: 'walk',
        name: 'Take a walk',
        completedDays: {
          dayKey(today),
          dayKey(today.subtract(const Duration(days: 1))),
          dayKey(today.subtract(const Duration(days: 2))),
        },
      );

      expect(habit.currentStreak(today), 3);
    });

    test('a missed day breaks the current streak', () {
      final today = DateTime(2026, 10, 26);
      final habit = Habit(
        id: 'walk',
        name: 'Take a walk',
        completedDays: {
          dayKey(today.subtract(const Duration(days: 2))),
        },
      );

      expect(habit.currentStreak(today), 0);
    });

    test('current streak includes yesterday while today is still open', () {
      final today = DateTime(2026, 10, 26);
      final habit = Habit(
        id: 'walk',
        name: 'Take a walk',
        completedDays: {
          dayKey(today.subtract(const Duration(days: 1))),
        },
      );

      expect(habit.currentStreak(today), 1);
    });
  });
}
