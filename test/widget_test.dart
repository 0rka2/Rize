import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rize/data/habit_repository.dart';
import 'package:rize/domain/habit.dart';
import 'package:rize/domain/habit_category.dart';
import 'package:rize/main.dart';
import 'package:rize/presentation/add_habit_screen.dart';
import 'package:rize/presentation/habit_heatmap.dart';
import 'package:rize/presentation/habit_detail_screen.dart';
import 'package:rize/presentation/home_screen.dart';
import 'package:rize/presentation/recent_habits_table.dart';
import 'package:rize/presentation/today_timeline.dart';
import 'package:rize/theme/app_colors.dart';

class _MemoryHabitRepository extends HabitRepository {
  List<Habit> habits = [];
  List<HabitCategory> customCategories = [];
  final Map<String, String> notes = {};
  bool failSavingNotes = false;
  bool failSavingHabits = false;
  Duration saveDelay = Duration.zero;

  @override
  Future<List<Habit>> loadHabits() async => habits;

  @override
  Future<List<HabitCategory>> loadCustomCategories() async => customCategories;

  @override
  Future<void> saveHabits(
    List<Habit> habits, {
    List<HabitCategory>? customCategories,
  }) async {
    if (saveDelay != Duration.zero) await Future<void>.delayed(saveDelay);
    if (failSavingHabits) throw StateError('Unable to save habits');
    this.habits = habits;
    if (customCategories != null) this.customCategories = customCategories;
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

Finder _timelineDate(DateTime day) =>
    find.byKey(ValueKey('today-date-${dayKey(day)}'));

Finder _viewMenuItem(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem),
);

double? _timelineProgress(WidgetTester tester, DateTime day) =>
    tester
        .widget<CircularProgressIndicator>(
          find.descendant(
            of: _timelineDate(day),
            matching: find.byType(CircularProgressIndicator),
          ),
        )
        .value;

Future<void> _selectEarlierTimelineDate(
  WidgetTester tester,
  DateTime day,
) async {
  final date = _timelineDate(day).hitTestable();
  for (var swipes = 0; swipes < 4 && date.evaluate().isEmpty; swipes++) {
    await tester.drag(
      find.byKey(const Key('today-week-timeline')),
      const Offset(650, 0),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(date);
  await tester.pumpAndSettle();
}

Future<void> _openHabitCategories(WidgetTester tester) async {
  final row = find.byKey(const Key('habit-categories'));
  await tester.scrollUntilVisible(
    row,
    250,
    scrollable: find.descendant(
      of: find.byType(AddHabitScreen),
      matching: find.byType(Scrollable),
    ).first,
  );
  await _tapCategoryControl(tester, row);
}

Future<void> _tapCategoryControl(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _setCategoryTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'habit editor saves multiple presets and clears them from details',
    (tester) async {
      _setCategoryTestViewport(tester);
      final repository = _MemoryHabitRepository();
      await tester.pumpWidget(RizeApp(repository: repository));
      await tester.pumpAndSettle();
      await _tapCategoryControl(tester, find.text('Add your first habit'));
      await tester.enterText(find.byKey(const Key('habit-name')), 'Run');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _openHabitCategories(tester);
      await _tapCategoryControl(tester, find.text('Fitness'));
      await _tapCategoryControl(tester, find.text('Morning'));
      await _tapCategoryControl(tester, find.text('Save'));
      expect(find.text('Fitness, Morning'), findsOneWidget);
      await _tapCategoryControl(tester, find.text('Save habit'));
      expect(repository.habits.single.categories.map((item) => item.id), [
        'fitness',
        'morning',
      ]);

      await _tapCategoryControl(tester, find.text('Run'));
      expect(find.widgetWithText(Chip, 'Fitness'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Morning'), findsOneWidget);
      await _tapCategoryControl(tester, find.byTooltip('Edit habit'));
      await _openHabitCategories(tester);
      await _tapCategoryControl(tester, find.text('Fitness'));
      await _tapCategoryControl(tester, find.text('Morning'));
      await _tapCategoryControl(tester, find.text('Save'));
      expect(find.text('None'), findsOneWidget);
      await _tapCategoryControl(tester, find.text('Save changes'));
      expect(repository.habits.single.categories, isEmpty);
      expect(find.widgetWithText(Chip, 'Fitness'), findsNothing);
      expect(find.widgetWithText(Chip, 'Morning'), findsNothing);
    },
  );

  testWidgets(
    'custom category drafts can be discarded and retried after a failed save',
    (tester) async {
      _setCategoryTestViewport(tester);
      final repository =
          _MemoryHabitRepository()
            ..habits = [const Habit(id: 'read', name: 'Read')];
      await tester.pumpWidget(RizeApp(repository: repository));
      await tester.pumpAndSettle();
      await _tapCategoryControl(tester, find.text('Read'));
      final name = find.byKey(const Key('category-name'));

      Future<void> draftCategory() async {
        await _tapCategoryControl(tester, find.byTooltip('Edit habit'));
        await _openHabitCategories(tester);
        await _tapCategoryControl(tester, find.text('Create your own'));
        final save = find.widgetWithText(FilledButton, 'Save').last;
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        await tester.enterText(name, ' fItNeSs ');
        await tester.pumpAndSettle();
        expect(find.text('This category already exists.'), findsOneWidget);
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        await tester.enterText(name, ' Garden ');
        await _tapCategoryControl(tester, find.byTooltip('Choose an emoji'));
        await _tapCategoryControl(tester, find.byTooltip('Seedling'));
        await _tapCategoryControl(tester, save);
        expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, 'Garden'))
              .selected,
          isTrue,
        );
        await _tapCategoryControl(tester, find.text('Save'));
      }

      await draftCategory();
      await _tapCategoryControl(tester, find.byTooltip('Close'));
      await _tapCategoryControl(tester, find.text('Discard'));
      expect(repository.customCategories, isEmpty);
      expect(find.widgetWithText(Chip, 'Garden'), findsNothing);

      await draftCategory();
      repository.failSavingHabits = true;
      await _tapCategoryControl(tester, find.text('Save changes'));
      expect(find.text('Could not save the habit. Try again.'), findsOneWidget);
      expect(find.text('Garden'), findsOneWidget);
      expect(repository.customCategories, isEmpty);
      expect(repository.habits.single.categories, isEmpty);

      repository.failSavingHabits = false;
      await _tapCategoryControl(tester, find.text('Save changes'));
      expect(repository.customCategories.single.name, 'Garden');
      expect(repository.customCategories.single.emoji, '🌱');
      expect(repository.habits.single.categories, repository.customCategories);
      expect(find.widgetWithText(Chip, 'Garden'), findsOneWidget);
      expect(find.text('🌱'), findsOneWidget);
    },
  );

  testWidgets(
    'custom categories are reusable, reorderable, and deleted from all habits',
    (tester) async {
      _setCategoryTestViewport(tester);
      const garden = (id: 'custom:garden', name: 'Garden', emoji: '🌱');
      const music = (id: 'custom:music', name: 'Music', emoji: '🎵');
      final repository =
          _MemoryHabitRepository()
            ..customCategories = [garden, music]
            ..habits = [
              const Habit(
                id: 'first',
                name: 'Water plants',
                categories: [garden],
              ),
              const Habit(id: 'second', name: 'Sow seeds'),
            ];
      await tester.pumpWidget(RizeApp(repository: repository));
      await tester.pumpAndSettle();
      await _tapCategoryControl(tester, find.text('Sow seeds'));
      await _tapCategoryControl(tester, find.byTooltip('Edit habit'));
      await _openHabitCategories(tester);
      await _tapCategoryControl(tester, find.text('Garden'));
      await _tapCategoryControl(tester, find.text('Edit'));
      expect(find.text('Fitness'), findsNothing);
      final handle = find.byTooltip('Reorder Garden');
      final drag = await tester.startGesture(tester.getCenter(handle));
      await drag.moveBy(const Offset(0, 20));
      await tester.pump();
      await drag.moveBy(const Offset(0, 120));
      await tester.pumpAndSettle();
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Music')).dy,
        lessThan(tester.getTopLeft(find.text('Garden')).dy),
      );
      await _tapCategoryControl(tester, find.text('Done'));
      await _tapCategoryControl(tester, find.text('Save'));
      await _tapCategoryControl(tester, find.text('Save changes'));
      expect(repository.customCategories, [music, garden]);
      expect(repository.habits.last.categories, [garden]);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(RizeApp(repository: repository));
      await tester.pumpAndSettle();
      await _tapCategoryControl(tester, find.text('Sow seeds'));
      await _tapCategoryControl(tester, find.byTooltip('Edit habit'));
      await _openHabitCategories(tester);
      await _tapCategoryControl(tester, find.text('Edit'));
      final gardenRow = find.widgetWithText(ListTile, 'Garden').hitTestable();
      final musicRow = find.widgetWithText(ListTile, 'Music').hitTestable();
      expect(
        tester.getTopLeft(musicRow).dy,
        lessThan(tester.getTopLeft(gardenRow).dy),
      );
      await _tapCategoryControl(tester, find.byTooltip('Delete Garden'));
      expect(
        find.text(
          'Saving will remove this category from every habit that uses it.',
        ),
        findsOneWidget,
      );
      await _tapCategoryControl(tester, find.text('Delete'));
      await _tapCategoryControl(tester, find.text('Save'));
      expect(repository.customCategories, [music, garden]);
      await _tapCategoryControl(tester, find.text('Save changes'));
      expect(repository.customCategories, [music]);
      expect(
        repository.habits.every((habit) => habit.categories.isEmpty),
        isTrue,
      );
      expect(find.widgetWithText(Chip, 'Garden'), findsNothing);
    },
  );

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
      expect(find.text('Enter a habit name.'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Add your first habit'), findsOneWidget);
    },
  );

