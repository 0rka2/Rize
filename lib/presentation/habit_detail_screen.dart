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
    await _editNoteForDay(_selectedDay);
  }

  Future<void> _editNoteForDay(DateTime day) async {
    final key = dayKey(day);
    final savedNote = await showDialog<String>(
      context: context,
      builder:
          (_) => _NoteEditorDialog(
            day: day,
            initialNote: _notes[key] ?? '',
            repository: widget.repository,
            habitId: _habit.id,
          ),
    );
    if (savedNote == null || !mounted) return;

    _applyNoteChange(key, savedNote);
  }

  void _applyNoteChange(String key, String content) {
    setState(() {
      if (content.isEmpty) {
        _notes.remove(key);
      } else {
        _notes[key] = content;
      }
      _noteError = false;
    });
  }

  Future<void> _openAllNotes() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => HabitNotesScreen(
              habit: _habit,
              repository: widget.repository,
              initialNotes: _notes,
              onNotesChanged: (notes) {
                if (!mounted) return;
                setState(() {
                  _notes = notes;
                  _noteError = false;
                });
              },
            ),
      ),
    );
  }

  List<MapEntry<String, String>> _sortedNotes() {
    final entries = _notes.entries.toList();
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries;
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
    final recentNotes = _sortedNotes().take(3).toList();
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
              hasSelectedNote: _notes.containsKey(dayKey(_selectedDay)),
              onPreviousMonth: () => _changeMonth(-1),
              onNextMonth: () => _changeMonth(1),
              onSelectDay: _selectDay,
              onEditSelectedNote: _editNote,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notes',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${_notes.length}',
                        key: const Key('notes-count'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.coolGrey),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: _openAllNotes,
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('All notes'),
                        iconAlignment: IconAlignment.end,
                      ),
                    ],
                  ),
                  if (_loadingNotes)
                    const Center(child: CircularProgressIndicator())
                  else if (recentNotes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No notes yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.coolGrey,
                        ),
                      ),
                    )
                  else
                    for (final entry in recentNotes) ...[
                      const SizedBox(height: 10),
                      _NotePreviewCard(entry: entry),
                    ],
                ],
              ),
            ),
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
  const _NoteEditorDialog({
    required this.day,
    required this.initialNote,
    required this.repository,
    required this.habitId,
  });

  final DateTime day;
  final String initialNote;
  final HabitRepository repository;
  final String habitId;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

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

  Future<void> _save({bool delete = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final content = delete ? '' : _controller.text.trim();
    try {
      await widget.repository.saveNote(widget.habitId, widget.day, content);
      if (mounted) Navigator.pop(context, content);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Your note could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(MaterialLocalizations.of(context).formatMediumDate(widget.day)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
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
        if (_error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.burntOrange),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (widget.initialNote.isNotEmpty)
        TextButton(
          onPressed: _saving ? null : () => _save(delete: true),
          child: const Text('Delete'),
        ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}

class HabitNotesScreen extends StatefulWidget {
  const HabitNotesScreen({
    required this.habit,
    required this.repository,
    required this.initialNotes,
    required this.onNotesChanged,
    super.key,
  });

  final Habit habit;
  final HabitRepository repository;
  final Map<String, String> initialNotes;
  final ValueChanged<Map<String, String>> onNotesChanged;

  @override
  State<HabitNotesScreen> createState() => _HabitNotesScreenState();
}

class _HabitNotesScreenState extends State<HabitNotesScreen> {
  late Map<String, String> _notes;
  bool _loading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _notes = Map.of(widget.initialNotes);
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await widget.repository.loadNotes(widget.habit.id);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
        _loadError = false;
      });
      widget.onNotesChanged(Map.of(notes));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  List<MapEntry<String, String>> get _sortedNotes {
    final entries = _notes.entries.toList();
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  Future<void> _editNote(DateTime day) async {
    final key = dayKey(day);
    final content = await showDialog<String>(
      context: context,
      builder:
          (_) => _NoteEditorDialog(
            day: day,
            initialNote: _notes[key] ?? '',
            repository: widget.repository,
            habitId: widget.habit.id,
          ),
    );
    if (content == null || !mounted) return;

    final updated = Map<String, String>.of(_notes);
    if (content.isEmpty) {
      updated.remove(key);
    } else {
      updated[key] = content;
    }
    setState(() => _notes = updated);
    widget.onNotesChanged(Map.of(updated));
  }

  Future<void> _addNote() async {
    final day = await showDialog<DateTime>(
      context: context,
      builder: (_) => _NoteDatePickerDialog(),
    );
    if (day != null && mounted) await _editNote(day);
  }

  String _dateLabel(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime(parts[0], parts[1], parts[2]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes'),
          Text(
            widget.habit.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.coolGrey),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Add note for a date',
          onPressed: _addNote,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child:
          _loading && _notes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  if (_loadError)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Notes could not be loaded. Showing the last available notes.',
                        style: TextStyle(color: AppColors.burntOrange),
                      ),
                    ),
                  if (_notes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 36),
                      child: Center(
                        child: Text(
                          'No notes yet. Tap + to add one.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.coolGrey),
                        ),
                      ),
                    )
                  else
                    for (final entry in _sortedNotes)
                      _FullNoteCard(
                        entry: entry,
                        dateLabel: _dateLabel(entry.key),
                        onEdit: () => _editNote(_dateFromKey(entry.key)),
                      ),
                ],
              ),
    ),
  );
}

class _FullNoteCard extends StatelessWidget {
  const _FullNoteCard({
    required this.entry,
    required this.dateLabel,
    required this.onEdit,
  });

  final MapEntry<String, String> entry;
  final String dateLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(16, 12, 10, 14),
    decoration: BoxDecoration(
      color: AppColors.charcoalGrey,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.coolGrey.withValues(alpha: 0.16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: AppColors.coolGrey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Edit note',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
          ],
        ),
        Text(entry.value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class _NotePreviewCard extends StatelessWidget {
  const _NotePreviewCard({required this.entry});

  final MapEntry<String, String> entry;

  @override
  Widget build(BuildContext context) {
    final parts = entry.key.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    final label = MaterialLocalizations.of(context).formatMediumDate(date);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coolGrey.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.coolGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _NoteDatePickerDialog extends StatelessWidget {
  const _NoteDatePickerDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose a date'),
    content: SizedBox(
      width: 340,
      child: CalendarDatePicker(
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
        onDateChanged: (day) => Navigator.pop(context, day),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

DateTime _dateFromKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.habit,
    required this.noteDays,
    required this.visibleMonth,
    required this.selectedDay,
    required this.hasSelectedNote,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    required this.onEditSelectedNote,
  });

  final Habit habit;
  final Set<String> noteDays;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final bool hasSelectedNote;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onEditSelectedNote;

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
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color:
                                    inMonth
                                        ? AppColors.offWhite
                                        : AppColors.coolGrey.withValues(
                                          alpha: 0.45,
                                        ),
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
                      if (inMonth && hasNote)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(
                            Icons.notes_rounded,
                            size: 12,
                            color:
                                isSelected
                                    ? accent
                                    : AppColors.offWhite.withValues(
                                      alpha: 0.75,
                                    ),
                          ),
                        ),
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
              IconButton(
                tooltip:
                    hasSelectedNote
                        ? 'Edit note for selected day'
                        : 'Add note for selected day',
                onPressed: onEditSelectedNote,
                icon: const Icon(Icons.edit_note_rounded),
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
