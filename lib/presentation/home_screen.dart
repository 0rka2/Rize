import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'add_habit_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_icons.dart';

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
    final settings = await Navigator.of(context).push<HabitSettings>(
      MaterialPageRoute(builder: (_) => const AddHabitScreen()),
    );
    if (settings == null || !mounted) return;

    final habit = Habit(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: settings.name,
    ).withSettings(settings);
    await _saveHabits([..._habits, habit]);
  }

  Future<Habit?> _editHabit(Habit habit) async {
    final settings = await Navigator.of(context).push<HabitSettings>(
      MaterialPageRoute(builder: (_) => AddHabitScreen(habit: habit)),
    );
    if (settings == null || !mounted) return null;

    final updatedHabit = habit.withSettings(settings);
    final updated =
        _habits
            .map((item) => item.id == habit.id ? updatedHabit : item)
            .toList();
    final saved = await _saveHabits(updated);
    return saved ? updatedHabit : null;
  }

  Future<void> _openDetails(Habit habit) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => HabitDetailScreen(
              habit: habit,
              repository: widget.repository,
              onEdit:
                  () => _editHabit(
                    _habits.firstWhere((item) => item.id == habit.id),
                  ),
            ),
      ),
    );
  }

  Future<void> _trackHabit(Habit habit) async {
    final today = DateTime.now();
    if (habit.trackingMode == TrackingMode.yesNo) {
      final updated =
          _habits
              .map((item) => item.id == habit.id ? item.toggleDay(today) : item)
              .toList();
      await _saveHabits(updated);
      return;
    }

    final updated = <Habit>[];
    final reachedDailyGoal =
        habit.type == HabitType.build &&
        (habit.trackingMode == TrackingMode.count ||
            habit.trackingMode == TrackingMode.measure) &&
        habit.countOn(today) >= habit.target;
    if (habit.tapAction == TapAction.enterTotal || reachedDailyGoal) {
      final entered = await _askForTotal(habit);
      if (entered == null || !mounted) return;
      for (final item in _habits) {
        updated.add(item.id == habit.id ? item.setCount(today, entered) : item);
      }
    } else {
      for (final item in _habits) {
        updated.add(item.id == habit.id ? item.addCount(today) : item);
      }
    }
    await _saveHabits(updated);
  }

  Future<double?> _askForTotal(Habit habit) async {
    return showDialog<double>(
      context: context,
      builder: (_) => _TotalEditorDialog(habit: habit),
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
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadHabits,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Today',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                        ),
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
              ),
            ),
            if (_hasStorageError)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(child: _StorageMessage()),
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
                        today: DateTime.now(),
                        onOpen: () => _openDetails(habit),
                        onTrack: () => _trackHabit(habit),
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

class _TotalEditorDialog extends StatefulWidget {
  const _TotalEditorDialog({required this.habit});

  final Habit habit;

  @override
  State<_TotalEditorDialog> createState() => _TotalEditorDialogState();
}

class _TotalEditorDialogState extends State<_TotalEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.habit.countOn(DateTime.now()).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'Today’s ${widget.habit.unit.isEmpty ? 'total' : widget.habit.unit}',
    ),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: const InputDecoration(labelText: 'Total'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = double.tryParse(_controller.text);
          if (value != null && value >= 0) Navigator.pop(context, value);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.today,
    required this.onOpen,
    required this.onTrack,
  });

  final Habit habit;
  final DateTime today;
  final VoidCallback onOpen;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.colorValue);
    final completedToday = habit.isCompleteOn(today);
    return Material(
      color: AppColors.charcoalGrey,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.coolGrey.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(habitIcon(habit.icon), color: color, size: 27),
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (habit.description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            habit.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.coolGrey),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: IconButton.filled(
                      tooltip:
                          habit.type == HabitType.quit
                              ? 'Record a slip'
                              : habit.trackingMode == TrackingMode.yesNo
                              ? (completedToday
                                  ? 'Mark incomplete'
                                  : 'Mark complete')
                              : 'Track today',
                      onPressed: onTrack,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            completedToday
                                ? color
                                : color.withValues(alpha: 0.2),
                        foregroundColor:
                            completedToday ? AppColors.carbon : color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      icon: Icon(
                        completedToday
                            ? Icons.check_rounded
                            : Icons.check_rounded,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _WeekMarks(habit: habit, today: today, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekMarks extends StatelessWidget {
  const _WeekMarks({
    required this.habit,
    required this.today,
    required this.color,
  });

  final Habit habit;
  final DateTime today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final localToday = DateTime(today.year, today.month, today.day);
    final monday = localToday.subtract(Duration(days: localToday.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(
            child: Builder(
              builder: (context) {
                final day = monday.add(Duration(days: index));
                final isFuture = day.isAfter(localToday);
                final complete = !isFuture && habit.isCompleteOn(day);
                final hasProgress = !isFuture && habit.countOn(day) > 0;
                final label = labels[index];
                return Column(
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.coolGrey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color:
                            complete
                                ? color
                                : hasProgress
                                ? color.withValues(alpha: 0.45)
                                : AppColors.carbon,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              complete || hasProgress
                                  ? color
                                  : AppColors.coolGrey.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.coolGrey),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAddHabit,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add your first habit'),
        ),
      ],
    ),
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
