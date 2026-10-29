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
              onTrackDay:
                  (day) => _trackHabit(
                    _habits.firstWhere((item) => item.id == habit.id),
                    day,
                  ),
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
