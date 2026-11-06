import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'add_habit_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_heatmap.dart';
import 'habit_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repository, this.onHabitsChanged, super.key});

  final HabitRepository repository;
  final ValueChanged<List<Habit>>? onHabitsChanged;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Habit> _habits = [];
  bool _isLoading = true;
  bool _hasStorageError = false;

  Future<void> addHabit() => _openAddHabit();

  Future<void> editHabitById(String id) async {
    final matches = _habits.where((habit) => habit.id == id);
    if (matches.isNotEmpty) await _editHabit(matches.first);
  }

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
              onSetSlipDay: (day, isSlip) async {
                final current = _habits.firstWhere(
                  (item) => item.id == habit.id,
                );
                final updatedHabit = current.setCount(day, isSlip ? 1 : 0);
                final updated =
                    _habits
                        .map(
                          (item) => item.id == habit.id ? updatedHabit : item,
                        )
                        .toList();
                final saved = await _saveHabits(updated);
                return saved ? updatedHabit : null;
              },
              onEdit:
                  () => _editHabit(
                    _habits.firstWhere((item) => item.id == habit.id),
                  ),
            ),
      ),
    );
  }

  Future<Habit?> _trackHabit(Habit habit, [DateTime? selectedDate]) async {
    final now = DateTime.now();
    final today = selectedDate ?? DateTime(now.year, now.month, now.day);
    if (habit.trackingMode == TrackingMode.yesNo) {
      final updatedHabit = habit.toggleDay(today);
      final updated =
          _habits
              .map((item) => item.id == habit.id ? updatedHabit : item)
              .toList();
      final saved = await _saveHabits(updated);
      return saved ? updatedHabit : null;
    }

    final canAddOneDirectly =
        habit.type == HabitType.build &&
        habit.trackingMode != TrackingMode.yesNo &&
        habit.tapAction == TapAction.addOne &&
        !habit.isCompleteOn(today);
    if (canAddOneDirectly) {
      final updated =
          _habits
              .map((item) => item.id == habit.id ? habit.addCount(today) : item)
              .toList();
      final saved = await _saveHabits(updated);
      return saved ? updated.firstWhere((item) => item.id == habit.id) : null;
    }

    String initialNote = '';
    try {
      initialNote =
          (await widget.repository.loadNotes(habit.id))[dayKey(today)] ?? '';
    } catch (_) {
      // The tracking sheet remains usable if loading the optional note fails.
    }
    final count = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _DailyTrackingSheet(
            habit: habit,
            today: today,
            repository: widget.repository,
            initialNote: initialNote,
          ),
    );
    if (count == null || !mounted) return null;

    final updatedHabit = habit.setCount(today, count);
    final updated =
        _habits
            .map((item) => item.id == habit.id ? updatedHabit : item)
            .toList();
    final saved = await _saveHabits(updated);
    return saved ? updatedHabit : null;
  }

  Future<bool> _saveHabits(List<Habit> habits) async {
    try {
      await widget.repository.saveHabits(habits);
      if (!mounted) return false;
      setState(() {
        _habits = habits;
        _hasStorageError = false;
      });
      widget.onHabitsChanged?.call(habits);
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
                        key: ValueKey(habit.id),
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

enum _UnsavedChangesChoice { save, discard, cancel }

class _DailyTrackingSheet extends StatefulWidget {
  const _DailyTrackingSheet({
    required this.habit,
    required this.today,
    required this.repository,
    required this.initialNote,
  });

  final Habit habit;
  final DateTime today;
  final HabitRepository repository;
  final String initialNote;

  @override
  State<_DailyTrackingSheet> createState() => _DailyTrackingSheetState();
}

class _DailyTrackingSheetState extends State<_DailyTrackingSheet> {
  late final TextEditingController _countController;
  late final TextEditingController _noteController;
  late double _count;
  late double _initialCount;
  late String _note;
  bool _isEditingNote = false;
  bool _allowPop = false;
  bool _showingExitPrompt = false;

  bool get _hasUnsavedChanges =>
      _count != _initialCount || _noteController.text.trim() != _note;

  Habit get _habit => widget.habit;
  bool get _isYesNo => _habit.trackingMode == TrackingMode.yesNo;
  bool get _isQuit => _habit.type == HabitType.quit;
  double get _goal => _isYesNo ? 1 : _habit.target;
  double get _progress =>
      _isQuit ? (_count == 0 ? 1 : 0) : (_count / _goal).clamp(0, 1);

  @override
  void initState() {
    super.initState();
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

  String _formatCount(double value) =>
      value == value.truncateToDouble() ? value.toInt().toString() : '$value';

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
    setState(() => _isEditingNote = true);
  }

  Future<bool> _saveNote() async {
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
      _allowPop = true;
      Navigator.of(context).pop(_count);
    }
  }

  Future<void> _requestClose() async {
    if (!_hasUnsavedChanges) {
      _allowPop = true;
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _confirmExit();
  }

  Future<void> _confirmExit() async {
    if (_showingExitPrompt || !mounted) return;
    _showingExitPrompt = true;
    final choice = await showDialog<_UnsavedChangesChoice>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Save your changes?'),
            content: const Text('Your changes have not been saved.'),
            actions: [
              FilledButton(
                onPressed:
                    () => Navigator.pop(
                      dialogContext,
                      _UnsavedChangesChoice.save,
                    ),
                child: const Text('Save'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(
                      dialogContext,
                      _UnsavedChangesChoice.discard,
                    ),
                child: const Text('Discard'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(
                      dialogContext,
                      _UnsavedChangesChoice.cancel,
                    ),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
    _showingExitPrompt = false;
    if (!mounted) return;

    switch (choice) {
      case _UnsavedChangesChoice.save:
        await _saveTracking();
        return;
      case _UnsavedChangesChoice.discard:
        _allowPop = true;
        Navigator.of(context).pop();
        return;
      case _UnsavedChangesChoice.cancel:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_habit.colorValue);
    final unit = _habit.unit.isEmpty ? 'times' : _habit.unit;
    final percent = (_progress * 100).round();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope<double>(
      canPop: !_hasUnsavedChanges || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasUnsavedChanges) _confirmExit();
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
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
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.coolGrey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
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
                              '${dayKey(widget.today) == dayKey(DateTime.now()) ? 'Today  ·  ' : ''}${_dateLabel(widget.today)}',
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
                        Expanded(
                          child: _quickButton(
                            'Goal',
                            () => _setCount(_habit.target),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      decoration: const InputDecoration(
                        labelText: "Today's note",
                        hintText: 'Add a note about today',
                        border: OutlineInputBorder(),
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
                        onPressed: _isEditingNote ? null : _editNote,
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

class _HabitCard extends StatefulWidget {
  const _HabitCard({
    required this.habit,
    required this.today,
    required this.onOpen,
    required this.onTrack,
    super.key,
  });

  final Habit habit;
  final DateTime today;
  final VoidCallback onOpen;
  final Future<Habit?> Function() onTrack;

  @override
  State<_HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<_HabitCard> {
  int _completionAnimation = 0;

  Future<void> _track() async {
    final wasComplete = widget.habit.isCompleteOn(widget.today);
    final updated = await widget.onTrack();
    if (!mounted || updated == null) return;
    if (!wasComplete &&
        updated.type == HabitType.build &&
        updated.isCompleteOn(widget.today) &&
        !MediaQuery.disableAnimationsOf(context)) {
      setState(() => _completionAnimation++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final today = widget.today;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = Color(habit.colorValue);
    final completedToday = habit.isCompleteOn(today);
    return _CardIgnition(
      color: color,
      completed: completedToday && habit.type == HabitType.build,
      animation: _completionAnimation,
      reduceMotion: reduceMotion,
      habitId: habit.id,
      child: Material(
        color:
            completedToday && habit.type == HabitType.build
                ? Color.alphaBlend(
                  color.withValues(alpha: 0.32),
                  AppColors.charcoalGrey,
                )
                : AppColors.charcoalGrey,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color:
                    completedToday && habit.type == HabitType.build
                        ? color.withValues(alpha: 0.65)
                        : AppColors.coolGrey.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        habitIcon(habit.icon),
                        color: color,
                        size: 25,
                      ),
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
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (habit.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              habit.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: AppColors.coolGrey,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton.filled(
                        tooltip:
                            habit.type == HabitType.quit
                                ? completedToday
                                    ? 'Record a slip'
                                    : 'Clear today’s slip'
                                : habit.trackingMode == TrackingMode.yesNo
                                ? (completedToday
                                    ? 'Mark incomplete'
                                    : 'Mark complete')
                                : 'Track today',
                        onPressed: _track,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              completedToday
                                  ? color
                                  : color.withValues(alpha: 0.10),
                          foregroundColor:
                              completedToday ? AppColors.carbon : color,
                          minimumSize: const Size(48, 48),
                          side:
                              completedToday
                                  ? BorderSide.none
                                  : BorderSide(
                                    color: color.withValues(alpha: 0.55),
                                  ),
                          animationDuration: Duration.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon:
                            habit.type == HabitType.quit
                                ? Icon(
                                  completedToday
                                      ? Icons.check_rounded
                                      : Icons.undo_rounded,
                                  size: 28,
                                )
                                : SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        completedToday
                                            ? Icons
                                                .local_fire_department_rounded
                                            : Icons
                                                .local_fire_department_outlined,
                                        size: 28,
                                      ),
                                      if (completedToday)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              size: 13,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                HabitHeatmap(
                  habit: habit,
                  startDate: DateTime(today.year, today.month, today.day - 179),
                  endDate: today,
                  showMonthLabels: false,
                  showWeekdayLabels: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardIgnition extends StatelessWidget {
  const _CardIgnition({
    required this.color,
    required this.completed,
    required this.animation,
    required this.reduceMotion,
    required this.habitId,
    required this.child,
  });

  final Color color;
  final bool completed;
  final int animation;
  final bool reduceMotion;
  final String habitId;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(animation),
    tween: Tween(begin: animation == 0 || reduceMotion ? 1 : 0, end: 1),
    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 1600),
    child: child,
    builder: (context, progress, child) {
      final ignition = Curves.easeOut.transform(
        (progress / 0.18).clamp(0.0, 1.0),
      );
      final cooling =
          1 -
          Curves.easeInOut.transform(
            ((progress - 0.48) / 0.52).clamp(0.0, 1.0),
          );
      final pulse = !completed || reduceMotion ? 0.0 : ignition * cooling;
      return DecoratedBox(
        key: ValueKey('habit-ignition-$habitId'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha: completed ? 0.16 + 0.32 * pulse : 0,
              ),
              blurRadius: completed ? 8 + 18 * pulse : 0,
              spreadRadius: 2 * pulse,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              child!,
              if (pulse > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _RisingFlamesPainter(
                          color,
                          progress,
                          pulse,
                          habitId.codeUnits.fold<int>(
                            animation * 31,
                            (seed, unit) => (seed * 31 + unit) & 0xFFFF,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _RisingFlamesPainter extends CustomPainter {
  const _RisingFlamesPainter(this.color, this.progress, this.pulse, this.seed);

  final Color color;
  final double progress;
  final double pulse;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final hsl = HSLColor.fromColor(color);
    // Cool accents get a cyan core; other accents retain their chosen hue.
    final coreHue = hsl.hue >= 180 && hsl.hue <= 260 ? hsl.hue - 22 : hsl.hue;
    final core =
        hsl.withHue(coreHue).withSaturation(0.95).withLightness(0.72).toColor();
    final rise = Curves.easeOutCubic.transform(
      (progress / 0.65).clamp(0.0, 1.0),
    );
    final base = size.height + 14;
    final variation = (seed % 997) / 997;
    // A continuous burn front carries the accent across the entire card.
    // Its soft edge follows the taller flames instead of stopping at the grid.
    final front = size.height * (1.15 - rise * 1.4);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color.withValues(alpha: 0.24 * pulse),
            core.withValues(alpha: 0.17 * pulse),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.65, 1],
        ).createShader(Rect.fromLTRB(0, front, size.width, base)),
    );

    // Anchor below the card: no moving horizontal edge can cut the fire off.
    // Rounded curls vary in height, width and phase rather than repeating triangles.
    for (var i = 0; i < 11; i++) {
      final phase =
          i * 2.37 +
          variation * math.pi * 2 +
          progress * math.pi * (3 + variation * 2);
      final x = size.width * (i + 0.4 + 0.14 * math.sin(phase)) / 11;
      final width = size.width / 8 * (0.8 + 0.2 * math.sin(phase));
      final height =
          size.height *
          (0.32 + 1.45 * rise) *
          (0.83 + 0.17 * math.sin(i * 1.73 + variation * 5));
      final curl = width * (0.5 + math.sin(phase) * 0.7);
      final strandHue =
          (hsl.hue + 18 * math.sin(i * 1.91 + variation * 6) + 360) % 360;
      final strand = hsl.withHue(strandHue).withSaturation(0.9).toColor();
      final strandCore = Color.lerp(strand, core, 0.65)!;
      final whiteHot = Color.lerp(strandCore, Colors.white, 0.7)!;
      for (var layer = 0; layer < 3; layer++) {
        final taper = 1 - layer * 0.28;
        final w = width * taper;
        final h = height * (1 - layer * 0.14);
        final tip = base - h;
        final flame =
            Path()
              ..moveTo(x - w, base)
              ..cubicTo(
                x - w * 1.25,
                base - h * 0.28,
                x + curl - w,
                tip + h * 0.52,
                x + curl * 0.2,
                tip + h * 0.28,
              )
              ..cubicTo(
                x + curl * 0.65,
                tip + h * 0.16,
                x + curl,
                tip + h * 0.1,
                x + curl * 0.7,
                tip,
              )
              ..cubicTo(
                x + curl + w * 0.65,
                tip + h * 0.24,
                x - w * 0.2,
                base - h * 0.35,
                x + w * 0.65,
                base - h * 0.22,
              )
              ..quadraticBezierTo(x + w * 1.25, base - h * 0.08, x + w, base)
              ..close();
        final shade =
            layer == 0
                ? strand
                : layer == 1
                ? strandCore
                : whiteHot;
        final paint =
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  shade.withValues(alpha: 0),
                  shade.withValues(alpha: (layer == 0 ? 0.38 : 0.48) * pulse),
                  shade.withValues(alpha: 0),
                ],
                stops: const [0, 0.35, 1],
              ).createShader(Rect.fromLTRB(0, tip, size.width, base));
        if (layer == 0) {
          canvas.drawPath(
            flame,
            Paint()
              ..color = color.withValues(alpha: 0.1 * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }
        canvas.drawPath(flame, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RisingFlamesPainter oldDelegate) =>
      color != oldDelegate.color ||
      seed != oldDelegate.seed ||
      progress != oldDelegate.progress ||
      pulse != oldDelegate.pulse;
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