  for (final type in HabitType.values) {
    for (final mode in [TrackingMode.count, TrackingMode.measure]) {
      testWidgets('daily amount validation for ${type.name} ${mode.name}', (
        tester,
      ) async {
        final isQuit = type == HabitType.quit;
        final isMeasure = mode == TrackingMode.measure;
        final label = isQuit ? 'Daily limit' : 'Daily goal';
        final repository =
            _MemoryHabitRepository()
              ..habits = [
                Habit(
                  id: 'habit',
                  name: 'Test habit',
                  type: type,
                  trackingMode: mode,
                  unit: isMeasure ? 'minutes' : 'times',
                ),
              ];
        await tester.pumpWidget(RizeApp(repository: repository));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test habit'));
        await tester.pumpAndSettle();

        final amount = find.byKey(const Key('habit-goal'));
        final unit = find.byKey(const Key('habit-unit'));
        final save = find.text('Save changes');

        Future<void> openEditor() async {
          await tester.tap(find.byTooltip('Edit habit'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            amount,
            200,
            scrollable: find.byType(Scrollable).first,
          );
        }

        double savedAmount() =>
            isQuit
                ? repository.habits.single.quitLimit
                : repository.habits.single.target;

        await openEditor();
        final originalAmount = savedAmount();
        final invalidAmounts = [
          ('6299999999', '$label must be 999,999 or less.'),
          ('1000000', '$label must be 999,999 or less.'),
          ('', '$label must be a number.'),
          if (isMeasure) ...[
            ('999999.1', '$label must be 999,999 or less.'),
            ('1.2.3', '$label must be a number.'),
          ],
          if (!isQuit) ('0', 'Daily goal must be greater than 0.'),
        ];

        Future<void> expectError(String message) async {
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(find.text(message), findsOneWidget);
          expect(find.text('Edit Habit'), findsOneWidget);
          expect(savedAmount(), originalAmount);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
        }

        for (final (input, message) in invalidAmounts) {
          await tester.enterText(amount, input);
          await expectError(message);
        }

        if (isMeasure) {
          await tester.enterText(amount, '999999');
          await tester.scrollUntilVisible(
            unit,
            -150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(unit, ' ');
          await expectError('Enter a measurement unit, such as minutes or km.');
          await tester.enterText(unit, 'minutes');
        }

        final validAmounts = [999999, isQuit ? 0 : 1, if (isMeasure) 0.5];
        for (final (index, value) in validAmounts.indexed) {
          if (index > 0) await openEditor();
          await tester.scrollUntilVisible(
            amount,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(amount, '$value');
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(find.text('Edit Habit'), findsNothing);
          expect(savedAmount(), value);
        }
      });
    }
  }

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

  testWidgets('detail cards update after a check-in and a repeat edit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = DateUtils.dateOnly(DateTime.now());
    const color = Color(0xFFA4E635);
    var habit = const Habit(
      id: 'read',
      name: 'Read',
      goalPeriod: GoalPeriod.weekly,
      colorValue: 0xFFA4E635,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HabitDetailScreen(
          habit: habit,
          repository: _MemoryHabitRepository(),
          onEdit:
              () async =>
                  habit = habit.copyWith(
                    goalPeriod: GoalPeriod.monthly,
                    monthlyGoalTarget: 7,
                  ),
          onTrackDay: (day) async => habit = habit.setCount(day, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byType(HabitProgressIndicators);
    Finder cardIcon(IconData icon) =>
        find.descendant(of: cards, matching: find.byIcon(icon));

    expect(find.text('Habit detail'), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Weekly goal'), findsOneWidget);
    final flameIcon = cardIcon(Icons.local_fire_department_rounded);
    final targetIcon = cardIcon(Icons.track_changes_rounded);
    final streak = tester.getCenter(flameIcon);
    final goal = tester.getCenter(targetIcon);
    final history = tester.getRect(find.text('History'));
    expect(streak.dy, closeTo(goal.dy, 0.01));
    expect(goal.dx, greaterThan(streak.dx));
    expect(tester.getBottomLeft(cards).dy, lessThan(history.top));
    expect(
      history.bottom,
      lessThan(tester.getTopLeft(find.byType(HabitHeatmap)).dy),
    );
    expect(find.text('0 days'), findsOneWidget);
    expect(find.text('0 / 1 day'), findsOneWidget);
    expect(tester.widget<Icon>(targetIcon).color, color);

    final todayCell = find.byKey(ValueKey('calendar-day-${dayKey(today)}'));
    await tester.tap(todayCell);
    await tester.pumpAndSettle();
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('1 / 1 day'), findsOneWidget);
    expect(cardIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Edit habit'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly goal'), findsOneWidget);
    expect(find.text('1 / 7 days'), findsOneWidget);
    expect(targetIcon, findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 7 days'), findsOneWidget);
  });

  testWidgets('detail cards show the configured repeat schedule', (
    tester,
  ) async {
    const buildHabit = Habit(id: 'read', name: 'Read');
    const quitHabit = Habit(id: 'soda', name: 'Soda', type: HabitType.quit);
    final schedules = [
      (buildHabit, 'No repeat goal'),
      (buildHabit.copyWith(goalPeriod: GoalPeriod.daily), 'Every day'),
      (buildHabit.copyWith(goalPeriod: GoalPeriod.specificDays), 'Mon–Fri'),
      (
        buildHabit.copyWith(goalPeriod: GoalPeriod.everyFewDays),
        'Every 5 days',
      ),
      (quitHabit, 'Slip-free days'),
      (quitHabit.copyWith(quitLimit: 2), 'Everyday'),
    ];

    for (final (habit, label) in schedules) {
      await tester.pumpWidget(
        MaterialApp(
          home: HabitDetailScreen(
            key: ValueKey(label),
            habit: habit,
            repository: _MemoryHabitRepository(),
            onEdit: () async => null,
            onTrackDay: (_) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('detail cards stack at larger text sizes on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const streakLabel = '2 days';
    const repeatLabel = 'Mon, Tue, Wed, Thu, Fri, Sat';
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: 2,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: HabitProgressIndicators(
              streakLabel: streakLabel,
              goalTitle: 'Repeat',
              goalLabel: repeatLabel,
              goalReached: false,
              color: Color(0xFFA4E635),
            ),
          ),
        ),
      ),
    );

    final streak = tester.getRect(find.text(streakLabel));
    final repeat = tester.getRect(find.text(repeatLabel));
    expect(repeat.top, greaterThan(streak.bottom));
    expect(repeat.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today cards wrap measured progress and show the daily bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now();
    final habit = Habit(
      id: 'water',
      name: 'Drink water',
      colorValue: 0xFF4CAF50,
      trackingMode: TrackingMode.measure,
      target: 1000,
      unit: 'millilitres',
      dailyCounts: {
        dayKey(today): 300.5,
        dayKey(shiftHabitDay(today, -1)): 1000,
      },
    );
    final repository = _MemoryHabitRepository()..habits = [habit];

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final subtitle = find.text('300.5 / 1000 millilitres today');
    final name = find.text('Drink water');
    expect(subtitle, findsOneWidget);
    expect(
      tester.getTopLeft(subtitle).dy,
      greaterThan(tester.getBottomLeft(name).dy),
    );
    expect(
      tester.getSize(subtitle).height,
      greaterThan(tester.getSize(name).height),
    );
    expect(find.byType(HabitHeatmap), findsNothing);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.3005, 0.0001));
    expect(bar.color, Color(habit.colorValue));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(_viewMenuItem('Heatmaps'));
    await tester.pumpAndSettle();
    final heatmap = find.byType(HabitHeatmap);
    expect(heatmap, findsOneWidget);
    expect(
      tester.widget<HabitHeatmap>(heatmap).endDate,
      DateUtils.dateOnly(today),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(subtitle, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(_viewMenuItem('Progress bars'));
    await tester.pumpAndSettle();
    expect(heatmap, findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('Last 5 days keeps a fixed range and tracks the tapped date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = shiftHabitDay(today, -1);
    final habit = Habit(id: 'read', name: 'Read', startDate: yesterday);
    final repository = _MemoryHabitRepository()..habits = [habit];
    await tester.pumpWidget(RizeApp(repository: repository));
    await tester.pumpAndSettle();

    Future<void> chooseView(String label) async {
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(_viewMenuItem(label));
      await tester.pumpAndSettle();
    }

    final timeline = find.byKey(const Key('today-week-timeline'));
    await tester.drag(timeline, const Offset(235, 0));
    await tester.pumpAndSettle();
    await tester.tap(_timelineDate(shiftHabitDay(today, -7)));
    await tester.pumpAndSettle();
    await chooseView('Last 5 days');
    expect(timeline, findsNothing);
    expect(find.text('Last 5 days'), findsOneWidget);
    expect(find.text('1 habit'), findsOneWidget);
    expect(find.text('🔥0'), findsOneWidget);
    for (var offset = -4; offset <= 0; offset++) {
      final day = shiftHabitDay(today, offset);
      final marker = find.byKey(ValueKey('recent-read-${dayKey(day)}'));
      final rect = tester.getRect(marker);
      expect(rect.left, greaterThanOrEqualTo(20));
      expect(rect.right, lessThanOrEqualTo(300));
      expect(rect.height, greaterThanOrEqualTo(48));
      if (offset < -1) {
        expect(tester.widget<InkWell>(marker).onTap, isNull);
      }
    }
    final marker = find.byKey(ValueKey('recent-read-${dayKey(yesterday)}'));
    await tester.tap(marker);
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(yesterday), 1);
    expect(repository.habits.single.countOn(today), 0);
    expect(
      tester.widget<Text>(find.text('🔥1')).semanticsLabel,
      '1 day streak',
    );
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(find.text('1 day'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await chooseView('Heatmaps');
    expect(timeline, findsOneWidget);
    expect(_timelineDate(today).hitTestable(), findsOneWidget);
    expect(find.byType(HabitHeatmap), findsOneWidget);
    await chooseView('Progress bars');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Last 5 days includes both months when the range crosses a boundary',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentHabitsTable(
              today: DateTime(2026, 11, 2),
              habits: const [Habit(id: 'walk', name: 'Walk')],
              isActiveOn: (_, _) => true,
              onOpenHabit: (_) {},
              onTrackDay: (_, _) {},
            ),
          ),
        ),
      );
      expect(find.text('Oct 29 – Nov 2'), findsOneWidget);
      expect(
        tester.getRect(find.text('Oct 29 – Nov 2')).right,
        tester.getRect(find.byType(Table)).right,
      );
      for (final day in [29, 30, 31, 1, 2]) {
        final date = DateTime(2026, day > 2 ? 10 : 11, day);
        final dateLabel = find.text('$day');
        final marker = find.byKey(ValueKey('recent-walk-${dayKey(date)}'));
        expect(
          tester.getCenter(dateLabel).dx,
          closeTo(tester.getCenter(marker).dx, 0.1),
        );
      }
      expect(
        tester.widget<Text>(find.text('2')).style?.color,
        AppColors.burntOrange,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Today header fits seven dates and only offers Show all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final today = DateTime(2027, 1, 7);
    var selectedDay = today;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StatefulBuilder(
              builder:
                  (context, setState) => TodayTimeline(
                    today: today,
                    selectedDay: selectedDay,
                    completionForDay: (day) => (completed: 2, active: 3),
                    onSelectDay: (day) => setState(() => selectedDay = day),
                    onAddHabit: () {},
                  ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getCenter(find.text('Today')).dx, closeTo(160, 1));
    expect(find.text('January 2027'), findsOneWidget);
    expect(find.byTooltip('Add habit'), findsOneWidget);
    for (var day = 4; day <= 10; day++) {
      final bounds = tester.getRect(_timelineDate(DateTime(2027, 1, day)));
      expect(bounds.left, greaterThanOrEqualTo(20));
      expect(bounds.right, lessThanOrEqualTo(300));
    }
    expect(_timelineProgress(tester, today), closeTo(2 / 3, 0.001));
    expect(
      find.byTooltip(
        'Thursday, January 7, 2027 · 67% complete (2 of 3 habits)',
      ),
      findsOneWidget,
    );

    final tomorrow = shiftHabitDay(today, 1);
    final yesterday = shiftHabitDay(today, -1);
    expect(_timelineProgress(tester, yesterday), closeTo(2 / 3, 0.001));
    for (final offset in [1, 2, 3]) {
      expect(
        find.descendant(
          of: _timelineDate(shiftHabitDay(today, offset)),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    }
    expect(
      tester.widget<Semantics>(_timelineDate(tomorrow)).properties.enabled,
      isFalse,
    );
    await tester.tap(_timelineDate(tomorrow), warnIfMissed: false);
    expect(selectedDay, today);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    final menu = find.byType(CheckedPopupMenuItem<String>);
    expect(menu, findsOneWidget);
    expect(tester.widget<CheckedPopupMenuItem<String>>(menu).checked, isTrue);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Show all'), findsNothing);
    expect(selectedDay, today);

    final timeline = find.byKey(const Key('today-week-timeline'));
    await tester.drag(timeline, const Offset(235, 0));
    await tester.pumpAndSettle();
    final newYearRange = find.text('Dec 28, 2026 – Jan 3, 2027');
    expect(find.text('December – January'), findsNothing);
    expect(newYearRange, findsOneWidget);
    expect(selectedDay, today);

    final pastDay = DateTime(2027, 1, 2);
    await tester.tap(_timelineDate(pastDay));
    await tester.pumpAndSettle();
    expect(selectedDay, pastDay);
    expect(newYearRange, findsOneWidget);
    expect(_timelineProgress(tester, pastDay), closeTo(2 / 3, 0.001));

    await tester.drag(timeline, const Offset(235, 0));
    await tester.pumpAndSettle();
    expect(find.text('December'), findsOneWidget);
    final pastRange = find.text('21 – 27, 2026');
    expect(pastRange, findsOneWidget);
    expect(selectedDay, pastDay);

    for (var week = 0; week < 3; week++) {
      await tester.drag(timeline, const Offset(235, 0));
      await tester.pumpAndSettle();
    }
    final crossMonthRange = find.text('Nov 30 – Dec 6');
    expect(crossMonthRange, findsOneWidget);
    expect(find.text('2026'), findsOneWidget);

    await tester.tap(crossMonthRange);
    await tester.pumpAndSettle();
    expect(find.text('January 2027'), findsOneWidget);
    expect(selectedDay, today);
    expect(_timelineDate(today).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Today timeline updates historical progress and applies the edit window',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final editable = shiftHabitDay(today, -7);
      final readOnly = shiftHabitDay(today, -8);
      final repository =
          _MemoryHabitRepository()
            ..habits = [
              Habit(
                id: 'read',
                name: 'Read',
                target: 2,
                startDate: readOnly,
                dailyCounts: {dayKey(editable): 2, dayKey(readOnly): 1},
              ),
              Habit(
                id: 'water',
                name: 'Drink water',
                target: 2,
                startDate: readOnly,
                dailyCounts: {dayKey(editable): 1, dayKey(today): 2},
              ),
              Habit(
                id: 'soda',
                name: 'Limit soda',
                type: HabitType.quit,
                quitLimit: 3,
                startDate: readOnly,
                noteSlipDays: {dayKey(editable)},
              ),
              Habit(id: 'walk', name: 'Walk', startDate: today),
            ];
      await tester.pumpWidget(RizeApp(repository: repository));
      await tester.pumpAndSettle();

      expect(_timelineProgress(tester, today), 0.5);
      expect(find.text('Walk'), findsOneWidget);
      await _selectEarlierTimelineDate(tester, editable);
      expect(find.text('Walk'), findsNothing);
      expect(find.text('Slip recorded · 0 / 3 times'), findsOneWidget);
      expect(_timelineProgress(tester, editable), closeTo(1 / 3, 0.001));
      final neighboringDay = shiftHabitDay(
        editable,
        editable.weekday == DateTime.sunday ? -1 : 1,
      );
      expect(_timelineProgress(tester, neighboringDay), closeTo(1 / 3, 0.001));
      final waterCard =
          find
              .ancestor(
                of: find.text('Drink water'),
                matching: find.byType(InkWell),
              )
              .first;
      await tester.tap(
        find.descendant(
          of: waterCard,
          matching: find.byTooltip('Track this date'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.habits[1].countOn(editable), 2);
      expect(repository.habits[1].countOn(today), 2);
      expect(_timelineProgress(tester, editable), closeTo(2 / 3, 0.001));
      expect(_timelineProgress(tester, neighboringDay), closeTo(1 / 3, 0.001));

      await _selectEarlierTimelineDate(tester, readOnly);
      expect(
        find.text('Read-only · Tracking is available for the past 7 days.'),
        findsOneWidget,
      );
      final disabled = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Tracking unavailable for this date',
      );
      expect(disabled, findsNWidgets(3));
      expect(
        tester
            .widgetList<IconButton>(disabled)
            .every((button) => button.onPressed == null),
        isTrue,
      );
      await tester.tap(disabled.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repository.habits.first.countOn(readOnly), 1);
      expect(_timelineProgress(tester, readOnly), closeTo(1 / 3, 0.001));

      await tester.tap(find.byTooltip('Back to today'));
      await tester.pumpAndSettle();
      expect(_timelineDate(today).hitTestable(), findsOneWidget);
      expect(_timelineProgress(tester, today), 0.5);
      expect(find.text('Walk'), findsOneWidget);
      expect(disabled, findsNothing);
    },
  );

  testWidgets(
    'Today timeline preserves older records and handles an empty day',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final history = shiftHabitDay(today, -3);
      final emptyDay = shiftHabitDay(today, -10);
      final repository =
          _MemoryHabitRepository()
            ..habits = [
              Habit(
                id: 'legacy',
                name: 'Legacy build',
                dailyCounts: {dayKey(shiftHabitDay(history, -1)): 1},
              ),
              Habit(
                id: 'slip',
                name: 'Recorded slip',
                type: HabitType.quit,
                trackingMode: TrackingMode.yesNo,
                startDate: today,
                noteSlipDays: {dayKey(history)},
              ),
              const Habit(id: 'unknown', name: 'No history yet'),
            ];
      await tester.pumpWidget(RizeApp(repository: repository));
      await tester.pumpAndSettle();

      await _selectEarlierTimelineDate(tester, history);
      expect(find.text('Legacy build'), findsOneWidget);
      expect(find.text('Recorded slip'), findsOneWidget);
      expect(find.text('No history yet'), findsNothing);
      expect(_timelineProgress(tester, history), 0);
      expect(
        tester.widget<Semantics>(_timelineDate(history)).properties.value,
        '0% complete (0 of 2 habits)',
      );

      await _selectEarlierTimelineDate(tester, emptyDay);
      expect(find.text('No habits on this date'), findsOneWidget);
      expect(_timelineProgress(tester, emptyDay), 0);
      expect(
        tester.widget<Semantics>(_timelineDate(emptyDay)).properties.value,
        '0% complete (0 of 0 habits)',
      );
    },
  );

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
    await tester.tap(find.text('Quit soda'));
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

  testWidgets('quit-habit calendar distinguishes slips from slip-free days', (
    tester,
  ) async {
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

    Finder marker(DateTime day, IconData icon) => find.descendant(
      of: find.byKey(ValueKey('calendar-day-${dayKey(day)}')),
      matching: find.byIcon(icon),
    );

    expect(marker(slipDay, Icons.close_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(marker(soberDay, Icons.check_rounded)).color,
      AppColors.burntOrange,
    );
  });

  testWidgets('calendar shows build ratios and updates them after tracking', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime.now();
    final month = DateTime(today.year, today.month - 1);
    final partialDay = DateTime(month.year, month.month, 2);
    final completeDay = shiftHabitDay(partialDay, 1);
    final emptyDay = shiftHabitDay(completeDay, 1);
    final freeDay = shiftHabitDay(
      month,
      7 + (DateTime.saturday - month.weekday) % 7,
    );
    final adjacentDay = DateTime(today.year, today.month);
    final futureDay = DateTime(today.year, today.month + 1, 2);
    var habit = Habit(
      id: 'walk',
      name: 'Walk',
      target: 5.5,
      trackingMode: TrackingMode.measure,
      unit: 'km',
      goalPeriod: GoalPeriod.specificDays,
      startDate: month,
      dailyCounts: {
        dayKey(partialDay): 2.25,
        dayKey(completeDay): 12500,
        dayKey(adjacentDay): 5.5,
        dayKey(futureDay): 5.5,
      },
    );
    final repository =
        _MemoryHabitRepository()
          ..notes[dayKey(partialDay)] = 'Walked before breakfast';

    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.5,
              child: child!,
            ),
        home: HabitDetailScreen(
          habit: habit,
          repository: repository,
          onEdit: () async => null,
          onTrackDay: (day) async => habit = habit.setCount(day, 5.5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    Finder cell(DateTime day) =>
        find.byKey(ValueKey('calendar-day-${dayKey(day)}'));
    Finder inCell(DateTime day, Finder matching) =>
        find.descendant(of: cell(day), matching: matching);
    Finder bar(DateTime day) =>
        inCell(day, find.byType(LinearProgressIndicator));

    expect(inCell(partialDay, find.text('2.25/5.5')), findsOneWidget);
    expect(
      inCell(partialDay, find.byIcon(Icons.notes_rounded)),
      findsOneWidget,
    );
    expect(
      tester.widget<LinearProgressIndicator>(bar(partialDay)).value,
      closeTo(2.25 / 5.5, 0.001),
    );
    expect(inCell(completeDay, find.text('12.5k/5.5')), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(bar(completeDay)).value, 1);
    expect(
      find.bySemanticsLabel(RegExp('12500 of 5.5 km.*Daily goal reached')),
      findsOneWidget,
    );
    expect(bar(emptyDay), findsNothing);
    expect(bar(adjacentDay), findsNothing);
    expect(bar(freeDay), findsNothing);
    expect(inCell(freeDay, find.byType(Text)), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Free day')), findsNothing);

    final lastDay = shiftHabitDay(month, 42 - month.weekday);
    expect(
      tester.getRect(cell(lastDay)).bottom,
      closeTo(tester.getRect(find.byType(PageView)).bottom, 0.01),
    );
    await tester.tap(cell(partialDay));
    await tester.pumpAndSettle();
    expect(inCell(partialDay, find.text('5.5/5.5')), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(bar(partialDay)).value, 1);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    expect(cell(futureDay), findsOneWidget);
    expect(bar(futureDay), findsNothing);
  });

  testWidgets('quit calendar bars show the remaining daily allowance', (
    tester,
  ) async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month - 1);
    final start = DateTime(month.year, month.month, 2);
    final habit = Habit(
      id: 'soda',
      name: 'Limit soda',
      type: HabitType.quit,
      quitLimit: 5,
      startDate: start,
      dailyCounts: {
        dayKey(shiftHabitDay(start, 1)): 2,
        dayKey(shiftHabitDay(start, 2)): 5,
        dayKey(shiftHabitDay(start, 3)): 7,
      },
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

    expect(
      find.text('Amount / limit · Bar shows how much is left'),
      findsOneWidget,
    );
    for (final (offset, label, remaining) in [
      (0, '0/5', 1.0),
      (1, '2/5', 0.6),
      (2, '5/5', 0.0),
      (3, '7/5', 0.0),
    ]) {
      final day = shiftHabitDay(start, offset);
      final cell = find.byKey(ValueKey('calendar-day-${dayKey(day)}'));
      expect(
        find.descendant(of: cell, matching: find.text(label)),
        findsOneWidget,
      );
      final bar = find.descendant(
        of: cell,
        matching: find.byType(LinearProgressIndicator),
      );
      expect(
        tester.widget<LinearProgressIndicator>(bar).value,
        closeTo(remaining, 0.001),
      );
      expect(
        find.descendant(
          of: cell,
          matching: find.byIcon(Icons.close_rounded),
        ),
        offset >= 2 ? findsOneWidget : findsNothing,
      );
    }
  });

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

  testWidgets('add-one tap opens the editor after reaching the build goal', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            Habit(
              id: 'read',
              name: 'Read',
              target: 5,
              dailyCounts: {dayKey(today): 4},
            ),
          ];
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final trackButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Track today',
    );
    double fillOpacity() =>
        tester
            .widget<IconButton>(trackButton)
            .style!
            .backgroundColor!
            .resolve({})!
            .a;
    expect(fillOpacity(), closeTo(0.84, 0.001));

    await tester.tap(find.byTooltip('Track today'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(today), 5);
    expect(fillOpacity(), 1);
    expect(find.byKey(const Key('tracking-count')), findsNothing);

    await tester.tap(find.byTooltip('Track today'));
    await tester.pumpAndSettle();
    final input = find.byKey(const Key('tracking-count'));
    expect(tester.widget<TextField>(input).controller!.text, '5');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(repository.habits.single.countOn(today), 5);
  });

  for (final type in HabitType.values) {
    testWidgets(
      'calendar add-one opens the editor after the ${type.name} cutoff',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final today = DateTime.now();
        final day = DateTime(today.year, today.month);
        final repository =
            _MemoryHabitRepository()
              ..habits = [
                Habit(
                  id: 'read',
                  name: 'Read',
                  type: type,
                  target: 5,
                  quitLimit: 5,
                  startDate: day,
                  dailyCounts: {dayKey(day): 4},
                ),
              ];
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
        await tester.pumpAndSettle();
        await tester.tap(dayCell);
        await tester.pumpAndSettle();
        expect(repository.habits.single.countOn(day), 5);
        expect(find.byKey(const Key('tracking-count')), findsNothing);

        await tester.tap(dayCell);
        await tester.pumpAndSettle();
        final input = find.byKey(const Key('tracking-count'));
        expect(tester.widget<TextField>(input).controller!.text, '5');
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(input, findsNothing);
        expect(repository.habits.single.countOn(day), 5);
      },
    );
  }

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

  testWidgets('tracking handle follows a downward drag and dismisses', (
    tester,
  ) async {
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            const Habit(
              id: 'walk',
              name: 'Walk',
              tapAction: TapAction.enterTotal,
            ),
          ];
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Track today'));
    await tester.pumpAndSettle();

    final handle = find.byKey(const Key('tracking-drag-handle'));
    final initialTop = tester.getTopLeft(handle).dy;
    await tester.timedDrag(
      handle,
      const Offset(0, -120),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(handle).dy, initialTop);

    final drag = await tester.startGesture(tester.getCenter(handle));
    await drag.moveBy(const Offset(0, 25));
    await drag.moveBy(const Offset(0, 15));
    await tester.pump();
    expect(tester.getTopLeft(handle).dy, greaterThan(initialTop));
    await tester.pump(const Duration(milliseconds: 300));
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(handle).dy, initialTop);

    await tester.timedDrag(
      handle,
      const Offset(0, 120),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    expect(handle, findsNothing);
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

    await tester.timedDrag(
      find.byKey(const Key('tracking-drag-handle')),
      const Offset(0, 180),
      const Duration(milliseconds: 1000),
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
      expect(find.text('Notes'), findsOneWidget);
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

    expect(find.text('Notes'), findsOneWidget);
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
    expect(find.text('Slip-free today'), findsOneWidget);
    await tester.tap(find.byTooltip('Record a slip'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 1);
    expect(repository.habits.single.isCompleteOn(DateTime.now()), isFalse);
    expect(find.text('Slip recorded today'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );

    await tester.tap(find.byTooltip('Clear today’s slip'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(DateTime.now()), 0);
    expect(repository.habits.single.isCompleteOn(DateTime.now()), isTrue);
    expect(find.text('Slip-free today'), findsOneWidget);
    expect(find.byKey(const Key('tracking-save')), findsNothing);
  });

  testWidgets(
    'quit note editor shares slip status across detail entry points',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateUtils.dateOnly(DateTime.now());
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final repository =
          _MemoryHabitRepository()
            ..habits = [
              Habit(
                id: 'quit-soda',
                name: 'Limit soda',
                type: HabitType.quit,
                quitLimit: 8,
                startDate: yesterday,
                colorValue: Colors.green.toARGB32(),
                dailyCounts: {dayKey(today): 2, dayKey(yesterday): 8},
              ),
            ];
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limit soda'));
      await tester.pumpAndSettle();

      final dayCell = find.byKey(ValueKey('calendar-day-${dayKey(today)}'));
      final progressBar = find.descendant(
        of: dayCell,
        matching: find.byType(LinearProgressIndicator),
      );
      await tester.scrollUntilVisible(
        dayCell,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.longPress(dayCell);
      await tester.pumpAndSettle();
      expect(tester.widget<LinearProgressIndicator>(progressBar).value, 0.75);
      final slipSwitch = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(slipSwitch).value, isFalse);
      expect(
        tester.widget<SwitchListTile>(slipSwitch).activeTrackColor,
        Color(Colors.green.toARGB32()),
      );
      await tester.enterText(find.byType(TextField), 'A draft note');

      repository.failSavingHabits = true;
      await tester.tap(find.text('Mark as slip'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(slipSwitch).value, isFalse);
      expect(
        find.text('Your slip status could not be saved. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('A draft note'), findsOneWidget);

      repository.failSavingHabits = false;
      repository.saveDelay = const Duration(milliseconds: 200);
      await tester.tap(find.text('Mark as slip'));
      await tester.pump();
      expect(tester.widget<SwitchListTile>(slipSwitch).onChanged, isNull);
      await tester.pump(repository.saveDelay);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(slipSwitch).value, isTrue);
      repository.saveDelay = Duration.zero;
      expect(repository.habits.single.isCompleteOn(today), isFalse);
      expect(repository.habits.single.countOn(today), 2);
      expect(tester.widget<LinearProgressIndicator>(progressBar).value, 0);
      expect(repository.notes, isEmpty);
      expect(find.text('A draft note'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.notes[dayKey(today)], 'A draft note');
      expect(
        find.descendant(
          of: dayCell,
          matching: find.byIcon(Icons.close_rounded),
        ),
        findsOneWidget,
      );

      final preview = find.text('A draft note');
      await tester.scrollUntilVisible(
        preview,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(slipSwitch).value, isTrue);
      await tester.tap(find.text('Mark as slip'));
      await tester.pumpAndSettle();
      expect(repository.habits.single.isCompleteOn(today), isTrue);
      expect(repository.habits.single.countOn(today), 2);
      expect(tester.widget<LinearProgressIndicator>(progressBar).value, 0.75);
      await tester.tap(find.byTooltip('Close note editor'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('All notes'));
      await tester.tap(find.text('All notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A draft note'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(slipSwitch).value, isFalse);
      await tester.tap(find.byTooltip('Close note editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add note for a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose note date'));
      await tester.pumpAndSettle();
      if (yesterday.month != today.month) {
        await tester.tap(find.byTooltip('Previous month').hitTestable());
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('${yesterday.day}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(slipSwitch).value, isTrue);
      await tester.tap(find.text('Mark as slip'));
      await tester.pumpAndSettle();
      expect(repository.habits.single.isSlipFreeOn(yesterday), isTrue);
    },
  );

  testWidgets(
    'tracking opens the same quit note editor and keeps count drafts',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final repository =
          _MemoryHabitRepository()
            ..habits = [
              Habit(
                id: 'quit-soda',
                name: 'Limit soda',
                type: HabitType.quit,
                quitLimit: 8,
                tapAction: TapAction.enterTotal,
                startDate: today,
                dailyCounts: {dayKey(today): 2},
              ),
            ];
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      final track = find.byTooltip('Track today');
      final noteButton = find.byKey(const Key('tracking-note'));
      final count = find.byKey(const Key('tracking-count'));
      final save = find.byKey(const Key('tracking-save'));

      await tester.tap(track);
      await tester.pumpAndSettle();
      await tester.tap(noteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as slip'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close note editor'));
      await tester.pumpAndSettle();
      expect(find.text('Slip recorded'), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.habits.single.hasNoteSlipOn(today), isTrue);
      expect(find.text('Slip recorded · 2 / 8 times today'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0,
      );

      await tester.tap(track);
      await tester.pumpAndSettle();
      await tester.enterText(count, '3');
      await tester.tap(noteButton);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await tester.tap(find.text('Mark as slip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as slip'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close note editor'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(count).controller!.text, '3');
      expect(repository.habits.single.countOn(today), 2);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.habits.single.countOn(today), 3);
      expect(repository.habits.single.hasNoteSlipOn(today), isFalse);
    },
  );

  testWidgets('quit habits save and track against a daily count limit', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final repository =
        _MemoryHabitRepository()
          ..habits = [
            Habit(
              id: 'soda',
              name: 'Limit soda',
              type: HabitType.quit,
              startDate: today,
            ),
          ];
    await tester.pumpWidget(RizeApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limit soda'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit habit'));
    await tester.pumpAndSettle();

    final goal = find.byKey(const Key('habit-goal'));
    await tester.scrollUntilVisible(
      find.text('DAILY LIMIT'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('DAILY LIMIT'), findsOneWidget);
    expect(tester.widget<TextField>(goal).controller!.text, '0');
    await tester.enterText(goal, '5');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repository.habits.single.quitLimit, 5);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final cell = find.byKey(ValueKey('habit-heatmap-${dayKey(today)}'));
    Color? heatmapColor() =>
        (tester.widget<Container>(cell).decoration! as BoxDecoration).color;
    double? dailyBarValue() =>
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value;
    final track = find.byTooltip('Track today');
    final input = find.byKey(const Key('tracking-count'));
    ButtonStyle trackStyle() =>
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Track today',
              ),
            )
            .style!;
    Color? buttonFill() => trackStyle().backgroundColor?.resolve({});
    Color? checkColor() => trackStyle().foregroundColor?.resolve({});

    expect(buttonFill(), AppColors.burntOrange);
    expect(checkColor(), AppColors.carbon);
    expect(find.text('Under limit · 0 / 5 times today'), findsOneWidget);
    expect(dailyBarValue(), 1);
    for (var i = 0; i < 2; i++) {
      await tester.tap(track);
    }
    await tester.pumpAndSettle();
    expect(buttonFill()!.a, closeTo(0.68, 0.001));
    expect(find.text('Under limit · 2 / 5 times today'), findsOneWidget);
    expect(dailyBarValue(), closeTo(0.6, 0.001));
    for (var i = 0; i < 2; i++) {
      await tester.tap(track);
    }
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(repository.habits.single.countOn(today), 4);
    expect(repository.habits.single.isCompleteOn(today), isTrue);
    expect(dailyBarValue(), closeTo(0.2, 0.001));
    expect(buttonFill()!.a, closeTo(0.36, 0.001));
    expect(checkColor(), AppColors.burntOrange);

    await tester.tap(find.text('Limit soda'));
    await tester.pumpAndSettle();
    expect(heatmapColor()!.a, closeTo(0.2, 0.001));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    repository.saveDelay = const Duration(milliseconds: 20);
    await tester.tap(track);
    await tester.tap(track);
    await tester.tap(track);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, '5');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(repository.habits.single.countOn(today), 5);
    expect(repository.habits.single.isCompleteOn(today), isFalse);
    expect(find.text('Limit reached · 5 / 5 times today'), findsOneWidget);
    expect(dailyBarValue(), 0);
    expect(buttonFill(), AppColors.burntOrange.withValues(alpha: 0.2));
    expect(checkColor(), AppColors.burntOrange);
    await tester.tap(find.text('Limit soda'));
    await tester.pumpAndSettle();
    expect(find.text('0 days'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit habit'));
    await tester.pumpAndSettle();
    final enterTotal = find.text('Enter total');
    await tester.scrollUntilVisible(
      enterTotal,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(enterTotal);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(track);
    await tester.pumpAndSettle();
    expect(find.text('Stay under 5 times'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    await tester.enterText(input, '4');
    await tester.pump();
    expect(find.text('20%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .value,
      closeTo(0.2, 0.001),
    );
    await tester.tap(find.byKey(const Key('tracking-save')));
    await tester.pumpAndSettle();
    expect(repository.habits.single.countOn(today), 4);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(_viewMenuItem('Last 5 days'));
    await tester.pumpAndSettle();
    final marker = find.byKey(ValueKey('recent-soda-${dayKey(today)}'));
    final ring = find.descendant(
      of: marker,
      matching: find.byType(CircularProgressIndicator),
    );
    expect(
      tester.widget<CircularProgressIndicator>(ring).value,
      closeTo(0.2, 0.001),
    );
    await tester.tap(marker);
    await tester.pumpAndSettle();
    await tester.enterText(input, '5');
    await tester.tap(find.byKey(const Key('tracking-save')));
    await tester.pumpAndSettle();
    expect(ring, findsNothing);
    expect(
      find.descendant(of: marker, matching: find.byIcon(Icons.close_rounded)),
      findsOneWidget,
    );
  });

  for (final (type, cutoff, initial, expected) in [
    (HabitType.quit, 0.0, 0.0, 0.0),
    (HabitType.build, 2.5, 2.0, 2.5),
    (HabitType.quit, 2.5, 2.0, 3.0),
  ]) {
    testWidgets('add-one handles a ${type.name} cutoff of $cutoff', (
      tester,
    ) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final habit = Habit(
        id: 'test',
        name: 'Track amount',
        type: type,
        startDate: today,
        trackingMode: TrackingMode.measure,
        target: type == HabitType.build ? cutoff : 1,
        quitLimit: type == HabitType.quit ? cutoff : 0,
        dailyCounts: {if (initial > 0) dayKey(today): initial},
      );
      final repository = _MemoryHabitRepository()..habits = [habit];
      await tester.pumpWidget(RizeApp(repository: repository));
      await tester.pumpAndSettle();

      final track = find.byTooltip('Track today');
      final input = find.byKey(const Key('tracking-count'));
      if (cutoff == 0) {
        expect(find.text('Slip-free · 0 / 0 times today'), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          1,
        );
      }
      if (initial < cutoff) {
        await tester.tap(track);
        await tester.pumpAndSettle();
        expect(input, findsNothing);
        expect(repository.habits.single.countOn(today), expected);
      }
      await tester.tap(track);
      await tester.pumpAndSettle();
      expect(
        double.parse(tester.widget<TextField>(input).controller!.text),
        expected,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(repository.habits.single.countOn(today), expected);
      if (cutoff == 0) expect(repository.habits.single.dailyCounts, isEmpty);
    });
  }

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
    'repeat fill stays in habit history and still allows a real check-in',
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
      double? dailyBarValue() =>
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value;
      expect(find.text('Not completed today'), findsOneWidget);
      expect(dailyBarValue(), 0);
      expect(repository.habits.single.dailyCounts, hasLength(1));

      await tester.tap(find.text('Stretch'));
      await tester.pumpAndSettle();
      expect(find.text('0 days'), findsOneWidget);
      expect(find.text('Every 5 days'), findsOneWidget);
      expect(heatmapDecoration().color, color.withValues(alpha: 0.18));
      final calendarDay = find.byKey(ValueKey('calendar-day-${dayKey(today)}'));
      expect(
        find.descendant(of: calendarDay, matching: find.text('Covered')),
        findsOneWidget,
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
      expect(find.text('Completed today'), findsOneWidget);
      expect(dailyBarValue(), 1);
      expect(repository.habits.single.dailyCounts, hasLength(2));
      await tester.tap(find.text('Stretch'));
      await tester.pumpAndSettle();
      expect(heatmapDecoration().color, color);
      expect(find.text('1 day'), findsOneWidget);
      expect(
        find.descendant(
          of: calendarDay,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
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
    await tester.pumpAndSettle();
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
