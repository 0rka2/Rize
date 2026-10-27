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
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const AddHabitScreen()),
    );
    if (name == null || !mounted) return;

    final habit = Habit(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      completedDays: const {},
    );
    await _saveHabits([..._habits, habit]);
  }

  Future<void> _toggleHabit(Habit habit) async {
    final today = DateTime.now();
    final updated = _habits
        .map((item) => item.id == habit.id ? item.toggleCompletion(today) : item)
        .toList();
    final saved = await _saveHabits(updated);
    if (!saved || !mounted) return;
    final isComplete = updated.firstWhere((item) => item.id == habit.id)
        .isCompleteOn(today);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(isComplete ? 'Nice work showing up.' : 'Check-in undone.'),
          duration: const Duration(seconds: 2),
        ),
      );
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
    final completedCount = _habits.where((habit) => habit.isCompleteOn(today)).length;
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.7,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(dateLabel, style: _mutedTextStyle(context)),
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
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final habit = _habits[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _HabitCard(
                            habit: habit,
                            isComplete: habit.isCompleteOn(today),
                            streak: habit.currentStreak(today),
                            onTap: () => _toggleHabit(habit),
                          ),
                        );
                      },
                      childCount: _habits.length,
                    ),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
    required this.onTap,
  });

  final Habit habit;
  final bool isComplete;
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isComplete ? AppColors.successGreen : AppColors.burntOrange;

    return Material(
      color: AppColors.charcoalGrey,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.coolGrey.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.spa_outlined, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (streak > 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        '$streak day${streak == 1 ? '' : 's'} in a row',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.coolGrey),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ExcludeSemantics(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isComplete ? accent : AppColors.carbon,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: isComplete ? 0 : 0.55)),
                  ),
                  child: Icon(
                    isComplete ? Icons.check_rounded : Icons.add_rounded,
                    color: isComplete ? AppColors.carbon : accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
