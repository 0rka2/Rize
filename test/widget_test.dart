// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rize/data/habit_repository.dart';
import 'package:rize/domain/habit.dart';
import 'package:rize/presentation/home_screen.dart';

class _MemoryHabitRepository extends HabitRepository {
  List<Habit> habits = [];

  @override
  Future<List<Habit>> loadHabits() async => habits;

  @override
  Future<void> saveHabits(List<Habit> habits) async {
    this.habits = habits;
  }
}

void main() {
  testWidgets('creates a targeted habit and tracks today progress', (
    tester,
  ) async {
    final repository = _MemoryHabitRepository();
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add your first habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Drink water');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.enterText(find.byType(TextField).at(2), 'glasses');
    await tester.tap(find.text('Save habit'));
    await tester.pumpAndSettle();

    expect(find.text('0 / 2 glasses'), findsOneWidget);
    expect(repository.habits.single.target, 2);

    await tester.tap(find.byTooltip('Add one glasses'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 glasses'), findsOneWidget);

    await tester.tap(find.byTooltip('Add one glasses'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2 glasses'), findsOneWidget);
    expect(repository.habits.single.isCompleteOn(DateTime.now()), isTrue);
  });
}
