import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'add_habit_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_icons.dart';
import 'habit_note_editor.dart';
import 'today_timeline.dart';
import 'unsaved_changes.dart';

String _formatCount(double value) =>
    value == value.truncateToDouble() ? value.toInt().toString() : '$value';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repository, super.key});

  final HabitRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _editablePastDays = 7;

  List<Habit> _habits = [];
  DateTime? _selectedDay;
  Future<void> _trackingWrites = Future<void>.value();
  bool _trackingEditorOpen = false;
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
      startDate: DateTime.now(),
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
              onTrackDay:
                  (day) => _trackHabit(
                    _habits.firstWhere((item) => item.id == habit.id),
                    day,
                  ),
              onSetStartDate: (day) async {
                final current = _habits.firstWhere(
                  (item) => item.id == habit.id,
                );
                final updatedHabit = current.copyWith(startDate: day);
                final updated =
                    _habits
                        .map(
                          (item) => item.id == habit.id ? updatedHabit : item,
                        )
                        .toList();
                final saved = await _saveHabits(updated);
                return saved ? updatedHabit : null;
              },
              onSetSlipDay:
                  (day, isSlip) => _setNoteSlip(habit.id, day, isSlip),
              onEdit:
                  () => _editHabit(
                    _habits.firstWhere((item) => item.id == habit.id),
                  ),
            ),
      ),
    );
  }

  Future<Habit?> _trackHabit(Habit habit, DateTime day) async {
    if (_trackingEditorOpen) return null;

    if (habit.trackingMode == TrackingMode.yesNo) {
      final result = await _saveTrackingChange(
        habit.id,
        (current) => current.toggleDay(day),
      );
      return result.habit;
    }

    if (habit.tapAction == TapAction.addOne) {
      final result = await _saveTrackingChange(habit.id, (current) {
        return current.countOn(day) < current.dailyTrackingThreshold
            ? current.addCount(day)
            : null;
      });
      if (!result.openEditor) return result.habit;
    }

    return _openTrackingEditor(habit.id, day);
  }

  Future<Habit?> _setNoteSlip(String id, DateTime day, bool isSlip) async {
    final result = await _saveTrackingChange(
      id,
      (habit) => habit.setNoteSlip(day, isSlip),
    );
    return result.habit;
  }

  Future<Habit?> _openTrackingEditor(String id, DateTime day) async {
    if (!mounted || _trackingEditorOpen) return null;
    _trackingEditorOpen = true;
    try {
      String initialNote = '';
      try {
        initialNote =
            (await widget.repository.loadNotes(id))[dayKey(day)] ?? '';
      } catch (_) {
        // The tracking sheet remains usable if loading the optional note fails.
      }
      await _trackingWrites;
      if (!mounted) return null;

      final habit = _habits.firstWhere((item) => item.id == id);
      final count = await showModalBottomSheet<double>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder:
            (_) => _DailyTrackingSheet(
              habit: habit,
              today: day,
              repository: widget.repository,
              initialNote: initialNote,
              onSetSlip: (day, isSlip) => _setNoteSlip(id, day, isSlip),
            ),
      );
      if (!mounted) return null;
      final current = _habits.firstWhere((item) => item.id == id);
      if (count == null) return identical(current, habit) ? null : current;
      // A slip edit already saved the day's state, including a missing count.
      if (count == current.countOn(day) &&
          (current.hasNoteSlipOn(day) || !identical(current, habit))) {
        return current;
      }

      final result = await _saveTrackingChange(
        id,
        (current) => current.setCount(day, count),
      );
      return result.habit;
    } finally {
      _trackingEditorOpen = false;
    }
  }

  Future<({Habit? habit, bool openEditor})> _saveTrackingChange(
    String id,
    Habit? Function(Habit) change,
  ) {
    final write = _trackingWrites.then((_) async {
      if (!mounted) return (habit: null, openEditor: false);
      final current = _habits.firstWhere((habit) => habit.id == id);
      final updated = change(current);
      if (updated == null) return (habit: null, openEditor: true);
      final saved = await _saveHabits([
        for (final habit in _habits) habit.id == id ? updated : habit,
      ]);
      return (habit: saved ? updated : null, openEditor: false);
    });
    _trackingWrites = write.then<void>((_) {});
    return write;
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

  bool _isActiveOn(Habit habit, DateTime day, DateTime today) {
    final key = dayKey(day);
    if (habit.dailyCounts.containsKey(key) || habit.hasNoteSlipOn(day)) {
      return true;
    }
    final start = habit.startDate;
    if (start != null) return !day.isBefore(DateUtils.dateOnly(start));
    return day == today ||
        habit.dailyCounts.keys.any((date) => date.compareTo(key) < 0) ||
        habit.noteSlipDays.any((date) => date.compareTo(key) < 0);
  }

  ({int completed, int active}) _completionForDay(
    DateTime day,
    DateTime today,
  ) {
    var completed = 0;
    var active = 0;
    for (final habit in _habits) {
      if (!_isActiveOn(habit, day, today)) continue;
      active++;
      if (habit.isCompleteOn(day)) completed++;
    }
    return (completed: completed, active: active);
  }

  bool _canTrackTimelineDay(DateTime day, DateTime today) =>
      !day.isBefore(shiftHabitDay(today, -_editablePastDays)) &&
      !day.isAfter(today);

  void _trackTimelineDay(Habit habit, DateTime? selectedDay) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = selectedDay ?? today;
    if (_canTrackTimelineDay(day, today)) _trackHabit(habit, day);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = _selectedDay ?? today;
    final isToday = day == today;
    final canTrack = _canTrackTimelineDay(day, today);
    final activeHabits =
        _habits.where((habit) => _isActiveOn(habit, day, today)).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHabits,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                sliver: SliverToBoxAdapter(
                  child: TodayTimeline(
                    today: today,
                    selectedDay: day,
                    completionForDay: (date) => _completionForDay(date, today),
                    onSelectDay:
                        (date) => setState(() {
                          _selectedDay = date == today ? null : date;
                        }),
                    onAddHabit: _isLoading ? null : _openAddHabit,
                  ),
                ),
              ),
              if (_hasStorageError)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(child: _StorageMessage()),
                ),
              if (!canTrack)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Read-only · Tracking is available for the past $_editablePastDays days.',
                      style: TextStyle(color: AppColors.coolGrey),
                    ),
                  ),
                ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (activeHabits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child:
                      isToday && _habits.isEmpty
                          ? _EmptyState(onAddHabit: _openAddHabit)
                          : const Center(child: Text('No habits on this date')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList.builder(
                    itemCount: activeHabits.length,
                    itemBuilder: (context, index) {
                      final habit = activeHabits[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HabitCard(
                          habit: habit,
                          day: day,
                          isToday: isToday,
                          onOpen: () => _openDetails(habit),
                          onTrack:
                              canTrack
                                  ? () => _trackTimelineDay(
                                    habit,
                                    isToday ? null : day,
                                  )
                                  : null,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyTrackingSheet extends StatefulWidget {
  const _DailyTrackingSheet({
    required this.habit,
    required this.today,
    required this.repository,
    required this.initialNote,
    required this.onSetSlip,
  });

  final Habit habit;
  final DateTime today;
  final HabitRepository repository;
  final String initialNote;
  final Future<Habit?> Function(DateTime day, bool isSlip) onSetSlip;

  @override
  State<_DailyTrackingSheet> createState() => _DailyTrackingSheetState();
}

class _DailyTrackingSheetState extends State<_DailyTrackingSheet> {
  late Habit _habit;
  late final TextEditingController _countController;
  late final TextEditingController _noteController;
  late double _count;
  late double _initialCount;
  late String _note;
  bool _isEditingNote = false;
  double _dragOffset = 0;
  bool _isDragging = false;

  bool get _hasUnsavedChanges =>
      _count != _initialCount || _noteController.text.trim() != _note;

  bool get _isYesNo => _habit.trackingMode == TrackingMode.yesNo;
  bool get _isQuit => _habit.type == HabitType.quit;
  bool get _hasSavedNoteSlip =>
      _count == _initialCount && _habit.hasNoteSlipOn(widget.today);
  double get _goal => _isYesNo ? 1 : _habit.dailyTrackingThreshold;
  double get _progress {
    if (_isQuit && !_habit.hasQuitLimit) {
      return !_hasSavedNoteSlip && _habit.meetsQuitLimit(_count) ? 1 : 0;
    }
    return (_count / _goal).clamp(0, 1);
  }

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    _count = _habit.countOn(widget.today);
    _initialCount = _count;
    _note = widget.initialNote;
    _countController = TextEditingController(text: _formatCount(_count));
    _noteController = TextEditingController(text: _note);
  }

  @override
  void dispose() {
    _countController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setCount(double value) {
    final next =
        _isYesNo
            ? value.clamp(0, 1).toDouble()
            : value.clamp(0, 999999).toDouble();
    setState(() {
      _count = next;
      _countController.text = _formatCount(next);
    });
  }

  void _readCount(String value) {
    final parsed = double.tryParse(value);
    setState(() => _count = (parsed ?? 0).clamp(0, 999999).toDouble());
  }

  Future<void> _editNote() async {
    if (!_isQuit) {
      setState(() => _isEditingNote = true);
      return;
    }

    FocusScope.of(context).unfocus();
    final savedNote = await showHabitNoteEditor(
      context,
      day: widget.today,
      habit: _habit,
      notes: {if (_note.isNotEmpty) dayKey(widget.today): _note},
      repository: widget.repository,
      allowDateChange: false,
      onSetSlip: _setNoteSlip,
    );
    if (savedNote != null && mounted) {
      setState(() {
        _note = savedNote.content;
        _noteController.text = _note;
      });
    }
  }

  Future<Habit?> _setNoteSlip(DateTime day, bool isSlip) async {
    final updated = await widget.onSetSlip(day, isSlip);
    if (updated == null || !mounted) return updated;

    setState(() {
      final countChanged = _count != _initialCount;
      _habit = updated;
      _initialCount = updated.countOn(day);
      if (!countChanged) {
        _count = _initialCount;
        _countController.text = _formatCount(_count);
      }
    });
    return updated;
  }

  Future<bool> _saveNote() async {
    if (_note.isEmpty && !canCreateHabitNoteOn(widget.today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New notes cannot be added for future dates.'),
        ),
      );
      return false;
    }
    try {
      await widget.repository.saveNote(
        _habit.id,
        widget.today,
        _noteController.text,
      );
      if (mounted) {
        setState(() {
          _note = _noteController.text.trim();
          _isEditingNote = false;
        });
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your note could not be saved.')),
      );
      return false;
    }
  }

  Future<void> _saveTracking() async {
    if (_noteController.text.trim() != _note && !await _saveNote()) return;
    if (mounted) {
      Navigator.of(context).pop(_count);
    }
  }

  Future<void> _requestClose() => Navigator.of(context).maybePop();

  void _updateDrag(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, double.infinity);
    });
  }

  void _endDrag(DragEndDetails details) {
    final shouldClose =
        _dragOffset >= 64 ||
        (_dragOffset > 0 && (details.primaryVelocity ?? 0) > 200);
    if (!shouldClose || _hasUnsavedChanges) _resetDrag();
    if (shouldClose) _requestClose();
  }

  void _resetDrag() {
    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_habit.colorValue);
    final unit = _habit.unit.isEmpty ? 'times' : _habit.unit;
    final percent = (_progress * 100).round();
    final isToday = dayKey(widget.today) == dayKey(DateTime.now());
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return UnsavedChangesGuard(
      color: accent,
      hasUnsavedChanges: () => _hasUnsavedChanges,
      onSave: _saveTracking,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: AnimatedContainer(
            duration:
                _isDragging ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _dragOffset, 0),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF171719),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(
                color: AppColors.coolGrey.withValues(alpha: 0.16),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: const Key('tracking-drag-handle'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _updateDrag,
                    onVerticalDragEnd: _endDrag,
                    onVerticalDragCancel: _resetDrag,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.coolGrey.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          habitIcon(_habit.icon),
                          color: accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _habit.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (_habit.description.isNotEmpty)
                              Text(
                                _habit.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.coolGrey),
                              ),
                            const SizedBox(height: 3),
                            Text(
                              '${isToday ? 'Today  ·  ' : ''}${_dateLabel(widget.today)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.coolGrey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _requestClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_isYesNo)
                    _yesNoControls()
                  else
                    Row(
                      children: [
                        _stepButton(
                          Icons.remove_rounded,
                          'Decrease amount',
                          () => _setCount(_count - 1),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 82,
                            decoration: BoxDecoration(
                              color: AppColors.charcoalGrey,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.coolGrey.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 112,
                                  child: TextField(
                                    key: const Key('tracking-count'),
                                    controller: _countController,
                                    onChanged: _readCount,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal:
                                              _habit.trackingMode ==
                                              TrackingMode.measure,
                                        ),
                                    inputFormatters: [
                                      _habit.trackingMode ==
                                              TrackingMode.measure
                                          ? FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.]'),
                                          )
                                          : FilteringTextInputFormatter
                                              .digitsOnly,
                                    ],
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                    ),
                                  ),
                                ),
                                Text(
                                  unit,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: AppColors.coolGrey),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _stepButton(
                          Icons.add_rounded,
                          'Increase amount',
                          () => _setCount(_count + 1),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 7,
                      backgroundColor: AppColors.coolGrey.withValues(
                        alpha: 0.2,
                      ),
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _goalLabel(unit),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.coolGrey),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.coolGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (!_isYesNo) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _quickButton(
                            '+1',
                            () => _setCount(_count + 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _quickButton(
                            '+5',
                            () => _setCount(_count + 5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!_isQuit) ...[
                          Expanded(
                            child: _quickButton(
                              'Goal',
                              () => _setCount(_habit.target),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: _quickButton('Reset', () => _setCount(0)),
                        ),
                      ],
                    ),
                  ],
                  if (_isEditingNote) ...[
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('tracking-note-input'),
                      controller: _noteController,
                      autofocus: true,
                      maxLines: 3,
                      maxLength: 500,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText:
                            isToday ? "Today's note" : 'Note for this date',
                        hintText:
                            isToday
                                ? 'Add a note about today'
                                : 'Add a note for this date',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _saveNote,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save note'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        key: const Key('tracking-note'),
                        tooltip:
                            _isEditingNote
                                ? 'Editing note'
                                : (_note.isEmpty ? 'Add note' : 'Edit note'),
                        onPressed:
                            !_isEditingNote &&
                                    (_note.isNotEmpty ||
                                        canCreateHabitNoteOn(widget.today))
                                ? _editNote
                                : null,
                        icon: Icon(
                          _note.isEmpty
                              ? Icons.edit_note_rounded
                              : Icons.sticky_note_2_rounded,
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(56, 56),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: FilledButton(
                            key: const Key('tracking-save'),
                            onPressed: _saveTracking,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: AppColors.carbon,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              _saveLabel(unit),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _yesNoControls() => Row(
    children: [
      Expanded(
        child: _quickButton(
          _isQuit ? 'Slip-free' : 'Not done',
          () => _setCount(0),
          selected: _count == 0,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _quickButton(
          _isQuit ? 'Slip recorded' : 'Done',
          () => _setCount(1),
          selected: _count > 0,
        ),
      ),
    ],
  );

  Widget _stepButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      SizedBox(
        width: 58,
        height: 82,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.offWhite,
            side: BorderSide(color: AppColors.coolGrey.withValues(alpha: 0.18)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Tooltip(message: tooltip, child: Icon(icon, size: 24)),
        ),
      );

  Widget _quickButton(
    String label,
    VoidCallback onPressed, {
    bool selected = false,
  }) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: selected ? AppColors.offWhite : AppColors.coolGrey,
      backgroundColor: selected ? AppColors.charcoalGrey : Colors.transparent,
      side: BorderSide(color: AppColors.coolGrey.withValues(alpha: 0.16)),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(vertical: 13),
    ),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  String _goalLabel(String unit) {
    if (_hasSavedNoteSlip) return 'Slip recorded';
    if (_isQuit && _habit.hasQuitLimit) {
      return 'Stay under ${_formatCount(_habit.quitLimit)} $unit';
    }
    if (_isQuit) return 'Goal 0 $unit';
    return 'Goal ${_formatCount(_goal)} $unit';
  }

  String _saveLabel(String unit) {
    if (_isYesNo) {
      final selected = _count > 0;
      return _isQuit
          ? (selected ? 'Save slip' : 'Save slip-free day')
          : (selected ? 'Save as done' : 'Save as not done');
    }
    return 'Save ${_formatCount(_count)} $unit';
  }

  String _dateLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.day,
    required this.isToday,
    required this.onOpen,
    required this.onTrack,
  });

  final Habit habit;
  final DateTime day;
  final bool isToday;
  final VoidCallback onOpen;
  final VoidCallback? onTrack;

  String _progressLabel(double amount, double threshold, bool complete) {
    final isYesNo = habit.trackingMode == TrackingMode.yesNo;
    final status = switch (habit.type) {
      HabitType.build when isYesNo => complete ? 'Completed' : 'Not completed',
      HabitType.build => null,
      HabitType.quit when habit.isQuitSlipOn(day) =>
        habit.hasQuitLimit && !habit.hasNoteSlipOn(day)
            ? 'Limit reached'
            : 'Slip recorded',
      HabitType.quit when !complete => 'Not started',
      HabitType.quit when habit.hasQuitLimit => 'Under limit',
      HabitType.quit => 'Slip-free',
    };

    final details = [if (status != null) status];
    if (!isYesNo) {
      final savedUnit = habit.unit.trim();
      final unit = savedUnit.isEmpty ? 'times' : savedUnit;
      details.add('${_formatCount(amount)} / ${_formatCount(threshold)} $unit');
    }
    return '${details.join(' · ')}${isToday ? ' today' : ''}';
  }

  String _trackTooltip(bool complete) {
    if (onTrack == null) return 'Tracking unavailable for this date';
    if (habit.trackingMode != TrackingMode.yesNo) {
      return isToday ? 'Track today' : 'Track this date';
    }
    if (habit.type == HabitType.build) {
      return complete ? 'Mark incomplete' : 'Mark complete';
    }
    if (complete) return 'Record a slip';
    return isToday ? 'Clear today’s slip' : 'Clear slip';
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.colorValue);
    final complete = habit.isCompleteOn(day);
    final isQuit = habit.type == HabitType.quit;
    final amount = habit.countOn(day);
    final threshold = habit.dailyTrackingThreshold;
    var fillStrength = complete ? 1.0 : 0.0;
    if (habit.trackingMode != TrackingMode.yesNo && threshold > 0) {
      final progress = (amount / threshold).clamp(0.0, 1.0);
      fillStrength = isQuit ? (complete ? 1 - progress : 0) : progress;
    }
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
                        const SizedBox(height: 3),
                        Text(
                          _progressLabel(amount, threshold, complete),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.coolGrey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: GestureDetector(
                      // A disabled check button should not open habit details.
                      onTap: onTrack == null ? () {} : null,
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      child: IconButton.filled(
                        tooltip: _trackTooltip(complete),
                        onPressed: onTrack,
                        style: IconButton.styleFrom(
                          backgroundColor: color.withValues(
                            alpha: 0.2 + 0.8 * fillStrength,
                          ),
                          foregroundColor:
                              fillStrength >= 0.5 ? AppColors.carbon : color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 30),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: fillStrength,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: AppColors.coolGrey.withValues(alpha: 0.16),
                  color: color,
                  trackGap: 0,
                  stopIndicatorRadius: 0,
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
