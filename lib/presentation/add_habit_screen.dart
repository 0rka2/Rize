import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'habit_icons.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({this.habit, super.key});

  final Habit? habit;

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  static const _colors = <Color>[
    Color(0xFFFF6B70),
    Color(0xFFFF963D),
    Color(0xFFFFC02E),
    Color(0xFFFFD21F),
    Color(0xFFA4E635),
    Color(0xFF45D97C),
    Color(0xFF2ECC9A),
    Color(0xFF24C7C8),
    Color(0xFF22C8E8),
    Color(0xFF38B8E8),
    Color(0xFF629EF3),
    Color(0xFF8189F5),
    Color(0xFFA789F2),
    Color(0xFFC17CF0),
    Color(0xFFD970EA),
    Color(0xFFEB66B0),
    Color(0xFFF56D8D),
    Color(0xFF95A4B8),
    Color(0xFF9299A4),
    Color(0xFFAAAAAA),
    Color(0xFFB1AAA5),
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;
  late int _colorValue;
  late String _icon;
  late HabitType _type;
  late TrackingMode _trackingMode;
  late TapAction _tapAction;
  late GoalPeriod _goalPeriod;
  late int _weeklyGoalTarget;
  late int _monthlyGoalTarget;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _nameController = TextEditingController(text: habit?.name ?? '');
    _descriptionController = TextEditingController(
      text: habit?.description ?? '',
    );
    _targetController = TextEditingController(
      text: (habit?.target ?? 1).toString(),
    );
    _unitController = TextEditingController(
      text:
          habit?.trackingMode == TrackingMode.measure ? habit?.unit ?? '' : '',
    );
    _colorValue = habit?.colorValue ?? _colors.first.toARGB32();
    _icon = habit?.icon ?? 'spa';
    _type = habit?.type ?? HabitType.build;
    _trackingMode = habit?.trackingMode ?? TrackingMode.count;
    _tapAction = habit?.tapAction ?? TapAction.addOne;
    _goalPeriod = habit?.goalPeriod ?? GoalPeriod.none;
    _weeklyGoalTarget = habit?.weeklyGoalTarget ?? 1;
    _monthlyGoalTarget = habit?.monthlyGoalTarget ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final targetText = _targetController.text.trim();
    final target = double.tryParse(targetText);
    final unit = _unitController.text.trim();
    if (name.isEmpty ||
        ((_type == HabitType.build && _trackingMode != TrackingMode.yesNo) &&
            (target == null || target <= 0 || target > 999999)) ||
        (_trackingMode == TrackingMode.measure && unit.isEmpty)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Enter a name, valid goal, and measurement unit.'),
          ),
        );
      return;
    }

    Navigator.of(context).pop(
      HabitSettings(
        name: name,
        description: _descriptionController.text.trim(),
        colorValue: _colorValue,
        icon: _icon,
        type: _type,
        trackingMode: _trackingMode,
        target: target ?? 1,
        unit:
            _trackingMode == TrackingMode.measure
                ? unit
                : _trackingMode == TrackingMode.count
                ? 'times'
                : '',
        tapAction: _tapAction,
        goalPeriod: _goalPeriod,
        weeklyGoalTarget: _weeklyGoalTarget,
        monthlyGoalTarget: _monthlyGoalTarget,
      ),
    );
  }

  void _adjustDailyGoal(int amount) {
    final current = int.tryParse(_targetController.text) ?? 1;
    final next = (current + amount).clamp(1, 999999);
    setState(() => _targetController.text = '$next');
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_colorValue);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit == null ? 'New Habit' : 'Edit Habit'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                children: [
                  Center(
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(36),
                          onTap: _chooseIcon,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Icon(
                              habitIcon(_icon),
                              color: accent,
                              size: 38,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _chooseIcon,
                          child: const Text('Change icon'),
                        ),
                      ],
                    ),
                  ),
                  _label('Name'),
                  TextField(
                    key: const Key('habit-name'),
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 60,
                    decoration: _decoration(
                      'Habit name',
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  _label('Description'),
                  TextField(
                    key: const Key('habit-description'),
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 120,
                    decoration: _decoration(
                      'Add a short description',
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 14),
                  _label('Color'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final color in _colors)
                        _ColorOption(
                          color: color,
                          selected: _colorValue == color.toARGB32(),
                          onTap:
                              () => setState(
                                () => _colorValue = color.toARGB32(),
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _label('Habit type'),
                  _choiceRow<HabitType>(
                    values: HabitType.values,
                    selected: _type,
                    labels: const ['Build a habit', 'Quit a habit'],
                    onSelected: (value) => setState(() => _type = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _type == HabitType.build
                        ? 'Mark each day you complete it.'
                        : 'Days without a recorded slip count as successful.',
                    textAlign: TextAlign.center,
                    style: _hintStyle(context),
                  ),
                  const SizedBox(height: 24),
                  _label('Tracking'),
                  _choiceRow<TrackingMode>(
                    values: TrackingMode.values,
                    selected: _trackingMode,
                    labels: const ['Yes / No', 'Count', 'Measure'],
                    onSelected:
                        (value) => setState(() => _trackingMode = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _trackingDescription,
                    textAlign: TextAlign.center,
                    style: _hintStyle(context),
                  ),
                  if (_trackingMode == TrackingMode.measure) ...[
                    const SizedBox(height: 20),
                    _label('Unit'),
                    TextField(
                      key: const Key('habit-unit'),
                      controller: _unitController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 20,
                      decoration: _decoration(
                        'km, pages, minutes...',
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_trackingMode == TrackingMode.count &&
                      _type == HabitType.build) ...[
                    const SizedBox(height: 20),
                    _label('Daily goal'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('habit-goal'),
                            controller: _targetController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _decoration('1 / Day'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Decrease daily goal',
                          onPressed: () => _adjustDailyGoal(-1),
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: 'Increase daily goal',
                          onPressed: () => _adjustDailyGoal(1),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                  if (_trackingMode == TrackingMode.measure &&
                      _type == HabitType.build) ...[
                    _label('Daily goal'),
                    TextField(
                      key: const Key('habit-goal'),
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: _decoration('Goal'),
                    ),
                  ],
                  if (_trackingMode == TrackingMode.count ||
                      _trackingMode == TrackingMode.measure) ...[
                    const SizedBox(height: 20),
                    _label('On tap'),
                    _choiceRow<TapAction>(
                      values: TapAction.values,
                      selected: _tapAction,
                      labels: const ['Add 1', 'Enter total'],
                      onSelected: (value) => setState(() => _tapAction = value),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tapAction == TapAction.addOne
                          ? _trackingMode == TrackingMode.count ||
                                  _trackingMode == TrackingMode.measure
                              ? 'Adds one. At your goal, opens the editor.'
                              : 'The corner button adds one to today.'
                          : 'The corner button opens today’s total for editing.',
                      textAlign: TextAlign.center,
                      style: _hintStyle(context),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Streak Goal'),
                      InkWell(
                        key: const Key('streak-goal-selector'),
                        onTap: _chooseGoalPeriod,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.charcoalGrey,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.coolGrey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(_goalPeriodLabel)),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.coolGrey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: AppColors.carbon,
                  ),
                  child: Text(
                    widget.habit == null ? 'Save habit' : 'Save changes',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _trackingDescription => switch (_trackingMode) {
    TrackingMode.yesNo => 'Mark the day as done or not done.',
    TrackingMode.count =>
      _type == HabitType.quit
          ? 'Record each slip with a tap or enter the day’s total.'
          : 'Count daily repetitions.',
    TrackingMode.measure =>
      _type == HabitType.quit
          ? 'Record the amount of a slip and keep slip-free days clear.'
          : 'Log amounts with a unit, such as 2 L of water or 7.5 km.',
  };

  String get _goalPeriodLabel => switch (_goalPeriod) {
    GoalPeriod.none => 'None',
    GoalPeriod.daily => 'Daily',
    GoalPeriod.weekly => '$_weeklyGoalTarget days / week',
    GoalPeriod.monthly => '$_monthlyGoalTarget days / month',
  };

  Future<void> _chooseGoalPeriod() async {
    final selection = await showDialog<(GoalPeriod, int, int)>(
      context: context,
      builder:
          (_) => _GoalPeriodDialog(
            initialPeriod: _goalPeriod,
            weeklyTarget: _weeklyGoalTarget,
            monthlyTarget: _monthlyGoalTarget,
          ),
    );
    if (selection == null || !mounted) return;

    setState(() {
      _goalPeriod = selection.$1;
      _weeklyGoalTarget = selection.$2;
      _monthlyGoalTarget = selection.$3;
    });
  }

  void _chooseIcon() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              padding: const EdgeInsets.all(20),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final entry in habitIcons.entries)
                  IconButton.filledTonal(
                    tooltip: entry.key,
                    onPressed: () {
                      setState(() => _icon = entry.key);
                      Navigator.pop(context);
                    },
                    icon: Icon(entry.value),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.coolGrey,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _choiceRow<T extends Enum>({
    required List<T> values,
    required T selected,
    required List<String> labels,
    required ValueChanged<T> onSelected,
  }) => SegmentedButton<T>(
    showSelectedIcon: false,
    segments: [
      for (var i = 0; i < values.length; i++)
        ButtonSegment<T>(value: values[i], label: Text(labels[i])),
    ],
    selected: {selected},
    onSelectionChanged: (selection) => onSelected(selection.first),
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.charcoalGrey,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.coolGrey.withValues(alpha: 0.2)),
    ),
  );

  TextStyle? _hintStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodySmall?.copyWith(color: AppColors.coolGrey);
}

class _GoalPeriodDialog extends StatefulWidget {
  const _GoalPeriodDialog({
    required this.initialPeriod,
    required this.weeklyTarget,
    required this.monthlyTarget,
  });

  final GoalPeriod initialPeriod;
  final int weeklyTarget;
  final int monthlyTarget;

  @override
  State<_GoalPeriodDialog> createState() => _GoalPeriodDialogState();
}

class _GoalPeriodDialogState extends State<_GoalPeriodDialog> {
  late GoalPeriod _period;
  late final TextEditingController _weeklyController;
  late final TextEditingController _monthlyController;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    _weeklyController = TextEditingController(text: '${widget.weeklyTarget}');
    _monthlyController = TextEditingController(text: '${widget.monthlyTarget}');
  }

  @override
  void dispose() {
    _weeklyController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  TextEditingController get _targetController =>
      _period == GoalPeriod.weekly ? _weeklyController : _monthlyController;

  int get _maximum => _period == GoalPeriod.weekly ? 7 : 31;

  bool get _isValid {
    if (_period == GoalPeriod.none || _period == GoalPeriod.daily) return true;
    final target = int.tryParse(_targetController.text);
    return target != null && target >= 1 && target <= _maximum;
  }

  @override
  Widget build(BuildContext context) {
    final hasTarget =
        _period == GoalPeriod.weekly || _period == GoalPeriod.monthly;
    return AlertDialog(
      title: const Text('Streak Goal'),
      scrollable: true,
      content: RadioGroup<GoalPeriod>(
        groupValue: _period,
        onChanged: (value) {
          if (value != null) setState(() => _period = value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final period in GoalPeriod.values)
              RadioListTile<GoalPeriod>(
                value: period,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                title: Text(switch (period) {
                  GoalPeriod.none => 'None',
                  GoalPeriod.daily => 'Daily',
                  GoalPeriod.weekly => 'Weekly',
                  GoalPeriod.monthly => 'Monthly',
                }),
                subtitle: switch (period) {
                  GoalPeriod.none => const Text('No period goal'),
                  GoalPeriod.daily => const Text('Meet the daily habit goal'),
                  GoalPeriod.weekly => const Text(
                    '1–7 successful days each week',
                  ),
                  GoalPeriod.monthly => const Text(
                    '1–31 successful days each month',
                  ),
                },
              ),
            if (hasTarget)
              TextField(
                key: const Key('period-goal-value'),
                controller: _targetController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      _period == GoalPeriod.weekly
                          ? 'Successful days (1–7)'
                          : 'Successful days (1–31)',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _isValid
                  ? () => Navigator.pop(context, (
                    _period,
                    int.tryParse(_weeklyController.text) ?? 1,
                    int.tryParse(_monthlyController.text) ?? 1,
                  ))
                  : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(11),
        ),
      ),
    ),
  );
}
