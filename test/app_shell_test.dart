import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rize/data/habit_repository.dart';
import 'package:rize/domain/habit.dart';
import 'package:rize/presentation/app_shell.dart';
import 'package:rize/presentation/launch_screen.dart';

class _Repository extends HabitRepository {
  int loads = 0;
  List<Habit> habits = [
    const Habit(id: 'read', name: 'Read', trackingMode: TrackingMode.yesNo),
  ];

  @override
  Future<List<Habit>> loadHabits() async {
    loads++;
    return habits;
  }

  @override
  Future<void> saveHabits(List<Habit> habits) async => this.habits = habits;
}

void main() {
  testWidgets(
    'header prioritizes quit habits, changes focus and opens menu and account',
    (tester) async {
      final repository =
          _Repository()
            ..habits.add(
              const Habit(
                id: 'caffeine',
                name: 'Caffeine',
                type: HabitType.quit,
              ),
            );
      await tester.pumpWidget(
        MaterialApp(home: AppShell(repository: repository)),
      );
      await tester.pumpAndSettle();
      final picker = find.byKey(const ValueKey('focus-habit-picker'));
      expect(
        find.descendant(of: picker, matching: find.text('Caffeine')),
        findsOneWidget,
      );
      expect(find.text('Sober for: 1 day'), findsOneWidget);
      expect(find.byTooltip('Done for today'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Summary'), findsNothing);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Read'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: picker, matching: find.text('Read')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('A space for your Rize profile.'), findsOneWidget);
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Today'), findsNothing);
      expect(find.text('Add new habit'), findsOneWidget);
      await tester.tapAt(const Offset(750, 300));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mark complete'), findsOneWidget);
      expect(repository.habits.first.countOn(DateTime.now()), 0);
    },
  );

  testWidgets('habit menu opens add and edit flows and shows a preview trial', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AppShell(repository: _Repository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add new habit'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-name')), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit list'));
    await tester.pumpAndSettle();
    expect(find.text('Edit habit list'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Read'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('habit-name')))
          .controller!
          .text,
      'Read',
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    final trial = find.widgetWithText(FilledButton, 'Try for free 7 days');
    await tester.ensureVisible(trial);
    await tester.drag(
      find.descendant(of: find.byType(Drawer), matching: find.byType(ListView)),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(trial);
    await tester.pumpAndSettle();
    expect(find.text('Rize Surge preview'), findsOneWidget);
  });

  testWidgets('launch animation finishes once and opens Today', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(home: LaunchScreen(child: AppShell(repository: repository))),
    );
    expect(find.bySemanticsLabel('Starting Rize'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Starting Rize'), findsNothing);
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Preview · Coming soon'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsNWidgets(2));
    expect(repository.loads, 2);
  });

  testWidgets('reduced motion skips launch animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LaunchScreen(child: AppShell(repository: _Repository())),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Starting Rize'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsNWidgets(2));
  });

  testWidgets('preview tabs navigate and Today keeps saved completion', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(home: AppShell(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mark complete'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Done for today'), findsOneWidget);
    expect(find.text('Streak: 1 day'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Summary'), findsNothing);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Progress'));
    await tester.pumpAndSettle();
    for (final label in [
      'Summary',
      'Savings',
      'Calendar',
      'Urges',
      'Reasons',
      'Settings',
    ]) {
      final tab = find.widgetWithText(TextButton, label);
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.text('Preview · Coming soon'), findsOneWidget);
    }
    for (final label in ['Motivation', 'Support', 'Progress']) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(find.text('Preview · Coming soon'), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Summary'), findsNothing);
    expect(find.byTooltip('Mark incomplete'), findsOneWidget);
    expect(repository.habits.single.countOn(DateTime.now()), 1);
    expect(repository.loads, 2);
    await tester.tap(find.byTooltip('Mark incomplete'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Not done for today'), findsOneWidget);
    expect(repository.habits.single.countOn(DateTime.now()), 0);
  });
}
