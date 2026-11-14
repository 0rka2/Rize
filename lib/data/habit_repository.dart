//DATABASE

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/habit.dart';
import '../domain/habit_category.dart';

class HabitRepository {
  static const _databaseName = 'rize.db';
  static const _databaseVersion = 9;
  static const _createNoteSlips = '''
    CREATE TABLE note_slips (
      habit_id TEXT NOT NULL,
      day TEXT NOT NULL,
      PRIMARY KEY (habit_id, day),
      FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
    )
  ''';
  static const _repeatDefaults = {
    'repeat_weekdays': repeatWeekdays,
    'repeat_gap_days': 5,
    'repeat_count_weeks': 0,
    'repeat_count_months': 0,
    'repeat_fill_weeks': 0,
    'repeat_fill_months': 0,
    'repeat_fill_gaps': 0,
  };

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
        final repeatColumns = _repeatDefaults.entries.map(
          (entry) => '${entry.key} INTEGER NOT NULL DEFAULT ${entry.value}',
        );
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
            monthly_goal_target INTEGER NOT NULL DEFAULT 1,
            start_date TEXT,
            ${repeatColumns.join(', ')},
            quit_limit REAL NOT NULL DEFAULT 0
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
        await database.execute(_createNoteSlips);
        await _createCategories(database);
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
        if (oldVersion < 5) {
          await database.execute(
            'ALTER TABLE habits ADD COLUMN start_date TEXT',
          );
          await database.execute('''
            UPDATE habits
            SET start_date = date('now', 'localtime')
            WHERE habit_type = 'quit'
          ''');
        }
        if (oldVersion < 6) {
          for (final entry in _repeatDefaults.entries) {
            await database.execute(
              'ALTER TABLE habits ADD COLUMN ${entry.key} INTEGER NOT NULL DEFAULT ${entry.value}',
            );
          }
        }
        if (oldVersion < 7) {
          await database.execute(
            'ALTER TABLE habits ADD COLUMN quit_limit REAL NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 8) {
          await database.execute(_createNoteSlips);
        }
        if (oldVersion < 9) {
          await _createCategories(database);
        }
      },
    );
  }

  static Future<void> _createCategories(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        name_key TEXT NOT NULL UNIQUE,
        emoji TEXT,
        position INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE habit_categories (
        habit_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        PRIMARY KEY (habit_id, category_id),
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');
    final batch = database.batch();
    for (final (index, category) in presetHabitCategories.indexed) {
      batch.insert('categories', _categoryValues(category, index));
    }
    await batch.commit(noResult: true);
  }

  Future<List<HabitCategory>> loadCustomCategories() async {
    final database = await _db;
    final rows = await database.query(
      'categories',
      where: 'emoji IS NOT NULL',
      orderBy: 'position',
    );
    return rows.map(_categoryFromRow).toList(growable: false);
  }

  Future<List<Habit>> loadHabits() async {
    final database = await _db;
    return database.transaction(_loadHabits);
  }

  Future<List<Habit>> _loadHabits(Transaction transaction) async {
    final habitRows = await transaction.query('habits', orderBy: 'rowid');
    final checkInRows = await transaction.query('check_ins');
    final slipRows = await transaction.query('note_slips');
    final categoryRows = await transaction.rawQuery('''
      SELECT habit_categories.habit_id, categories.*
      FROM habit_categories
      JOIN categories ON categories.id = habit_categories.category_id
      ORDER BY categories.position
    ''');
    final countsByHabit = <String, Map<String, num>>{};
    final slipsByHabit = <String, Set<String>>{};
    final categoriesByHabit = <String, List<HabitCategory>>{};

    for (final row in checkInRows) {
      final habitId = row['habit_id'] as String;
      final counts = countsByHabit.putIfAbsent(habitId, () => <String, num>{});
      counts[row['day'] as String] = (row['count'] as num).toDouble();
    }
    for (final row in slipRows) {
      slipsByHabit
          .putIfAbsent(row['habit_id'] as String, () => <String>{})
          .add(row['day'] as String);
    }
    for (final row in categoryRows) {
      categoriesByHabit
          .putIfAbsent(row['habit_id'] as String, () => [])
          .add(_categoryFromRow(row));
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
            quitLimit: (row['quit_limit'] as num).toDouble(),
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
            buildRepeat: (
              weekdays: row['repeat_weekdays'] as int,
              gapDays: row['repeat_gap_days'] as int,
              countWeeks: row['repeat_count_weeks'] == 1,
              countMonths: row['repeat_count_months'] == 1,
              fillWeeks: row['repeat_fill_weeks'] == 1,
              fillMonths: row['repeat_fill_months'] == 1,
              fillGaps: row['repeat_fill_gaps'] == 1,
            ),
            startDate:
                row['start_date'] == null
                    ? null
                    : DateTime.parse(row['start_date'] as String),
            dailyCounts: countsByHabit[row['id']] ?? const <String, double>{},
            noteSlipDays: slipsByHabit[row['id']] ?? const {},
            categories: List.unmodifiable(categoriesByHabit[row['id']] ?? []),
          ),
        )
        .toList();
  }

  Future<void> saveHabits(
    List<Habit> habits, {
    List<HabitCategory>? customCategories,
  }) async {
    final database = await _db;
    await database.transaction((transaction) async {
      if (customCategories != null) {
        await _saveCustomCategories(transaction, customCategories);
      }
      final existingRows = await transaction.query('habits', columns: ['id']);
      final savedSlips = <String, Set<String>>{};
      for (final row in await transaction.query('note_slips')) {
        savedSlips
            .putIfAbsent(row['habit_id'] as String, () => <String>{})
            .add(row['day'] as String);
      }
      final savedCategoryIds = <String, Set<String>>{};
      for (final row in await transaction.query('habit_categories')) {
        savedCategoryIds
            .putIfAbsent(row['habit_id'] as String, () => <String>{})
            .add(row['category_id'] as String);
      }
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

        await _saveHabitCategories(
          transaction,
          habit,
          savedCategoryIds[habit.id] ?? const {},
        );

        final previousSlips = savedSlips[habit.id] ?? const <String>{};
        for (final day in previousSlips.difference(habit.noteSlipDays)) {
          await transaction.delete(
            'note_slips',
            where: 'habit_id = ? AND day = ?',
            whereArgs: [habit.id, day],
          );
        }
        for (final day in habit.noteSlipDays.difference(previousSlips)) {
          await transaction.insert('note_slips', {
            'habit_id': habit.id,
            'day': day,
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

  static Future<void> _saveCustomCategories(
    Transaction transaction,
    List<HabitCategory> categories,
  ) async {
    final rows = await transaction.query(
      'categories',
      where: 'emoji IS NOT NULL',
    );
    final existingIds = rows.map((row) => row['id'] as String).toSet();
    final incomingIds = categories.map((category) => category.id).toSet();
    for (final id in existingIds.difference(incomingIds)) {
      await transaction.delete('categories', where: 'id = ?', whereArgs: [id]);
    }
    for (final (index, category) in categories.indexed) {
      final position = presetHabitCategories.length + index;
      if (existingIds.contains(category.id)) {
        await transaction.update(
          'categories',
          {'position': position},
          where: 'id = ?',
          whereArgs: [category.id],
        );
      } else {
        await transaction.insert(
          'categories',
          _categoryValues(category, position),
        );
      }
    }
  }

  static Future<void> _saveHabitCategories(
    Transaction transaction,
    Habit habit,
    Set<String> previousIds,
  ) async {
    final categoryIds = habit.categories.map((category) => category.id).toSet();
    for (final id in previousIds.difference(categoryIds)) {
      await transaction.delete(
        'habit_categories',
        where: 'habit_id = ? AND category_id = ?',
        whereArgs: [habit.id, id],
      );
    }
    for (final id in categoryIds.difference(previousIds)) {
      await transaction.insert('habit_categories', {
        'habit_id': habit.id,
        'category_id': id,
      });
    }
  }

  static Map<String, Object?> _categoryValues(
    HabitCategory category,
    int position,
  ) => {
    'id': category.id,
    'name': category.name,
    'name_key': category.name.toLowerCase(),
    'emoji': category.emoji,
    'position': position,
  };

  static HabitCategory _categoryFromRow(Map<String, Object?> row) => (
    id: row['id'] as String,
    name: row['name'] as String,
    emoji: row['emoji'] as String?,
  );

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
    'quit_limit': habit.quitLimit,
    'unit': habit.unit,
    'tap_action': enumValue(habit.tapAction),
    'goal_period': enumValue(habit.goalPeriod),
    'weekly_goal_target': habit.weeklyGoalTarget,
    'monthly_goal_target': habit.monthlyGoalTarget,
    'repeat_weekdays': habit.buildRepeat.weekdays,
    'repeat_gap_days': habit.buildRepeat.gapDays,
    'repeat_count_weeks': habit.buildRepeat.countWeeks ? 1 : 0,
    'repeat_count_months': habit.buildRepeat.countMonths ? 1 : 0,
    'repeat_fill_weeks': habit.buildRepeat.fillWeeks ? 1 : 0,
    'repeat_fill_months': habit.buildRepeat.fillMonths ? 1 : 0,
    'repeat_fill_gaps': habit.buildRepeat.fillGaps ? 1 : 0,
    'start_date': habit.startDate == null ? null : dayKey(habit.startDate!),
  };
}
