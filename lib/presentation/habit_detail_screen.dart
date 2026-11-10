import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'habit_heatmap.dart';
import 'habit_icons.dart';
import 'unsaved_changes.dart';

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

  Future<void> _setSlipForDay(DateTime day, bool isSlip) async {
    if (isSlip ? _habit.countOn(day) > 0 : _habit.isSlipFreeOn(day)) return;
    final updated =
        widget.onSetSlipDay == null
            ? await widget.onTrackDay(day)
            : await widget.onSetSlipDay!(day, isSlip);
    if (updated != null && mounted) setState(() => _habit = updated);
  }

  Future<void> _editNoteForDay(
    DateTime day, {
    bool allowDateChange = false,
  }) async {
    final key = dayKey(day);
    if (!_notes.containsKey(key) && !canCreateHabitNoteOn(day)) return;
    final savedNote = await _showNoteEditor(
      context,
      day: day,
      habit: _habit,
      notes: _notes,
      repository: widget.repository,
      allowDateChange: allowDateChange,
      onSetSlip: _setSlipForDay,
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
              onSetSlipDay: (day, isSlip) async {
                final updated =
                    widget.onSetSlipDay == null
                        ? await widget.onTrackDay(day)
                        : await widget.onSetSlipDay!(day, isSlip);
                if (updated != null && mounted) {
                  setState(() => _habit = updated);
                }
                return updated;
              },
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
    if (updated != null && mounted) setState(() => _habit = updated);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_habit.colorValue);
    final recentNotes = _sortedNotes().take(3).toList();
    final showEmptyNotes = !_loadingNotes && !_noteError && recentNotes.isEmpty;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final heatmapStart = _heatmapStart(today);
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
            _HeatmapCard(
              habit: _habit,
              noteDays: _notes.keys.toSet(),
              startDate: heatmapStart,
              endDate: today,
              onSelectDay: _selectDay,
            ),
            const SizedBox(height: 12),
            HabitProgressIndicators(
              streakLabel: _streakLabel(_habit, today),
              goalLabel: _periodProgressLabel(context, _habit, today),
            ),
            const SizedBox(height: 18),
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
                  if (showEmptyNotes)
                    _EmptyNotes(onAdd: _addNote)
                  else
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
                  else
                    for (final entry in recentNotes) ...[
                      const SizedBox(height: 10),
                      _NotePreviewCard(
                        entry: entry,
                        onTap: () => _editNoteForDay(_dateFromKey(entry.key)),
                      ),
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

typedef _SavedNote = ({DateTime day, String content});

Future<_SavedNote?> _showNoteEditor(
  BuildContext context, {
  required DateTime day,
  required Habit habit,
  required Map<String, String> notes,
  required HabitRepository repository,
  required bool allowDateChange,
  required Future<void> Function(DateTime, bool) onSetSlip,
}) => showModalBottomSheet<_SavedNote>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  enableDrag: false,
  builder:
      (_) => _NoteEditor(
        day: DateUtils.dateOnly(day),
        habit: habit,
        notes: notes,
        repository: repository,
        allowDateChange: allowDateChange,
        onSetSlip: onSetSlip,
      ),
);

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({
    required this.day,
    required this.habit,
    required this.notes,
    required this.repository,
    required this.allowDateChange,
    required this.onSetSlip,
  });

  final DateTime day;
  final Habit habit;
  final Map<String, String> notes;
  final HabitRepository repository;
  final bool allowDateChange;
  final Future<void> Function(DateTime, bool) onSetSlip;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _controller;
  late DateTime _day;
  bool _choosingDate = false;
  bool _saving = false;
  String? _error;

  String? get _existingNote => widget.notes[dayKey(_day)];

  @override
  void initState() {
    super.initState();
    _day = widget.day;
    _controller = TextEditingController(text: _existingNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges =>
      _controller.text.trim() != (_existingNote ?? '');

  void _selectDate(DateTime day) {
    setState(() {
      final selectedNote = widget.notes[dayKey(day)];
      if (!DateUtils.isSameDay(day, _day) &&
          (selectedNote != null || _existingNote != null)) {
        _controller.text = selectedNote ?? '';
      }
      _day = day;
      _choosingDate = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_existingNote == null && !canCreateHabitNoteOn(_day)) {
      setState(() => _error = 'New notes cannot be added for future dates.');
      return;
    }
    final content = _controller.text.trim();
    if (_existingNote == null && content.isEmpty) {
      setState(() => _error = 'Write a note before saving.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveNote(widget.habit.id, _day, content);
      if (mounted) Navigator.pop(context, (day: _day, content: content));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Your note could not be saved. Please try again.';
      });
    }
  }

  Future<void> _setSlip(bool isSlip) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSetSlip(_day, isSlip);
      if (mounted) {
        setState(() => _saving = false);
        await Navigator.maybePop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(_day);
    final field = TextField(
      controller: _controller,
      readOnly: _saving,
      minLines: 3,
      maxLines: 6,
      maxLength: 500,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'What went well? What got in the way?',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
    final saveButton = FilledButton(
      onPressed: _saving ? null : _save,
      child: Text(_saving ? 'Saving…' : 'Save'),
    );
    final error = _error;
    final errorText =
        error == null
            ? null
            : Text(error, style: const TextStyle(color: AppColors.burntOrange));

    final color = Color(habit.colorValue);
    final isSlip = habit.countOn(_day) > 0;
    final isSober = habit.isSlipFreeOn(_day);
    return UnsavedChangesGuard(
      color: color,
      hasUnsavedChanges: () => _hasUnsavedChanges,
      isSaving: () => _saving,
      onSave: _save,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child:
                _choosingDate
                    ? Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back to note',
                            onPressed:
                                () => setState(() => _choosingDate = false),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        _NoteCalendar(
                          initialDate: _day,
                          onDateChanged: _selectDate,
                        ),
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.14),
                            foregroundColor: color,
                            child: Icon(habitIcon(habit.icon)),
                          ),
                          title: Text(habit.name),
                          subtitle: Text(
                            DateUtils.isSameDay(_day, DateTime.now())
                                ? 'Today'
                                : dateLabel,
                          ),
                          trailing: IconButton(
                            tooltip: 'Close note editor',
                            onPressed:
                                _saving
                                    ? null
                                    : () => Navigator.maybePop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        field,
                        if (errorText != null) errorText,
                        Row(
                          children: [
                            if (widget.allowDateChange) ...[
                              IconButton.filledTonal(
                                tooltip: 'Choose note date',
                                onPressed:
                                    _saving
                                        ? null
                                        : () {
                                          FocusScope.of(context).unfocus();
                                          setState(() => _choosingDate = true);
                                        },
                                icon: const Icon(Icons.calendar_today_rounded),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(child: saveButton),
                          ],
                        ),
                        if (habit.type == HabitType.quit &&
                            _existingNote != null)
                          Wrap(
                            children: [
                              TextButton(
                                onPressed:
                                    _saving || isSlip
                                        ? null
                                        : () => _setSlip(true),
                                child: Text(
                                  isSlip ? 'Marked as slip' : 'Mark as slip',
                                ),
                              ),
                              TextButton(
                                onPressed:
                                    _saving || isSober
                                        ? null
                                        : () => _setSlip(false),
                                child: Text(
                                  isSober ? 'Marked as sober' : 'Mark as sober',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
          ),
        ),
      ),
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
  final Future<Habit?> Function(DateTime day, bool isSlip) onSetSlipDay;
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
    final savedNote = await _showNoteEditor(
      context,
      day: day,
      habit: _habit,
      notes: _notes,
      repository: widget.repository,
      allowDateChange: allowDateChange,
      onSetSlip: _setSlipForDay,
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

  Future<void> _setSlipForDay(DateTime day, bool isSlip) async {
    if (isSlip ? _habit.countOn(day) > 0 : _habit.isSlipFreeOn(day)) return;
    final updated = await widget.onSetSlipDay(day, isSlip);
    if (updated != null && mounted) setState(() => _habit = updated);
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

class _NoteCalendar extends StatelessWidget {
  const _NoteCalendar({required this.initialDate, required this.onDateChanged});

  final DateTime initialDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final firstDate = DateTime(1900);
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(initialDate);
    return CalendarDatePicker(
      initialDate: day.isBefore(firstDate) || day.isAfter(today) ? today : day,
      firstDate: firstDate,
      lastDate: today,
      onDateChanged: onDateChanged,
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
              // Keep all six weeks visible, including the grid spacing.
              final cellSize = (constraints.maxWidth - 3 * 6) / 7;
              return SizedBox(
                height: cellSize * 6 + 5 * 5,
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
                      (context, page) =>
                          _buildMonthGrid(DateTime(page ~/ 12, page % 12 + 1)),
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

  Widget _buildMonthGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month);
    final localToday = DateUtils.dateOnly(DateTime.now());
    final gridStart = shiftHabitDay(firstDay, 1 - firstDay.weekday);
    final repeatMarks = widget.habit.repeatMarks(
      gridStart,
      shiftHabitDay(gridStart, 41),
      today: localToday,
    );
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 3,
      ),
      itemBuilder: (context, index) {
        final day = shiftHabitDay(gridStart, index);
        final inMonth = day.month == month.month;
        final isSelected = dayKey(day) == dayKey(widget.selectedDay);
        final isToday = dayKey(day) == dayKey(localToday);
        final isFuture = day.isAfter(localToday);
        final value = widget.habit.countOn(day);
        final complete = !isFuture && widget.habit.isCompleteOn(day);
        final slip =
            widget.habit.type == HabitType.quit &&
            value > 0 &&
            !widget.habit.meetsQuitLimit(value);
        final partial =
            value > 0 && !complete && widget.habit.type != HabitType.quit;
        final hasNote = widget.noteDays.contains(dayKey(day));
        final repeatMark = repeatMarks[dayKey(day)];
        final accent = Color(widget.habit.colorValue);
        final markColor = accent;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onTrackDay(day),
          onLongPress:
              hasNote || canCreateHabitNoteOn(day)
                  ? () => widget.onEditNoteForDay(day)
                  : null,
          child: Container(
            key: ValueKey('calendar-day-${dayKey(day)}'),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? accent.withValues(alpha: 0.18)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected || isToday ? accent : Colors.transparent,
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
                          (complete ||
                              partial ||
                              slip ||
                              hasNote ||
                              repeatMark != null))
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color:
                                hasNote &&
                                        !complete &&
                                        !partial &&
                                        !slip &&
                                        repeatMark == null
                                    ? AppColors.offWhite
                                    : slip
                                    ? AppColors.coolGrey
                                    : partial
                                    ? markColor.withValues(alpha: 0.55)
                                    : repeatMark == RepeatMark.free
                                    ? AppColors.coolGrey
                                    : markColor,
                            shape:
                                repeatMark == RepeatMark.filled
                                    ? BoxShape.rectangle
                                    : BoxShape.circle,
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
                              : AppColors.offWhite.withValues(alpha: 0.75),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _periodProgressLabel(BuildContext context, Habit habit, DateTime day) {
  final progress = habit.successfulDaysInPeriod(day, habit.goalPeriod);
  final reached = habit.periodGoalReached(day);
  return switch (habit.goalPeriod) {
    GoalPeriod.none =>
      habit.type == HabitType.quit
          ? (habit.hasQuitLimit ? 'Days within the limit' : 'Slip-free days')
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
    GoalPeriod.specificDays =>
      habit.isCompleteOn(day)
          ? 'Done today'
          : habit.isScheduledOn(day)
          ? 'Scheduled today'
          : 'Free day',
    GoalPeriod.everyFewDays => _rollingGoalLabel(context, habit, day),
  };
}

String _rollingGoalLabel(BuildContext context, Habit habit, DateTime day) {
  final due = habit.nextCheckInDue(day);
  if (due == null || !due.isAfter(shiftHabitDay(day, 0))) return 'Check-in due';
  final date = MaterialLocalizations.of(context).formatMediumDate(due);
  return 'Next check-in · $date';
}

String _streakLabel(Habit habit, DateTime today) {
  if (habit.type != HabitType.quit) {
    final streak = habit.currentStreak(today);
    final unit = switch (habit.goalPeriod) {
      GoalPeriod.everyFewDays => 'check-in',
      GoalPeriod.weekly when habit.countsPeriods => 'week',
      GoalPeriod.monthly when habit.countsPeriods => 'month',
      _ => 'day',
    };
    return '$streak $unit${streak == 1 ? '' : 's'}';
  }

  final todayKey = dayKey(today);
  final missedDays =
      habit.dailyCounts.entries
          .where(
            (entry) =>
                !habit.meetsQuitLimit(entry.value) &&
                entry.key.compareTo(todayKey) <= 0,
          )
          .map((entry) => entry.key)
          .toList()
        ..sort();
  if (missedDays.isEmpty) {
    return habit.hasQuitLimit ? 'No missed days' : 'No slips yet';
  }

  final parts = missedDays.last.split('-').map(int.parse).toList();
  final lastMissedDay = DateTime.utc(parts[0], parts[1], parts[2]);
  final streak =
      DateTime.utc(
        today.year,
        today.month,
        today.day,
      ).difference(lastMissedDay).inDays;
  return '$streak ${streak == 1 ? 'day' : 'days'}';
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
