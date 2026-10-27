import 'package:flutter/material.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'habit_icons.dart';

class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({
    required this.habit,
    required this.repository,
    required this.onEdit,
    super.key,
  });

  final Habit habit;
  final HabitRepository repository;
  final Future<Habit?> Function() onEdit;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late Habit _habit;
  late DateTime _selectedDay;
  late DateTime _visibleMonth;
  Map<String, String> _notes = {};
  bool _loadingNotes = true;
  bool _noteError = false;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _visibleMonth = DateTime(now.year, now.month);
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await widget.repository.loadNotes(_habit.id);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loadingNotes = false;
        _noteError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingNotes = false;
        _noteError = true;
      });
    }
  }

  Future<void> _editHabit() async {
    final updated = await widget.onEdit();
    if (updated != null && mounted) setState(() => _habit = updated);
  }

  Future<void> _editNote() async {
    final key = dayKey(_selectedDay);
    final savedNote = await showDialog<String>(
      context: context,
      builder:
          (_) => _NoteEditorDialog(
            day: _selectedDay,
            initialNote: _notes[key] ?? '',
          ),
    );
    if (savedNote == null || !mounted) return;

    try {
      await widget.repository.saveNote(_habit.id, _selectedDay, savedNote);
      if (!mounted) return;
      setState(() {
        if (savedNote.trim().isEmpty) {
          _notes.remove(key);
        } else {
          _notes[key] = savedNote.trim();
        }
        _noteError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _noteError = true);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = DateTime(day.year, day.month, day.day);
      _visibleMonth = DateTime(day.year, day.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_habit.colorValue);
    final selectedKey = dayKey(_selectedDay);
    final selectedNote = _notes[selectedKey];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit'),
        actions: [
          IconButton(
            tooltip: 'Edit habit',
            onPressed: _editHabit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(habitIcon(_habit.icon), color: color, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _habit.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_habit.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _habit.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.coolGrey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _CalendarCard(
              habit: _habit,
              noteDays: _notes.keys.toSet(),
              visibleMonth: _visibleMonth,
              selectedDay: _selectedDay,
              onPreviousMonth: () => _changeMonth(-1),
              onNextMonth: () => _changeMonth(1),
              onSelectDay: _selectDay,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppColors.charcoalGrey,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.coolGrey.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.edit_note_rounded, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedNote == null
                              ? 'No note for this day'
                              : 'Note',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedNote ??
                              'Add a reflection for ${MaterialLocalizations.of(context).formatMediumDate(_selectedDay)}.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.coolGrey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: selectedNote == null ? 'Add note' : 'Edit note',
                    onPressed: _editNote,
                    icon: Icon(
                      selectedNote == null
                          ? Icons.add_rounded
                          : Icons.edit_outlined,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (_loadingNotes) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_noteError) ...[
              const SizedBox(height: 12),
              const Text(
                'Your note could not be saved or loaded. Please try again.',
                style: TextStyle(color: AppColors.burntOrange),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({required this.day, required this.initialNote});

  final DateTime day;
  final String initialNote;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(MaterialLocalizations.of(context).formatMediumDate(widget.day)),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: 3,
      maxLines: 6,
      maxLength: 500,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'What went well? What got in the way?',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (widget.initialNote.isNotEmpty)
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Delete'),
        ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.habit,
    required this.noteDays,
    required this.visibleMonth,
    required this.selectedDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDay,
  });

  final Habit habit;
  final Set<String> noteDays;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final today = DateTime.now();
    final localToday = DateTime(today.year, today.month, today.day);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.charcoalGrey,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.coolGrey.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMonthYear(visibleMonth),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (final label in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.coolGrey,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 3,
            ),
            itemBuilder: (context, index) {
              final day = firstDay.add(
                Duration(days: index - (firstDay.weekday - 1)),
              );
              final inMonth = day.month == visibleMonth.month;
              final isSelected = dayKey(day) == dayKey(selectedDay);
              final isToday = dayKey(day) == dayKey(localToday);
              final isFuture = day.isAfter(localToday);
              final value = habit.countOn(day);
              final complete = !isFuture && habit.isCompleteOn(day);
              final partial = value > 0 && !complete;
              final hasNote = noteDays.contains(dayKey(day));
              final accent = Color(habit.colorValue);
              final markColor =
                  habit.type == HabitType.quit
                      ? (value > 0
                          ? AppColors.burntOrange
                          : AppColors.successGreen)
                      : accent;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelectDay(day),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? accent.withValues(alpha: 0.18)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected || isToday ? accent : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              inMonth
                                  ? AppColors.offWhite
                                  : AppColors.coolGrey.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (inMonth &&
                          !isFuture &&
                          (complete || partial || hasNote))
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color:
                                hasNote && !complete && !partial
                                    ? AppColors.offWhite
                                    : partial
                                    ? markColor.withValues(alpha: 0.55)
                                    : markColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => onSelectDay(localToday),
                icon: const Icon(Icons.today_rounded, size: 18),
                label: const Text('Today'),
              ),
              const Spacer(),
              Text(
                _periodProgressLabel(habit, selectedDay),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.coolGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _periodProgressLabel(Habit habit, DateTime day) {
  final progress = habit.successfulDaysInPeriod(day, habit.goalPeriod);
  final reached = habit.periodGoalReached(day);
  return switch (habit.goalPeriod) {
    GoalPeriod.none =>
      habit.type == HabitType.quit
          ? 'Slip-free days'
          : habit.trackingMode == TrackingMode.yesNo
          ? 'Done days are marked'
          : habit.trackingMode == TrackingMode.count
          ? 'Goal: ${habit.target}'
          : 'Goal: ${habit.target} ${habit.unit}'.trim(),
    GoalPeriod.daily => reached ? 'Daily goal reached' : 'Daily goal pending',
    GoalPeriod.weekly =>
      '${reached ? 'Goal reached · ' : ''}$progress / ${habit.weeklyGoalTarget} days this week',
    GoalPeriod.monthly =>
      '${reached ? 'Goal reached · ' : ''}$progress / ${habit.monthlyGoalTarget} days this month',
  };
}
