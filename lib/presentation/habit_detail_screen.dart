import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'habit_category_picker.dart';
import 'habit_heatmap.dart';
import 'habit_icons.dart';
import 'habit_note_editor.dart';
import 'repeat_picker_screen.dart' show specificDaysLabel;

class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({
    required this.habit,
    required this.repository,
    required this.onEdit,
    required this.onTrackDay,
    this.onSetSlipDay,
    this.onSetStartDate,
    super.key,
  });

  final Habit habit;
  final HabitRepository repository;
  final Future<Habit?> Function() onEdit;
  final Future<Habit?> Function(DateTime day) onTrackDay;
  final Future<Habit?> Function(DateTime day, bool isSlip)? onSetSlipDay;
  final Future<Habit?> Function(DateTime day)? onSetStartDate;

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

  Future<void> _addNote() =>
      _editNoteForDay(DateTime.now(), allowDateChange: true);

  Future<Habit?> _setSlipForDay(DateTime day, bool isSlip) async {
    final updated = await widget.onSetSlipDay?.call(day, isSlip);
    if (updated != null && mounted) setState(() => _habit = updated);
    return updated;
  }

  Future<void> _editNoteForDay(
    DateTime day, {
    bool allowDateChange = false,
  }) async {
    final key = dayKey(day);
    if (!_notes.containsKey(key) && !canCreateHabitNoteOn(day)) return;
    final savedNote = await showHabitNoteEditor(
      context,
      day: day,
      habit: _habit,
      notes: _notes,
      repository: widget.repository,
      allowDateChange: allowDateChange,
      onSetSlip: widget.onSetSlipDay == null ? null : _setSlipForDay,
    );
    if (savedNote == null || !mounted) return;

    _applyNoteChange(dayKey(savedNote.day), savedNote.content);
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
              onSetSlipDay: widget.onSetSlipDay == null ? null : _setSlipForDay,
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

  Future<void> _chooseMonth() async {
    var chosenMonth = _visibleMonth;
    final month = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose Date',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.monthYear,
                      initialDateTime: _visibleMonth,
                      onDateTimeChanged: (date) => chosenMonth = date,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, chosenMonth),
                    child: const Text('Go'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
    );
    if (!mounted || month == null) return;
    setState(() => _visibleMonth = month);
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = DateTime(day.year, day.month, day.day);
      _visibleMonth = DateTime(day.year, day.month);
    });
  }

  Future<void> _handleCalendarDayTap(DateTime day) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final startDate = DateUtils.dateOnly(_habit.startDate ?? today);
    final selectedDay = DateUtils.dateOnly(day);
    _selectDay(day);

    if (_habit.type == HabitType.quit &&
        selectedDay.isBefore(startDate) &&
        !selectedDay.isAfter(today)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _EarlierStartDateDialog(date: selectedDay),
      );
      if (confirmed != true || !mounted || widget.onSetStartDate == null) {
        return;
      }

      final updated = await widget.onSetStartDate!(selectedDay);
      if (updated != null && mounted) setState(() => _habit = updated);
      return;
    }

    final updated = await widget.onTrackDay(day);
    if (!mounted) return;
    if (updated != null) setState(() => _habit = updated);
    if (_habit.type == HabitType.quit) await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_habit.colorValue);
    final textTheme = Theme.of(context).textTheme;
    final sectionHeading = textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final recentNotes = _sortedNotes().take(3).toList();
    final showEmptyNotes = !_loadingNotes && !_noteError && recentNotes.isEmpty;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final heatmapStart = _heatmapStart(today);
    final streak = _habit.calendarDayStreak(today);
    final (goalTitle, goalLabel, goalReached) = _repeatProgress(_habit, today);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Habit detail'),
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
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_habit.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _habit.description,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.coolGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_habit.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final category in _habit.categories)
                    Chip(
                      avatar: HabitCategoryIcon(category: category),
                      label: Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            HabitProgressIndicators(
              streakLabel: '$streak ${streak == 1 ? 'day' : 'days'}',
              goalTitle: goalTitle,
              goalLabel: goalLabel,
              goalReached: goalReached,
              color: color,
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text('History', style: sectionHeading),
            ),
            const SizedBox(height: 8),
            _HeatmapCard(
              habit: _habit,
              noteDays: _notes.keys.toSet(),
              startDate: heatmapStart,
              endDate: today,
              onSelectDay: _selectDay,
            ),
            const SizedBox(height: 12),
            _CalendarCard(
              habit: _habit,
              noteDays: _notes.keys.toSet(),
              visibleMonth: _visibleMonth,
              selectedDay: _selectedDay,
              onChooseMonth: _chooseMonth,
              onMonthChanged: (month) {
                setState(() => _visibleMonth = month);
              },
              onPreviousMonth: () => _changeMonth(-1),
              onNextMonth: () => _changeMonth(1),
              onSelectDay: _selectDay,
              onTrackDay: _handleCalendarDayTap,
              onEditNoteForDay: (day) {
                _selectDay(day);
                _editNoteForDay(day);
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Notes', style: sectionHeading),
                  ),
                ),
                if (!showEmptyNotes) ...[
                  Text(
                    '${_notes.length}',
                    key: const Key('notes-count'),
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.coolGrey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: _openAllNotes,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('All notes'),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
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
                spacing: 10,
                children: [
                  if (showEmptyNotes)
                    _EmptyNotes(onAdd: _addNote)
                  else if (_loadingNotes)
                    const Center(child: CircularProgressIndicator())
                  else
                    for (final entry in recentNotes)
                      _NotePreviewCard(
                        entry: entry,
                        onTap: () => _editNoteForDay(_dateFromKey(entry.key)),
                      ),
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

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accentBackground = AppColors.burntOrange.withValues(alpha: 0.14);

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accentBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.edit_note_rounded,
            color: AppColors.burntOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No notes yet',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'What went well? What got in the way?',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.coolGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Add note',
          onPressed: onAdd,
          style: IconButton.styleFrom(
            backgroundColor: accentBackground,
            foregroundColor: AppColors.burntOrange,
          ),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class HabitNotesScreen extends StatefulWidget {
  const HabitNotesScreen({
    required this.habit,
    required this.repository,
    required this.initialNotes,
    required this.onSetSlipDay,
    required this.onNotesChanged,
    super.key,
  });

  final Habit habit;
  final HabitRepository repository;
  final Map<String, String> initialNotes;
  final Future<Habit?> Function(DateTime day, bool isSlip)? onSetSlipDay;
  final ValueChanged<Map<String, String>> onNotesChanged;

  @override
  State<HabitNotesScreen> createState() => _HabitNotesScreenState();
}

class _HabitNotesScreenState extends State<HabitNotesScreen> {
  late Map<String, String> _notes;
  late Habit _habit;
  bool _loading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _notes = Map.of(widget.initialNotes);
    _habit = widget.habit;
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

  Future<void> _editNote(DateTime day, {bool allowDateChange = false}) async {
    final savedNote = await showHabitNoteEditor(
      context,
      day: day,
      habit: _habit,
      notes: _notes,
      repository: widget.repository,
      allowDateChange: allowDateChange,
      onSetSlip: widget.onSetSlipDay == null ? null : _setSlipForDay,
    );
    if (savedNote == null || !mounted) return;

    final key = dayKey(savedNote.day);
    final content = savedNote.content;
    final updated = Map<String, String>.of(_notes);
    if (content.isEmpty) {
      updated.remove(key);
    } else {
      updated[key] = content;
    }
    setState(() => _notes = updated);
    widget.onNotesChanged(Map.of(updated));
  }

  Future<void> _addNote() => _editNote(DateTime.now(), allowDateChange: true);

  Future<Habit?> _setSlipForDay(DateTime day, bool isSlip) async {
    final updated = await widget.onSetSlipDay?.call(day, isSlip);
    if (updated != null && mounted) setState(() => _habit = updated);
    return updated;
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
            _habit.name,
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
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(18),
      child: Container(
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit note',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
              ],
            ),
            Text(
              entry.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    ),
  );
}

class _NotePreviewCard extends StatelessWidget {
  const _NotePreviewCard({required this.entry, required this.onTap});

  final MapEntry<String, String> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = entry.key.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    final label = MaterialLocalizations.of(context).formatMediumDate(date);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.carbon,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.coolGrey.withValues(alpha: 0.14),
            ),
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
        ),
      ),
    );
  }
}

