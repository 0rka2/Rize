//DATABASE

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/habit.dart';

class HabitRepository {
  static const _databaseName = 'rize.db';
  static const _databaseVersion = 2;

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
            name TEXT NOT NULL,
            target INTEGER NOT NULL DEFAULT 1,
            unit TEXT NOT NULL DEFAULT 'times'
          )
        ''');
        await database.execute('''
          CREATE TABLE check_ins (
            habit_id TEXT NOT NULL,
            day TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (habit_id, day),
            FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            "ALTER TABLE habits ADD COLUMN target INTEGER NOT NULL DEFAULT 1",
          );
          await database.execute(
            "ALTER TABLE habits ADD COLUMN unit TEXT NOT NULL DEFAULT 'times'",
          );
          await database.execute(
            'ALTER TABLE check_ins ADD COLUMN count INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );
  }

  Future<List<Habit>> loadHabits() async {
    final database = await _db;
    final habitRows = await database.query('habits', orderBy: 'rowid');
    final checkInRows = await database.query('check_ins');
    final countsByHabit = <String, Map<String, int>>{};

    for (final row in checkInRows) {
      final habitId = row['habit_id'] as String;
      countsByHabit.putIfAbsent(habitId, () => <String, int>{})[row['day']
              as String] =
          row['count'] as int;
    }

    return habitRows
        .map(
          (row) => Habit(
            id: row['id'] as String,
            name: row['name'] as String,
            target: row['target'] as int,
            unit: row['unit'] as String,
            dailyCounts: countsByHabit[row['id']] ?? const <String, int>{},
          ),
        )
        .toList();
  }

  Future<void> saveHabits(List<Habit> habits) async {
    final database = await _db;
    await database.transaction((transaction) async {
      final existingRows = await transaction.query('habits', columns: ['id']);
      final existingIds =
          existingRows.map((row) => row['id'] as String).toSet();
      final incomingIds = habits.map((habit) => habit.id).toSet();

      for (final removedId in existingIds.difference(incomingIds)) {
        await transaction.delete(
          'habits',
          where: 'id = ?',
          whereArgs: [removedId],
        );
      }

      for (final habit in habits) {
        if (existingIds.contains(habit.id)) {
          await transaction.update(
            'habits',
            {'name': habit.name, 'target': habit.target, 'unit': habit.unit},
            where: 'id = ?',
            whereArgs: [habit.id],
          );
        } else {
          await transaction.insert('habits', {
            'id': habit.id,
            'name': habit.name,
            'target': habit.target,
            'unit': habit.unit,
          });
        }

        final savedCheckIns = await transaction.query(
          'check_ins',
          columns: ['day', 'count'],
          where: 'habit_id = ?',
          whereArgs: [habit.id],
        );
        final savedCounts = {
          for (final row in savedCheckIns)
            row['day'] as String: row['count'] as int,
        };

        for (final removedDay in savedCounts.keys.toSet().difference(
          habit.dailyCounts.keys.toSet(),
        )) {
          await transaction.delete(
            'check_ins',
            where: 'habit_id = ? AND day = ?',
            whereArgs: [habit.id, removedDay],
          );
        }
        for (final entry in habit.dailyCounts.entries) {
          final previousCount = savedCounts[entry.key];
          if (previousCount == null) {
            await transaction.insert('check_ins', {
              'habit_id': habit.id,
              'day': entry.key,
              'count': entry.value,
            });
          } else if (previousCount != entry.value) {
            await transaction.update(
              'check_ins',
              {'count': entry.value},
              where: 'habit_id = ? AND day = ?',
              whereArgs: [habit.id, entry.key],
            );
          }
        }
      }
    });
  }
}
