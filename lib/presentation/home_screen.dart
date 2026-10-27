import 'package:flutter/material.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'add_habit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repository, super.key});

  final HabitRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Habit> _habits = [];
  bool _isLoading = true;
  bool _hasStorageError = false;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    try {
      final habits = await widget.repository.loadHabits();
      if (!mounted) return;
      setState(() {
        _habits = habits;
        _isLoading = false;
        _hasStorageError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasStorageError = true;
      });
    }
  }

  Future<void> _openAddHabit() async {
    final details = await Navigator.of(context).push<(String, int, String)>(
      MaterialPageRoute(builder: (_) => const AddHabitScreen()),
    );
    if (details == null || !mounted) return;

    final habit = Habit(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: details.$1,
      target: details.$2,
      unit: details.$3,
    );
    await _saveHabits([..._habits, habit]);
  }

  Future<void> _changeHabitCount(Habit habit, {required bool add}) async {
    final today = DateTime.now();
    final updated =
        _habits
            .map(
              (item) =>
                  item.id == habit.id
                      ? add
                          ? item.addCount(today)
                          : item.removeCount(today)
                      : item,
            )
            .toList();
    final saved = await _saveHabits(updated);
    if (!saved || !mounted) return;
    final isComplete = updated
        .firstWhere((item) => item.id == habit.id)
        .isCompleteOn(today);
    if (isComplete && add) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Daily target reached. Nice work!'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  Future<bool> _saveHabits(List<Habit> habits) async {
    try {
      await widget.repository.saveHabits(habits);
      if (!mounted) return false;
      setState(() {
        _habits = habits;
        _hasStorageError = false;
      });
      return true;
    } catch (_) {
      if (mounted) setState(() => _hasStorageError = true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final completedCount =
        _habits.where((habit) => habit.isCompleteOn(today)).length;
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(today);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHabits,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateLabel,
                                  style: _mutedTextStyle(context),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            tooltip: 'Add habit',
                            onPressed: _isLoading ? null : _openAddHabit,
                            icon: const Icon(Icons.add_rounded, size: 28),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.burntOrange,
                              foregroundColor: AppColors.carbon,
                              minimumSize: const Size(52, 52),
                            ),
                          ),
                        ],
                      ),
                      if (_habits.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Text(
                          completedCount == _habits.length
                              ? 'You showed up for yourself today.'
                              : '$completedCount of ${_habits.length} habits checked in',
                          style: _mutedTextStyle(context),
                        ),
                      ],
                      if (_hasStorageError) ...[
                        const SizedBox(height: 16),
                        const _StorageMessage(),
                      ],
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_habits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(onAddHabit: _openAddHabit),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final habit = _habits[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HabitCard(
                          habit: habit,
                          isComplete: habit.isCompleteOn(today),
                          streak: habit.currentStreak(today),
                          today: today,
                          onAdd: () => _changeHabitCount(habit, add: true),
                          onRemove: () => _changeHabitCount(habit, add: false),
                        ),
                      );
                    }, childCount: _habits.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddHabit});

  final VoidCallback onAddHabit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 12, 32, 60),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.charcoalGrey,
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Icon(
            Icons.spa_outlined,
            color: AppColors.burntOrange,
            size: 36,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Small steps start here',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose one thing you’d like to make part of your day.',
          textAlign: TextAlign.center,
          style: _mutedTextStyle(context),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAddHabit,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add your first habit'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 22),
          ),
        ),
      ],
    ),
  );
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.isComplete,
    required this.streak,
    required this.today,
    required this.onAdd,
    required this.onRemove,
  });

  final Habit habit;
  final bool isComplete;
  final int streak;
  final DateTime today;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = isComplete ? AppColors.successGreen : AppColors.burntOrange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.charcoalGrey,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.coolGrey.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.spa_outlined, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$streak day${streak == 1 ? '' : 's'} in a row',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.coolGrey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isComplete)
                Icon(Icons.check_circle_rounded, color: accent, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '${habit.countOn(today)} / ${habit.target} ${habit.unit}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.offWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove one ${habit.unit}',
                onPressed: habit.countOn(today) == 0 ? null : onRemove,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 38,
                ),
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: 'Add one ${habit.unit}',
                onPressed: isComplete ? null : onAdd,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 38,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: AppColors.carbon,
                  disabledBackgroundColor: accent.withValues(alpha: 0.35),
                  disabledForegroundColor: AppColors.carbon.withValues(
                    alpha: 0.6,
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TodayProgress(habit: habit, today: today, color: accent),
          const SizedBox(height: 14),
          _WeekHistory(habit: habit, today: today),
        ],
      ),
    );
  }
}

class _TodayProgress extends StatelessWidget {
  const _TodayProgress({
    required this.habit,
    required this.today,
    required this.color,
  });

  final Habit habit;
  final DateTime today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final count = habit.countOn(today);
    if (habit.target > 8) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: count / habit.target,
          minHeight: 8,
          backgroundColor: AppColors.carbon,
          color: color,
        ),
      );
    }

    return Row(
      children: List.generate(
        habit.target,
        (index) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 8,
            margin: EdgeInsets.only(right: index == habit.target - 1 ? 0 : 5),
            decoration: BoxDecoration(
              color: index < count ? color : AppColors.carbon,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekHistory extends StatelessWidget {
  const _WeekHistory({required this.habit, required this.today});

  final Habit habit;
  final DateTime today;

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(7, (index) {
      final todayDate = DateTime(today.year, today.month, today.day);
      final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));
      final day = monday.add(Duration(days: index));
      final count = habit.countOn(day);
      final complete = count >= habit.target;
      final partial = count > 0 && !complete;
      final color =
          complete
              ? AppColors.successGreen
              : partial
              ? AppColors.burntOrange
              : AppColors.coolGrey.withValues(alpha: 0.35);
      final label =
          MaterialLocalizations.of(context).narrowWeekdays[day.weekday % 7];

      return Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.coolGrey),
            ),
            const SizedBox(height: 6),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: partial ? color.withValues(alpha: 0.45) : color,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      partial || complete
                          ? color
                          : color.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      );
    }),
  );
}

class _StorageMessage extends StatelessWidget {
  const _StorageMessage();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.charcoalGrey,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'Your changes may not have been saved. Please try again.',
      style: TextStyle(color: AppColors.burntOrange),
    ),
  );
}

TextStyle? _mutedTextStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.coolGrey);
