import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rize/data/habit_repository.dart';
import 'package:rize/domain/habit.dart';
import 'package:rize/presentation/home_screen.dart';

class _MemoryHabitRepository extends HabitRepository {
  List<Habit> habits = [];
  final Map<String, String> notes = {};

  @override
  Future<List<Habit>> loadHabits() async => habits;

  @override
  Future<void> saveHabits(List<Habit> habits) async {
    this.habits = habits;
  }

  @override
  Future<Map<String, String>> loadNotes(String habitId) async => notes;

  @override
  Future<void> saveNote(String habitId, DateTime day, String content) async {
    final key = dayKey(day);
    if (content.isEmpty) {
      notes.remove(key);
    } else {
      notes[key] = content;
    }
  }
}

void main() {
  testWidgets(
    'creates, tracks, opens details, adds a note, and edits a habit',
    (tester) async {
      final repository = _MemoryHabitRepository();
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add your first habit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('habit-name')),
        'Drink water',
      );
      await tester.enterText(
        find.byKey(const Key('habit-description')),
        'Stay hydrated',
      );
      await tester.tap(find.text('Save habit'));
      await tester.pumpAndSettle();

      expect(repository.habits.single.name, 'Drink water');
      expect(repository.habits.single.description, 'Stay hydrated');
      expect(repository.habits.single.target, 1);
      expect(repository.habits.single.unit, 'times');

      await tester.tap(find.byTooltip('Track today'));
      await tester.pumpAndSettle();
      expect(repository.habits.single.countOn(DateTime.now()), 1);

      await tester.tap(find.text('Drink water'));
      await tester.pumpAndSettle();
      expect(find.text('Stay hydrated'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A note for today');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('A note for today'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit habit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('habit-name')),
        'Drink more water',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repository.habits.single.name, 'Drink more water');
      expect(repository.habits.single.countOn(DateTime.now()), 1);
      expect(repository.notes.values.single, 'A note for today');
    },
  );

  testWidgets('the card corner records a quit habit slip', (tester) async {
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            const Habit(
              id: 'quit-soda',
              name: 'Quit soda',
              type: HabitType.quit,
              trackingMode: TrackingMode.yesNo,
            ),
          ];
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(repository.habits.single.isCompleteOn(DateTime.now()), isTrue);
    await tester.tap(find.byTooltip('Record a slip'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 1);
    expect(repository.habits.single.isCompleteOn(DateTime.now()), isFalse);
  });

  testWidgets('enter-total tracking saves fractional measured amounts', (
    tester,
  ) async {
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            const Habit(
              id: 'walk',
              name: 'Walk',
              unit: 'km',
              target: 5,
              trackingMode: TrackingMode.measure,
              tapAction: TapAction.enterTotal,
            ),
          ];
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Track today'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '7.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.habits.single.countOn(DateTime.now()), 7.5);
    expect(repository.habits.single.isCompleteOn(DateTime.now()), isTrue);
  });

  testWidgets('streak period selection retains weekly and monthly targets', (
    tester,
  ) async {
    final repository = _MemoryHabitRepository();
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add your first habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habit-name')), 'Read');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.scrollUntilVisible(
      find.byKey(const Key('streak-goal-selector')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('streak-goal-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('period-goal-value')), '8');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const Key('period-goal-value')), '5');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('streak-goal-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('period-goal-value')), '32');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const Key('period-goal-value')), '31');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('streak-goal-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('period-goal-value')))
          .controller!
          .text,
      '5',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('31 days / month'), findsOneWidget);

    await tester.tap(find.byKey(const Key('streak-goal-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Daily'), findsOneWidget);

    await tester.tap(find.byKey(const Key('streak-goal-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save habit'));
    await tester.pumpAndSettle();

    final saved = repository.habits.single;
    expect(saved.goalPeriod, GoalPeriod.none);
    expect(saved.weeklyGoalTarget, 5);
    expect(saved.monthlyGoalTarget, 31);
  });
}