class _EarlierStartDateDialog extends StatelessWidget {
  const _EarlierStartDateDialog({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final formattedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(date);
    return AlertDialog(
      title: const Text('Start tracking earlier?'),
      content: Text(
        'Days from $formattedDate on will count as clean — your streak and '
        'graph will start there.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Start from $formattedDate'),
        ),
      ],
    );
  }
}

DateTime _dateFromKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({
    required this.habit,
    required this.noteDays,
    required this.startDate,
    required this.endDate,
    required this.onSelectDay,
  });

  final Habit habit;
  final Set<String> noteDays;
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      color: AppColors.charcoalGrey,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.coolGrey.withValues(alpha: 0.16)),
    ),
    child: HabitHeatmap(
      habit: habit,
      startDate: startDate,
      endDate: endDate,
      noteDays: noteDays,
      onSelectDay: onSelectDay,
      scrollable: true,
    ),
  );
}

class _CalendarCard extends StatefulWidget {
  const _CalendarCard({
    required this.habit,
    required this.noteDays,
    required this.visibleMonth,
    required this.selectedDay,
    required this.onChooseMonth,
    required this.onMonthChanged,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    required this.onTrackDay,
    required this.onEditNoteForDay,
  });

  final Habit habit;
  final Set<String> noteDays;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final VoidCallback onChooseMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<DateTime> onTrackDay;
  final ValueChanged<DateTime> onEditNoteForDay;

