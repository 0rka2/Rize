//DATABASE

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/habit.dart';

class HabitRepository {
  static const _databaseName = 'rize.db';
  static const _databaseVersion = 4;

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
            description TEXT NOT NULL DEFAULT '',
            color_value INTEGER NOT NULL DEFAULT 4294932992,
            icon TEXT NOT NULL DEFAULT 'spa',
            habit_type TEXT NOT NULL DEFAULT 'build',
            tracking_mode TEXT NOT NULL DEFAULT 'count',
            target REAL NOT NULL DEFAULT 1,
            unit TEXT NOT NULL DEFAULT 'times',
            tap_action TEXT NOT NULL DEFAULT 'addOne',
            goal_period TEXT NOT NULL DEFAULT 'none',
            weekly_goal_target INTEGER NOT NULL DEFAULT 1,
            monthly_goal_target INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await database.execute('''
          CREATE TABLE check_ins (
            habit_id TEXT NOT NULL,
            day TEXT NOT NULL,
            count REAL NOT NULL DEFAULT 1,
            PRIMARY KEY (habit_id, day),
            FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
          )
        ''');
        await database.execute('''
          CREATE TABLE notes (
            habit_id TEXT NOT NULL,
            day TEXT NOT NULL,
            content TEXT NOT NULL,
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
        if (oldVersion < 3) {
          await database.execute(
            "ALTER TABLE habits ADD COLUMN description TEXT NOT NULL DEFAULT ''",
          );
          await database.execute(
            'ALTER TABLE habits ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4294932992',
          );
          await database.execute(
            "ALTER TABLE habits ADD COLUMN icon TEXT NOT NULL DEFAULT 'spa'",
          );
          await database.execute(
            "ALTER TABLE habits ADD COLUMN habit_type TEXT NOT NULL DEFAULT 'build'",
          );
          await database.execute(
            "ALTER TABLE habits ADD COLUMN tracking_mode TEXT NOT NULL DEFAULT 'count'",
          );
          await database.execute(
            "ALTER TABLE habits ADD COLUMN tap_action TEXT NOT NULL DEFAULT 'addOne'",
          );
          await database.execute('''
            CREATE TABLE check_ins_new (
              habit_id TEXT NOT NULL,
              day TEXT NOT NULL,
              count REAL NOT NULL DEFAULT 1,
              PRIMARY KEY (habit_id, day),
              FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
            )
          ''');
          await database.execute('''
            INSERT INTO check_ins_new (habit_id, day, count)
            SELECT habit_id, day, count FROM check_ins
          ''');
          await database.execute('DROP TABLE check_ins');
          await database.execute(
            'ALTER TABLE check_ins_new RENAME TO check_ins',
          );
          await database.execute('''
            CREATE TABLE notes (
              habit_id TEXT NOT NULL,
              day TEXT NOT NULL,
              content TEXT NOT NULL,
              PRIMARY KEY (habit_id, day),
              FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 4) {
          await database.execute(
            "ALTER TABLE habits ADD COLUMN goal_period TEXT NOT NULL DEFAULT 'none'",
          );
          await database.execute(
            'ALTER TABLE habits ADD COLUMN weekly_goal_target INTEGER NOT NULL DEFAULT 1',
          );
          await database.execute(
            'ALTER TABLE habits ADD COLUMN monthly_goal_target INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );
  }

  Future<List<Habit>> loadHabits() async {
    final database = await _db;
    final habitRows = await database.query('habits', orderBy: 'rowid');
    final checkInRows = await database.query('check_ins');
    final countsByHabit = <String, Map<String, num>>{};

    for (final row in checkInRows) {
      final habitId = row['habit_id'] as String;
      countsByHabit.putIfAbsent(habitId, () => <String, int>{})[row['day']
              as String] =
          (row['count'] as num).toDouble();
    }

    return habitRows
        .map(
          (row) => Habit(
            id: row['id'] as String,
            name: row['name'] as String,
            description: row['description'] as String,
            colorValue: row['color_value'] as int,
            icon: row['icon'] as String,
            type: enumFromName(
              HabitType.values,
              row['habit_type'],
              HabitType.build,
            ),
            trackingMode: enumFromName(
              TrackingMode.values,
              row['tracking_mode'],
              TrackingMode.count,
            ),
            target: (row['target'] as num).toDouble(),
            unit: row['unit'] as String,
            tapAction: enumFromName(
              TapAction.values,
              row['tap_action'],
              TapAction.addOne,
            ),
            goalPeriod: enumFromName(
              GoalPeriod.values,
              row['goal_period'],
              GoalPeriod.none,
            ),
            weeklyGoalTarget: row['weekly_goal_target'] as int,
            monthlyGoalTarget: row['monthly_goal_target'] as int,
            dailyCounts: countsByHabit[row['id']] ?? const <String, double>{},
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
            _habitValues(habit),
            where: 'id = ?',
            whereArgs: [habit.id],
          );
        } else {
          await transaction.insert('habits', {
            'id': habit.id,
            ..._habitValues(habit),
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
            row['day'] as String: (row['count'] as num).toDouble(),
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

  Future<Map<String, String>> loadNotes(String habitId) async {
    final database = await _db;
    final rows = await database.query(
      'notes',
      columns: ['day', 'content'],
      where: 'habit_id = ?',
      whereArgs: [habitId],
    );
    return {
      for (final row in rows) row['day'] as String: row['content'] as String,
    };
  }

  Future<void> saveNote(String habitId, DateTime day, String content) async {
    final database = await _db;
    final key = dayKey(day);
    if (content.trim().isEmpty) {
      await database.delete(
        'notes',
        where: 'habit_id = ? AND day = ?',
        whereArgs: [habitId, key],
      );
      return;
    }
    await database.insert('notes', {
      'habit_id': habitId,
      'day': key,
      'content': content.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, Object?> _habitValues(Habit habit) => {
    'name': habit.name,
    'description': habit.description,
    'color_value': habit.colorValue,
    'icon': habit.icon,
    'habit_type': enumValue(habit.type),
    'tracking_mode': enumValue(habit.trackingMode),
    'target': habit.target,
    'unit': habit.unit,
    'tap_action': enumValue(habit.tapAction),
    'goal_period': enumValue(habit.goalPeriod),
    'weekly_goal_target': habit.weeklyGoalTarget,
    'monthly_goal_target': habit.monthlyGoalTarget,
  };
}
