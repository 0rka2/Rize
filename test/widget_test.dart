import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rize/data/habit_repository.dart';
import 'package:rize/domain/habit.dart';
import 'package:rize/main.dart';
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
  testWidgets('habit form protects edits on close and system back', (
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
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Save your changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.name, 'Read');

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit habit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('habit-description')),
      'New description',
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.description, isEmpty);
  });

  testWidgets('unchanged and reverted habit forms close without prompting', (
    tester,
  ) async {
    final repository = _MemoryHabitRepository();
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    for (final changeThenRevert in [false, true]) {
      await tester.tap(find.text('Add your first habit'));
      await tester.pumpAndSettle();
      if (changeThenRevert) {
        await tester.enterText(find.byKey(const Key('habit-name')), 'Read');
        await tester.enterText(find.byKey(const Key('habit-name')), '');
      }
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Save your changes?'), findsNothing);
      expect(find.text('Add your first habit'), findsOneWidget);
    }
  });

  testWidgets(
    'habit option edits prompt and invalid saves keep the form open',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(repository: _MemoryHabitRepository())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add your first habit'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Quit a habit'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Quit a habit'));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Save your changes?'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('New Habit'), findsOneWidget);
      expect(
        find.text('Enter a name, valid goal, and measurement unit.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Add your first habit'), findsOneWidget);
    },
  );

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

  testWidgets('quit heatmaps use the habit colour and leave slip days dark', (
    tester,
  ) async {
    final today = DateTime.now();
    final slipDay = today.subtract(const Duration(days: 1));
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            Habit(
              id: 'quit-soda',
              name: 'Quit soda',
              type: HabitType.quit,
              colorValue: AppColors.burntOrange.toARGB32(),
              startDate: today,
              dailyCounts: {
                dayKey(slipDay): 1,
                dayKey(today.subtract(const Duration(days: 2))): 0,
              },
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
    expect((slip.decoration! as BoxDecoration).color, AppColors.carbon);
    expect(
      (slipFreeDay.decoration! as BoxDecoration).color,
      AppColors.burntOrange,
    );
  });

  testWidgets(
    'quit-habit calendar marks slips grey and sober days in the habit colour',
    (tester) async {
      final today = DateTime.now();
      final previousMonth = DateTime(today.year, today.month - 1);
      final slipDay = DateTime(previousMonth.year, previousMonth.month, 2);
      final soberDay = DateTime(previousMonth.year, previousMonth.month, 3);
      final habit = Habit(
        id: 'quit-soda',
        name: 'Quit soda',
        type: HabitType.quit,
        colorValue: AppColors.burntOrange.toARGB32(),
        startDate: today,
        dailyCounts: {dayKey(slipDay): 1, dayKey(soberDay): 0},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitDetailScreen(
            habit: habit,
            repository: _MemoryHabitRepository(),
            onEdit: () async => null,
            onTrackDay: (_) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      Color markerColor(DateTime day) {
        final cell = find.byKey(ValueKey('calendar-day-${dayKey(day)}'));
        final marker = tester
            .widgetList<Container>(
              find.descendant(of: cell, matching: find.byType(Container)),
            )
            .firstWhere(
              (container) =>
                  (container.decoration as BoxDecoration?)?.shape ==
                  BoxShape.circle,
            );
        return (marker.decoration! as BoxDecoration).color!;
      }

      expect(markerColor(slipDay), AppColors.coolGrey);
      expect(markerColor(soberDay), AppColors.burntOrange);
    },
  );

  testWidgets('calendar swipes keep the header fixed and navigation in sync', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateUtils.dateOnly(DateTime.now());
    final trackedDays = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HabitDetailScreen(
          habit: Habit(id: 'calendar-swipe', name: 'Read'),
          repository: _MemoryHabitRepository(),
          onEdit: () async => null,
          onTrackDay: (day) async {
            trackedDays.add(day);
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pager = find.byType(PageView);
    await tester.ensureVisible(pager);
    await tester.pumpAndSettle();
    final monthButton = find.widgetWithText(
      OutlinedButton,
      MaterialLocalizations.of(tester.element(pager)).formatMonthYear(today),
    );
    final headerPosition = tester.getTopLeft(monthButton);
    final weekdaysPosition = tester.getTopLeft(find.text('Mon'));
    final todayPosition = tester.getTopLeft(find.text('Today'));

    String monthLabel(int offset) => MaterialLocalizations.of(
      tester.element(pager),
    ).formatMonthYear(DateTime(today.year, today.month + offset));

    await tester.drag(pager, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text(monthLabel(1)), findsOneWidget);
    expect(
      tester.getTopLeft(find.widgetWithText(OutlinedButton, monthLabel(1))),
      headerPosition,
    );
    expect(tester.getTopLeft(find.text('Mon')), weekdaysPosition);
    expect(tester.getTopLeft(find.text('Today')), todayPosition);
    expect(trackedDays, isEmpty);

    await tester.drag(pager, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text(monthLabel(0)), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text(monthLabel(-1)), findsOneWidget);
    await tester.drag(pager, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text(monthLabel(0)), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text(monthLabel(1)), findsOneWidget);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text(monthLabel(0)), findsOneWidget);
    expect(trackedDays, isEmpty);

    await tester.tap(find.byKey(ValueKey('calendar-day-${dayKey(today)}')));
    await tester.pumpAndSettle();
    expect(trackedDays, [today]);

    await tester.tap(find.widgetWithText(OutlinedButton, monthLabel(0)));
    await tester.pumpAndSettle();
    expect(find.text('Choose Date'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text(monthLabel(0)), findsOneWidget);
  });

  testWidgets('confirming an earlier quit date updates the start date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateUtils.dateOnly(DateTime.now());
    final earlierDay = today.subtract(const Duration(days: 1));
    final habit = Habit(
      id: 'quit-soda',
      name: 'Quit soda',
      type: HabitType.quit,
      startDate: today,
    );
    DateTime? savedStartDate;

    await tester.pumpWidget(
      MaterialApp(
        home: HabitDetailScreen(
          habit: habit,
          repository: _MemoryHabitRepository(),
          onEdit: () async => null,
          onTrackDay: (_) async => null,
          onSetStartDate: (day) async {
            savedStartDate = day;
            return habit.copyWith(startDate: day);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dayCell = find.byKey(ValueKey('calendar-day-${dayKey(earlierDay)}'));
    await tester.scrollUntilVisible(
      dayCell,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(dayCell);
    await tester.pumpAndSettle();

    expect(find.text('Start tracking earlier?'), findsOneWidget);
    expect(savedStartDate, isNull);
    await tester.tap(find.textContaining('Start from '));
    await tester.pumpAndSettle();

    expect(savedStartDate, earlierDay);
  });

  testWidgets('canceling an earlier quit date leaves it unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateUtils.dateOnly(DateTime.now());
    final earlierDay = today.subtract(const Duration(days: 1));
    final habit = Habit(
      id: 'quit-soda',
      name: 'Quit soda',
      type: HabitType.quit,
      startDate: today,
    );
    var startDateWasSaved = false;
    var trackingWasCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HabitDetailScreen(
          habit: habit,
          repository: _MemoryHabitRepository(),
          onEdit: () async => null,
          onTrackDay: (_) async {
            trackingWasCalled = true;
            return null;
          },
          onSetStartDate: (_) async {
            startDateWasSaved = true;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dayCell = find.byKey(ValueKey('calendar-day-${dayKey(earlierDay)}'));
    await tester.scrollUntilVisible(
      dayCell,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(dayCell);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(startDateWasSaved, isFalse);
    expect(trackingWasCalled, isFalse);
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
    await tester.tap(find.byTooltip('Close note editor'));
    await tester.pumpAndSettle();
    expect(find.text('Save your changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Note for yesterday'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
    );
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

    await tester.fling(
      find.byKey(const Key('tracking-drag-handle')),
      const Offset(0, 180),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Save your changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

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

      final addNote = find.byTooltip('Add note');
      await tester.scrollUntilVisible(
        addNote,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('No notes yet'), findsOneWidget);
      await tester.tap(addNote);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Today')),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'A note for another day');
      await tester.tap(find.byTooltip('Choose note date'));
      await tester.pumpAndSettle();
      final today = DateTime.now();
      final noteDay = DateTime(today.year, today.month, today.day - 1);
      final calendar = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(calendar.firstDate, DateTime(1900));
      expect(calendar.lastDate, DateUtils.dateOnly(today));
      if (noteDay.month != today.month) {
        await tester.tap(find.byTooltip('Previous month').hitTestable());
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('${noteDay.day}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A note for another day'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('A note for another day'), findsOneWidget);

      final notePreview = find.text('A note for another day');
      await tester.ensureVisible(notePreview);
      await tester.pumpAndSettle();
      await tester.tap(notePreview);
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'A note for another day',
      );
      await tester.enterText(find.byType(TextField), 'Edited from the preview');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Edited from the preview'), findsOneWidget);

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
      expect(repository.notes[dayKey(noteDay)], 'Edited from the preview');
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
          ..notes[dayKey(DateTime(today.year, today.month, today.day - 3))] =
              'Three days ago'
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

    final allNotes = find.text('All notes');
    await tester.ensureVisible(allNotes);
    await tester.pumpAndSettle();
    await tester.tap(allNotes);
    await tester.pumpAndSettle();
    expect(find.text('Old note'), findsOneWidget);

    await tester.tap(find.text('Today note'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
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
    await tester.tap(find.byTooltip('Choose note date'));
    await tester.pumpAndSettle();
    final addedDay = DateTime(today.year, today.month, today.day - 4);
    if (addedDay.month != today.month) {
      await tester.tap(find.byTooltip('Previous month').hitTestable());
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('${addedDay.day}'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Added on another day');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.notes[dayKey(addedDay)], 'Added on another day');

    await tester.tap(find.text('Added on another day'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
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

  testWidgets('build habit repeat settings work on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryHabitRepository();
    await tester.pumpWidget(RizeApp(repository: repository));
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      if (finder.hitTestable().evaluate().isEmpty) {
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            180,
            scrollable: find.byType(Scrollable).last,
          );
        } else {
          await tester.ensureVisible(finder);
        }
        await tester.pump();
      }
      expect(finder.hitTestable(), findsOneWidget);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> openRepeat() async {
      final selector = find.byKey(const Key('streak-goal-selector'));
      await tester.scrollUntilVisible(
        selector,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(selector);
    }

    Future<void> pick(String label) async {
      final option = find.text(label);
      if (option.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          option,
          -180,
          scrollable: find.byType(Scrollable).last,
        );
      }
      await tap(option);
    }

    Finder stepperButton(String tooltip) => find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == tooltip,
      description: 'IconButton with tooltip "$tooltip"',
    );

    final increaseWeek = stepperButton('Increase week target');
    final decreaseWeek = stepperButton('Decrease week target');
    final increaseMonth = stepperButton('Increase month target');
    final decreaseMonth = stepperButton('Decrease month target');
    const habitColor = Color(0xFF3F51E5);
    final selectionMark = find.byIcon(Icons.check_circle);
    final specificDays = find.widgetWithText(ListTile, 'On specific days');

    Future<void> verifySpecificDaysLabel(String label) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: specificDays, matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tap(find.text('Add your first habit'));
    await tester.enterText(find.byKey(const Key('habit-name')), 'Read');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == habitColor,
      ),
    );
    await openRepeat();
    expect(find.text('Goal & Streak'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'No repeat goal'), findsOneWidget);

    await tap(find.text('Every day'));
    expect(tester.widget<Icon>(selectionMark).color, habitColor);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Every day'))
          .selected,
      isTrue,
    );
    await tap(find.text('On specific days'));
    final monday = stepperButton('Monday');
    final sunday = stepperButton('Sunday');
    expect(
      tester.widget<IconButton>(monday).style?.backgroundColor?.resolve({}),
      habitColor,
    );
    expect(tester.getCenter(monday).dy, tester.getCenter(sunday).dy);
    expect(tester.getSize(sunday).shortestSide, greaterThanOrEqualTo(44));
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Weekdays'))
          .selected,
      isTrue,
    );
    await verifySpecificDaysLabel('Mon–Fri');
    await tap(specificDays);
    await tap(find.text('Every day'));
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Every day'))
          .selected,
      isTrue,
    );
    await verifySpecificDaysLabel('Every day');
    await tap(specificDays);
    await tap(find.text('Weekends'));
    await tap(stepperButton('Saturday'));
    expect(
      tester.widget<IconButton>(stepperButton('Sunday')).onPressed,
      isNull,
    );
    await tap(monday);
    await verifySpecificDaysLabel('Mon, Sun');
    await tap(specificDays);
    await tap(find.text('Weekends'));
    await verifySpecificDaysLabel('Sat, Sun');
    expect(tester.widget<ListTile>(specificDays).selected, isTrue);
    await tap(find.byTooltip('Back').last);
    expect(find.text('Sat, Sun'), findsOneWidget);
    await openRepeat();

    await tap(find.text('Times a week'));
    expect(tester.widget<IconButton>(decreaseWeek).onPressed, isNull);
    for (var target = 1; target < 7; target++) {
      await tap(increaseWeek);
    }
    expect(tester.widget<IconButton>(increaseWeek).onPressed, isNull);
    await tap(find.text('Weeks'));
    await tap(find.byType(Switch));

    await pick('Times a month');
    expect(tester.widget<IconButton>(decreaseMonth).onPressed, isNull);
    expect(
      tester.getSize(increaseMonth).shortestSide,
      greaterThanOrEqualTo(48),
    );
    for (var target = 1; target < 31; target++) {
      await tap(increaseMonth);
    }
    expect(tester.widget<IconButton>(increaseMonth).onPressed, isNull);
    expect(find.text('31 / month'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await pick('Every few days');
    expect(find.text('Every 5 days'), findsOneWidget);
    final decreaseGap = stepperButton('Decrease interval target');
    await tap(decreaseGap);
    await tap(decreaseGap);
    await tap(decreaseGap);
    expect(tester.widget<IconButton>(decreaseGap).onPressed, isNull);
    final increaseGap = stepperButton('Increase interval target');
    for (var target = 2; target < 31; target++) {
      await tap(increaseGap);
    }
    expect(tester.widget<IconButton>(increaseGap).onPressed, isNull);
    await tap(find.byType(Switch));

    await pick('Times a week');
    expect(find.text('7 / week'), findsOneWidget);
    await tap(decreaseWeek);
    await pick('Times a month');
    expect(find.text('31 / month'), findsOneWidget);
    await tap(find.byTooltip('Back').last);
    expect(find.text('Save your changes?'), findsNothing);
    expect(find.text('31 days / month'), findsOneWidget);
    expect(repository.habits, isEmpty);
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    await tap(find.text('Save habit'));

    final saved = repository.habits.single;
    expect(saved.goalPeriod, GoalPeriod.monthly);
    expect(saved.weeklyGoalTarget, 6);
    expect(saved.monthlyGoalTarget, 31);
    expect(saved.buildRepeat.weekdays, repeatWeekends);
    expect(saved.buildRepeat.gapDays, 31);
    expect(saved.buildRepeat.countWeeks, isTrue);
    expect(saved.buildRepeat.countMonths, isFalse);
    expect(saved.buildRepeat.fillWeeks, isTrue);
    expect(saved.buildRepeat.fillMonths, isFalse);
    expect(saved.buildRepeat.fillGaps, isTrue);

    await tap(find.text('Read'));
    await tap(find.byTooltip('Edit habit'));
    await openRepeat();
    expect(find.text('31 / month'), findsOneWidget);
    await tap(decreaseMonth);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Save your changes?'), findsNothing);
    expect(find.text('30 days / month'), findsOneWidget);

    await openRepeat();
    expect(find.text('30 / month'), findsOneWidget);
    await tap(find.text('No repeat goal'));
    await tap(find.byTooltip('Back').last);
    expect(find.text('Save your changes?'), findsNothing);
    await tap(find.text('Save changes'));
    expect(repository.habits.single.goalPeriod, GoalPeriod.none);
    expect(repository.habits.single.monthlyGoalTarget, 30);
    expect(repository.habits.single.buildRepeat, saved.buildRepeat);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'repeat fill appears in both calendars and allows a real check-in',
    (tester) async {
      tester.view.physicalSize = const Size(450, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateUtils.dateOnly(DateTime.now());
      final start = shiftHabitDay(today, -2);
      final habit = Habit(
        id: 'stretch',
        name: 'Stretch',
        trackingMode: TrackingMode.yesNo,
        goalPeriod: GoalPeriod.everyFewDays,
        startDate: start,
        buildRepeat: (
          weekdays: repeatWeekdays,
          gapDays: 5,
          countWeeks: false,
          countMonths: false,
          fillWeeks: false,
          fillMonths: false,
          fillGaps: true,
        ),
        dailyCounts: {dayKey(start): 1},
      );
      final repository =
          _MemoryHabitRepository()
            ..habits = [habit]
            ..notes[dayKey(today)] = 'A note for the free day';
      await tester.pumpWidget(RizeApp(repository: repository));
      await tester.pumpAndSettle();

      final color = Color(habit.colorValue);
      final heatmapDay = find.byKey(ValueKey('habit-heatmap-${dayKey(today)}'));
      BoxDecoration heatmapDecoration() =>
          tester.widget<Container>(heatmapDay).decoration! as BoxDecoration;
      expect(heatmapDecoration().color, color.withValues(alpha: 0.18));
      expect(repository.habits.single.dailyCounts, hasLength(1));

      await tester.tap(find.text('Stretch'));
      await tester.pumpAndSettle();
      expect(find.text('1 check-in'), findsOneWidget);
      expect(heatmapDecoration().color, color.withValues(alpha: 0.18));
      final calendarDay = find.byKey(ValueKey('calendar-day-${dayKey(today)}'));
      final children = find.descendant(
        of: calendarDay,
        matching: find.byType(Container),
      );
      expect(
        tester.widgetList<Container>(children).map((cell) => cell.decoration),
        contains(const BoxDecoration(color: AppColors.burntOrange)),
      );
      expect(
        find.descendant(
          of: calendarDay,
          matching: find.byIcon(Icons.notes_rounded),
        ),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mark complete'));
      await tester.pumpAndSettle();
      expect(heatmapDecoration().color, color);
      expect(repository.habits.single.dailyCounts, hasLength(2));
      await tester.tap(find.text('Stretch'));
      await tester.pumpAndSettle();
      expect(find.text('2 check-ins'), findsOneWidget);
    },
  );

  testWidgets('quit habits still open the streak goal dialog', (tester) async {
    final repository = _MemoryHabitRepository();
    await tester.pumpWidget(RizeApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your first habit'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Quit a habit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Quit a habit'));
    await tester.pumpAndSettle();

    final selector = find.byKey(const Key('streak-goal-selector'));
    await tester.scrollUntilVisible(
      selector,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();

    final dialog = find.widgetWithText(AlertDialog, 'Streak Goal');
    expect(dialog, findsOneWidget);
    expect(find.text('Repeat'), findsNothing);
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('Weekly')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('period-goal-value')), findsOneWidget);
  });
}