  @override
  State<_CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<_CalendarCard> {
  late final PageController _pageController;

  int _pageForMonth(DateTime month) => month.year * 12 + month.month - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _pageForMonth(widget.visibleMonth),
    );
  }

  @override
  void didUpdateWidget(covariant _CalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pageForMonth(oldWidget.visibleMonth) !=
        _pageForMonth(widget.visibleMonth)) {
      final page = _pageForMonth(widget.visibleMonth);
      if (_pageController.hasClients && _pageController.page?.round() != page) {
        _pageController.jumpToPage(page);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localToday = DateUtils.dateOnly(DateTime.now());
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
                onPressed: widget.onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: widget.onChooseMonth,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMonthYear(widget.visibleMonth),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: widget.onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          if (widget.habit.type == HabitType.quit && widget.habit.hasQuitLimit)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Amount / limit · Bar shows how much is left',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.coolGrey),
              ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = (constraints.maxWidth - 3 * 6) / 7;
              final cellHeight = cellWidth.clamp(
                _CalendarDayCell.minHeight(MediaQuery.textScalerOf(context)),
                double.infinity,
              );
              return SizedBox(
                height: cellHeight * 6 + 5 * 5,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    if (page != _pageForMonth(widget.visibleMonth)) {
                      widget.onMonthChanged(
                        DateTime(page ~/ 12, page % 12 + 1),
                      );
                    }
                  },
                  itemBuilder:
                      (context, page) => _buildMonthGrid(
                        DateTime(page ~/ 12, page % 12 + 1),
                        cellHeight,
                        localToday,
                      ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => widget.onSelectDay(localToday),
              icon: const Icon(Icons.today_rounded, size: 18),
              label: const Text('Today'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(DateTime month, double cellHeight, DateTime today) {
    final firstDay = DateTime(month.year, month.month);
    final gridStart = shiftHabitDay(firstDay, 1 - firstDay.weekday);
    final repeatMarks = widget.habit.repeatMarks(
      gridStart,
      shiftHabitDay(gridStart, 41),
      today: today,
    );
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 42,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 3,
        mainAxisExtent: cellHeight,
      ),
      itemBuilder: (context, index) {
        final day = shiftHabitDay(gridStart, index);
        final key = dayKey(day);
        final hasNote = widget.noteDays.contains(key);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onTrackDay(day),
          onLongPress:
              hasNote || canCreateHabitNoteOn(day)
                  ? () => widget.onEditNoteForDay(day)
                  : null,
          child: _CalendarDayCell(
            day: day,
            habit: widget.habit,
            showDetails: day.month == month.month && !day.isAfter(today),
            isSelected: key == dayKey(widget.selectedDay),
            isToday: day == today,
            hasNote: hasNote,
            coveredByRepeat: repeatMarks[key] == RepeatMark.filled,
          ),
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.habit,
    required this.showDetails,
    required this.isSelected,
    required this.isToday,
    required this.hasNote,
    required this.coveredByRepeat,
  });

  static const _dateSize = 12.0;
  static const _detailSize = 10.0;
  static const _lineHeight = 1.2;
  static const _padding = EdgeInsets.symmetric(horizontal: 3, vertical: 4);
  static const _borderWidth = 1.0;
  static const _detailGap = 3.0;
  static const _barRowHeight = 10.0;

  static double minHeight(TextScaler scaler) =>
      (scaler.scale(_dateSize) * _lineHeight).ceilToDouble() +
      (scaler.scale(_detailSize) * _lineHeight).ceilToDouble() +
      _padding.vertical +
      _borderWidth * 2 +
      _detailGap * 2 +
      _barRowHeight;

  final DateTime day;
  final Habit habit;
  final bool showDetails;
  final bool isSelected;
  final bool isToday;
  final bool hasNote;
  final bool coveredByRepeat;

  @override
  Widget build(BuildContext context) {
    final accent = Color(habit.colorValue);
    final warning = Theme.of(context).colorScheme.error;
    final isQuit = habit.type == HabitType.quit;
    final amount = habit.countOn(day);
    final threshold = habit.dailyTrackingThreshold;
    final complete = showDetails && habit.isCompleteOn(day);
    final slip = showDetails && habit.isQuitSlipOn(day);
    final numeric =
        isQuit
            ? habit.hasQuitLimit
            : habit.trackingMode != TrackingMode.yesNo && threshold > 0;
    final showRatio =
        showDetails && numeric && (amount > 0 || complete || slip);
    final showNote = showDetails && hasNote;
    final showCovered = showDetails && coveredByRepeat;

    final status = switch ((isQuit, complete, slip)) {
      (true, _, true) when habit.hasNoteSlipOn(day) => 'Slip recorded',
      (true, _, true) when numeric && amount > threshold =>
        'Daily limit exceeded',
      (true, _, true) => numeric ? 'Daily limit reached' : 'Slip recorded',
      (true, true, _) => numeric ? 'Below daily limit' : 'Slip-free',
      (false, true, _) => numeric ? 'Daily goal reached' : 'Completed',
      (false, false, _) when showRatio => 'In progress',
      _ => showCovered ? 'Covered by Repeat' : null,
    };
    final unit = habit.unit.trim();
    final details = [
      MaterialLocalizations.of(context).formatFullDate(day),
      if (showRatio)
        '${_exactAmount(amount)} of ${_exactAmount(threshold)}'
            '${unit.isEmpty ? '' : ' $unit'}',
      if (status != null) status,
      if (showNote) 'Has note',
    ];

    return Semantics(
      label: details.join('. '),
      excludeSemantics: true,
      selected: isSelected,
      child: Container(
        key: ValueKey('calendar-day-${dayKey(day)}'),
        padding: _padding,
        decoration: BoxDecoration(
          color:
              isSelected || (complete && !isQuit)
                  ? accent.withValues(alpha: 0.18)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected || isToday ? accent : Colors.transparent,
            width: _borderWidth,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _label(
                    '${day.day}',
                    _dateSize,
                    showDetails ? AppColors.offWhite : AppColors.coolGrey,
                  ),
                ),
                if (showNote)
                  const Icon(
                    Icons.notes_rounded,
                    size: 9,
                    color: AppColors.offWhite,
                  ),
              ],
            ),
            if (showRatio) ...[
              const SizedBox(height: _detailGap),
              _label(
                '${_compactAmount(amount)}/${_compactAmount(threshold)}',
                _detailSize,
                slip ? warning : AppColors.offWhite,
              ),
              const SizedBox(height: _detailGap),
              SizedBox(
                height: _barRowHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: habit.dailyProgressOn(day),
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                        backgroundColor: (slip ? warning : AppColors.offWhite)
                            .withValues(alpha: slip ? 0.38 : 0.20),
                        color: accent,
                        trackGap: 0,
                        stopIndicatorRadius: 0,
                      ),
                    ),
                    if (slip) ...[
                      const SizedBox(width: 2),
                      Icon(
                        Icons.close_rounded,
                        size: _barRowHeight,
                        color: warning,
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (complete || slip) ...[
              const SizedBox(height: _detailGap),
              Icon(
                slip ? Icons.close_rounded : Icons.check_rounded,
                size: 14,
                color: slip ? warning : accent,
              ),
            ] else if (showCovered) ...[
              const SizedBox(height: _detailGap),
              _label('Covered', _detailSize, AppColors.coolGrey),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _label(String text, double size, Color color) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontSize: size,
        height: _lineHeight,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );

  static String _exactAmount(double value) =>
      value.toString().replaceFirst(RegExp(r'\.0$'), '');

  static String _compactAmount(double value) {
    if (value > 0 && value < 0.01) return value.toStringAsExponential(1);
    final (scaled, decimals, suffix) = switch (value) {
      >= 1000000 => (value / 1000000, 1, 'M'),
      >= 1000 => (value / 1000, 1, 'k'),
      _ => (value, 2, ''),
    };
    return '${scaled.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.?0+$'), '')}$suffix';
  }
}

(String, String, bool) _repeatProgress(Habit habit, DateTime today) {
  switch (habit.goalPeriod) {
    case GoalPeriod.none:
      if (habit.type == HabitType.build) {
        return ('Repeat', 'No repeat goal', false);
      }
      return (
        'Repeat',
        habit.hasQuitLimit ? 'Everyday' : 'Slip-free days',
        false,
      );
    case GoalPeriod.daily:
      return ('Repeat', 'Every day', false);
    case GoalPeriod.specificDays:
      return ('Repeat', specificDaysLabel(habit.buildRepeat.weekdays), false);
    case GoalPeriod.everyFewDays:
      return ('Repeat', 'Every ${habit.buildRepeat.gapDays} days', false);
    case GoalPeriod.weekly:
    case GoalPeriod.monthly:
      final weekly = habit.goalPeriod == GoalPeriod.weekly;
      final target = weekly ? habit.weeklyGoalTarget : habit.monthlyGoalTarget;
      final title = weekly ? 'Weekly goal' : 'Monthly goal';
      final progress = habit.successfulDaysInPeriod(
        today,
        habit.goalPeriod,
        today: today,
      );
      final unit = target == 1 ? 'day' : 'days';
      return (title, '$progress / $target $unit', progress >= target);
  }
}

DateTime _addMonths(DateTime date, int months) {
  final firstOfMonth = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
  return DateTime(
    firstOfMonth.year,
    firstOfMonth.month,
    date.day > lastDay ? lastDay : date.day,
  );
}

DateTime _heatmapStart(DateTime today) => _addMonths(today, -12);
