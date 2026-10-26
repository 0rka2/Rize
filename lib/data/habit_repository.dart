import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/habit.dart';

class HabitRepository {
  static const _databaseName = 'rize.db';
  static const _databaseVersion = 1;

  Future<Database>? _database;

  Future<Database> get _db => _database ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    return openDatabase(
      path.join(databasesPath, _databaseName),
      version: _databaseVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE habits (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE check_ins (
            habit_id TEXT NOT NULL,
            day TEXT NOT NULL,
            PRIMARY KEY (habit_id, day),
            FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<List<Habit>> loadHabits() async {
    final database = await _db;
    final habitRows = await database.query('habits', orderBy: 'rowid');
    final checkInRows = await database.query('check_ins');
    final daysByHabit = <String, Set<String>>{};

    for (final row in checkInRows) {
      final habitId = row['habit_id'] as String;
      daysByHabit.putIfAbsent(habitId, () => <String>{}).add(row['day'] as String);
    }

    return habitRows
        .map(
          (row) => Habit(
            id: row['id'] as String,
            name: row['name'] as String,
            completedDays: daysByHabit[row['id']] ?? const <String>{},
          ),
        )
        .toList();
  }

  Future<void> saveHabits(List<Habit> habits) async {
    final database = await _db;
    await database.transaction((transaction) async {
      final existingRows = await transaction.query('habits', columns: ['id']);
      final existingIds = existingRows.map((row) => row['id'] as String).toSet();
      final incomingIds = habits.map((habit) => habit.id).toSet();

      for (final removedId in existingIds.difference(incomingIds)) {
        await transaction.delete('habits', where: 'id = ?', whereArgs: [removedId]);
      }

      for (final habit in habits) {
        if (existingIds.contains(habit.id)) {
          await transaction.update(
            'habits',
            {'name': habit.name},
            where: 'id = ?',
            whereArgs: [habit.id],
          );
        } else {
          await transaction.insert('habits', {'id': habit.id, 'name': habit.name});
        }

        final savedCheckIns = await transaction.query(
          'check_ins',
          columns: ['day'],
          where: 'habit_id = ?',
          whereArgs: [habit.id],
        );
        final savedDays = savedCheckIns.map((row) => row['day'] as String).toSet();

        for (final removedDay in savedDays.difference(habit.completedDays)) {
          await transaction.delete(
            'check_ins',
            where: 'habit_id = ? AND day = ?',
            whereArgs: [habit.id, removedDay],
          );
        }
        for (final addedDay in habit.completedDays.difference(savedDays)) {
          await transaction.insert(
            'check_ins',
            {'habit_id': habit.id, 'day': addedDay},
          );
        }
      }
    });
  }
}
