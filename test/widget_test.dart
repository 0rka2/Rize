import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rize/data/habit_repository.dart';
import 'package:rize/domain/habit.dart';
import 'package:rize/presentation/home_screen.dart';

class _MemoryHabitRepository extends HabitRepository {
  List<Habit> habits = [];
  final Map<String, String> notes = {};
  bool failSavingNotes = false;

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
    if (failSavingNotes) throw StateError('Unable to save note');
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
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.text('+1'));
      await tester.tap(find.byKey(const Key('tracking-save')));
      await tester.pumpAndSettle();
      expect(repository.habits.single.countOn(DateTime.now()), 1);

      await tester.tap(find.text('Drink water'));
      await tester.pumpAndSettle();
      expect(find.text('Stay hydrated'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add note for selected day'));
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

  testWidgets('notes preview, list, add, edit, delete, and stay in sync', (
    tester,
  ) async {
    final today = DateTime.now();
    final repository =
        _MemoryHabitRepository()
          ..habits = [const Habit(id: 'read', name: 'Read')]
          ..notes[dayKey(today)] = 'Today note'
          ..notes[dayKey(today.subtract(const Duration(days: 1)))] =
              'Yesterday note'
          ..notes[dayKey(today.subtract(const Duration(days: 2)))] =
              'Two days ago'
          ..notes[dayKey(today.subtract(const Duration(days: 5)))] = 'Old note';

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('notes-count')),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(tester.widget<Text>(find.byKey(const Key('notes-count'))).data, '4');
    expect(find.text('Today note'), findsOneWidget);
    expect(find.text('Two days ago'), findsOneWidget);
    expect(find.text('Old note'), findsNothing);

    await tester.tap(find.text('All notes'));
    await tester.pumpAndSettle();
    expect(find.text('Old note'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit note').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated today');
    repository.failSavingNotes = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your note could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Updated today'), findsOneWidget);

    repository.failSavingNotes = false;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.notes[dayKey(today)], 'Updated today');

    await tester.tap(find.byTooltip('Add note for a date'));
    await tester.pumpAndSettle();
    final addedDay = today.subtract(const Duration(days: 3));
    await tester.tap(find.text('${addedDay.day}'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Added on another day');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.notes[dayKey(addedDay)], 'Added on another day');

    await tester.tap(find.byTooltip('Edit note').at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.notes.containsKey(dayKey(addedDay)), isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('notes-count'))).data, '4');
    expect(find.text('Updated today'), findsOneWidget);
    expect(find.text('Added on another day'), findsNothing);
  });

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
    await tester.tap(find.text('Slip recorded'));
    await tester.tap(find.byKey(const Key('tracking-save')));
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
    await tester.enterText(find.byKey(const Key('tracking-count')), '7.5');
    await tester.tap(find.byKey(const Key('tracking-save')));
    await tester.pumpAndSettle();

    expect(repository.habits.single.countOn(DateTime.now()), 7.5);
    expect(repository.habits.single.isCompleteOn(DateTime.now()), isTrue);
  });

  testWidgets('tracking sheet quick actions save the selected count', (
    tester,
  ) async {
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            const Habit(
              id: 'read',
              name: 'Read',
              target: 3,
              unit: 'pages',
              dailyCounts: {},
            ).copyWith(dailyCounts: {dayKey(DateTime.now()): 1}),
          ];
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Track today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+5'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('tracking-count')))
          .controller!
          .text,
      '6',
    );
    await tester.tap(find.text('Goal'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('tracking-count')))
          .controller!
          .text,
      '3',
    );
    await tester.tap(find.text('+1'));
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('tracking-count')))
          .controller!
          .text,
      '0',
    );
    await tester.tap(find.text('+5'));
    await tester.tap(find.byKey(const Key('tracking-save')));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 5);
  });

  testWidgets('yes-no tracking can be saved as done or dismissed unchanged', (
    tester,
  ) async {
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            const Habit(
              id: 'stretch',
              name: 'Stretch',
              trackingMode: TrackingMode.yesNo,
            ),
          ];
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark complete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 0);

    await tester.tap(find.byTooltip('Mark complete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.tap(find.byKey(const Key('tracking-save')));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 1);
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
