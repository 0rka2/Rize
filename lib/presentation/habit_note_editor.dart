import 'package:flutter/material.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'habit_icons.dart';
import 'unsaved_changes.dart';

typedef SavedHabitNote = ({DateTime day, String content});

Future<SavedHabitNote?> showHabitNoteEditor(
  BuildContext context, {
  required DateTime day,
  required Habit habit,
  required Map<String, String> notes,
  required HabitRepository repository,
  required bool allowDateChange,
  Future<Habit?> Function(DateTime, bool)? onSetSlip,
}) => showModalBottomSheet<SavedHabitNote>(
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
  final Future<Habit?> Function(DateTime, bool)? onSetSlip;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _controller;
  late DateTime _day;
  late Habit _habit;
  bool _choosingDate = false;
  bool _saving = false;
  String? _error;

  String? get _existingNote => widget.notes[dayKey(_day)];

  @override
  void initState() {
    super.initState();
    _day = widget.day;
    _habit = widget.habit;
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
    final onSetSlip = widget.onSetSlip;
    if (_saving || onSetSlip == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await onSetSlip(_day, isSlip);
      if (updated == null) throw StateError('Unable to save slip status');
      if (!mounted) return;
      setState(() {
        _habit = updated;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Your slip status could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = _habit;
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
                        if (habit.type == HabitType.quit)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Mark as slip'),
                            value: habit.isQuitSlipOn(_day),
                            activeTrackColor: color,
                            activeThumbColor: AppColors.offWhite,
                            onChanged:
                                _saving || widget.onSetSlip == null
                                    ? null
                                    : _setSlip,
                          ),
                      ],
                    ),
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
