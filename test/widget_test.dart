import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rize/data/habit_repository.dart';
import 'package:rize/domain/habit.dart';
import 'package:rize/presentation/habit_heatmap.dart';
import 'package:rize/presentation/habit_detail_screen.dart';
import 'package:rize/presentation/home_screen.dart';
import 'package:rize/theme/app_colors.dart';

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
  testWidgets('heatmap month labels use three-letter abbreviations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: HabitHeatmap(
              habit: const Habit(id: 'read', name: 'Read'),
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 3, 31),
              selectedDay: DateTime(2026, 3, 31),
              noteDays: const {},
              onSelectDay: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Feb'), findsOneWidget);
    expect(find.text('Mar'), findsOneWidget);
  });

  testWidgets('scrollable heatmap opens at recent dates and keeps taps', (
    tester,
  ) async {
    final today = DateTime.now();
    DateTime? selectedDay;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: HabitHeatmap(
              habit: const Habit(id: 'read', name: 'Read'),
              startDate: DateTime(today.year - 2, today.month, today.day),
              endDate: today,
              selectedDay: today,
              onSelectDay: (day) => selectedDay = day,
              scrollable: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(
      scrollable.controller!.offset,
      scrollable.controller!.position.maxScrollExtent,
    );

    final todayCell = find.byKey(ValueKey('habit-heatmap-${dayKey(today)}'));
    await tester.tap(todayCell);
    expect(dayKey(selectedDay!), dayKey(today));

    await tester.drag(find.byType(HabitHeatmap), const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(
      scrollable.controller!.offset,
      lessThan(scrollable.controller!.position.maxScrollExtent),
    );
    expect(find.text('Mo'), findsOneWidget);
  });

  testWidgets('detail heatmap shows a rolling 12 months of history', (
    tester,
  ) async {
    final today = DateTime.now();
    final oldNoteDay = DateTime(today.year - 2, today.month, today.day);
    final oldCheckInDay = DateTime(today.year - 1, today.month, today.day);
    final repository =
        _MemoryHabitRepository()..notes[dayKey(oldNoteDay)] = 'Old note';
    final habit = Habit(
      id: 'read',
      name: 'Read',
      dailyCounts: {dayKey(oldCheckInDay): 1},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HabitDetailScreen(
          key: const ValueKey('history-detail'),
          habit: habit,
          repository: repository,
          onEdit: () async => null,
          onTrackDay: (_) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('habit-heatmap-${dayKey(oldNoteDay)}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('habit-heatmap-${dayKey(oldCheckInDay)}')),
      findsOneWidget,
    );

    final emptyRepository = _MemoryHabitRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: HabitDetailScreen(
          key: const ValueKey('empty-detail'),
          habit: const Habit(id: 'empty', name: 'Empty'),
          repository: emptyRepository,
          onEdit: () async => null,
          onTrackDay: (_) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final insideRange = today.subtract(const Duration(days: 220));
    final outsideRange = today.subtract(const Duration(days: 400));
    expect(
      find.byKey(ValueKey('habit-heatmap-${dayKey(insideRange)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('habit-heatmap-${dayKey(outsideRange)}')),
      findsNothing,
    );
  });

  testWidgets('home habit cards show an unlabeled 180-day heatmap', (
    tester,
  ) async {
    final today = DateTime.now();
    final habit = Habit(
      id: 'read',
      name: 'Read',
      colorValue: 0xFF4CAF50,
      target: 3,
      dailyCounts: {
        dayKey(today.subtract(const Duration(days: 1))): 3,
        dayKey(today.subtract(const Duration(days: 2))): 1,
      },
    );
    final repository = _MemoryHabitRepository()..habits = [habit];

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final cellFinder = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return widget is Container &&
          key is ValueKey<String> &&
          key.value.startsWith('habit-heatmap-');
    });
    expect(cellFinder, findsNWidgets(180));
    expect(find.text('Mo'), findsNothing);
    expect(find.text('Jan'), findsNothing);

    final completed = tester.widget<Container>(
      find.byKey(
        ValueKey(
          'habit-heatmap-${dayKey(today.subtract(const Duration(days: 1)))}',
        ),
      ),
    );
    final partial = tester.widget<Container>(
      find.byKey(
        ValueKey(
          'habit-heatmap-${dayKey(today.subtract(const Duration(days: 2)))}',
        ),
      ),
    );
    final inactive = tester.widget<Container>(
      find.byKey(
        ValueKey(
          'habit-heatmap-${dayKey(today.subtract(const Duration(days: 3)))}',
        ),
      ),
    );
    expect(
      (completed.decoration! as BoxDecoration).color,
      const Color(0xFF4CAF50),
    );
    expect(
      (partial.decoration! as BoxDecoration).color,
      const Color(0xFF4CAF50).withValues(alpha: 0.48),
    );
    expect((inactive.decoration! as BoxDecoration).color, AppColors.carbon);
  });

  testWidgets('home heatmaps distinguish quit-habit slip days', (tester) async {
    final today = DateTime.now();
    final slipDay = today.subtract(const Duration(days: 1));
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            Habit(
              id: 'quit-soda',
              name: 'Quit soda',
              type: HabitType.quit,
              dailyCounts: {dayKey(slipDay): 1},
            ),
          ];

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final slip = tester.widget<Container>(
      find.byKey(ValueKey('habit-heatmap-${dayKey(slipDay)}')),
    );
    final slipFreeDay = tester.widget<Container>(
      find.byKey(
        ValueKey(
          'habit-heatmap-${dayKey(today.subtract(const Duration(days: 2)))}',
        ),
      ),
    );
    expect((slip.decoration! as BoxDecoration).color, AppColors.burntOrange);
    expect(
      (slipFreeDay.decoration! as BoxDecoration).color,
      AppColors.successGreen,
    );
  });

  testWidgets('add-one tap tracks to the goal, then opens the editor', (
    tester,
  ) async {
    final repository =
        _MemoryHabitRepository()
          ..habits = [const Habit(id: 'read', name: 'Read', target: 2)];
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Track today'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 1);
    expect(find.byKey(const Key('tracking-count')), findsNothing);

    await tester.tap(find.byTooltip('Track today'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 2);
    expect(find.byKey(const Key('tracking-count')), findsNothing);

    await tester.tap(find.byTooltip('Track today'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking-count')), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 2);
  });

  testWidgets('calendar taps add one until the goal, then open the editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final repository =
        _MemoryHabitRepository()
          ..habits = [const Habit(id: 'read', name: 'Read', target: 2)];
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    final dayCell = find.byKey(ValueKey('calendar-day-${dayKey(day)}'));
    await tester.scrollUntilVisible(
      dayCell,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(dayCell);
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(day), 1);
    expect(find.byKey(const Key('tracking-count')), findsNothing);

    await tester.tap(dayCell);
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(day), 2);
    expect(find.byKey(const Key('tracking-count')), findsNothing);

    await tester.tap(dayCell);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking-count')), findsOneWidget);
  });

  testWidgets('long-pressing a calendar day opens its note editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day - 1);
    final repository =
        _MemoryHabitRepository()
          ..habits = [const Habit(id: 'read', name: 'Read')];
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    final dayCell = find.byKey(ValueKey('calendar-day-${dayKey(day)}'));
    await tester.scrollUntilVisible(
      dayCell,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.longPress(dayCell);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Note for yesterday');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.notes[dayKey(day)], 'Note for yesterday');
  });

  testWidgets('tracking editor prompts before discarding unsaved changes', (
    tester,
  ) async {
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            const Habit(
              id: 'walk',
              name: 'Walk',
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
    await tester.enterText(find.byKey(const Key('tracking-count')), '2');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Save your changes?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking-count')), findsOneWidget);

    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();
    expect(find.text('Save your changes?'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 2);

    await tester.tap(find.byTooltip('Track today'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tracking-count')), '3');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 2);
  });

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
      expect(find.byKey(const Key('tracking-count')), findsNothing);

      await tester.tap(find.byTooltip('Track today'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tracking-save')));
      await tester.pumpAndSettle();
      expect(repository.habits.single.countOn(DateTime.now()), 1);

      await tester.tap(find.text('Drink water'));
      await tester.pumpAndSettle();
      expect(find.text('Stay hydrated'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Mo'), findsOneWidget);
      expect(find.byTooltip('Previous month'), findsOneWidget);

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
      scrollable: find.byType(Scrollable).first,
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

  testWidgets('the card corner toggles a quit habit slip directly', (
    tester,
  ) async {
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

    await tester.tap(find.byTooltip('Clear today’s slip'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 0);
    expect(repository.habits.single.isCompleteOn(DateTime.now()), isTrue);
    expect(find.byKey(const Key('tracking-save')), findsNothing);
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
              tapAction: TapAction.enterTotal,
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

  testWidgets('yes-no tracking toggles immediately', (tester) async {
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
    expect(repository.habits.single.countOn(DateTime.now()), 1);

    await tester.tap(find.byTooltip('Mark incomplete'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 0);
    expect(find.byKey(const Key('tracking-save')), findsNothing);
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
