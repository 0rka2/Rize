import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/habit.dart';
import '../domain/habit_category.dart';
import '../theme/app_colors.dart';
import 'habit_category_picker.dart';
import 'habit_icons.dart';
import 'repeat_picker_screen.dart';
import 'unsaved_changes.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({
    this.habit,
    required this.loadCustomCategories,
    required this.onSave,
    super.key,
  });

  final Habit? habit;
  final Future<List<HabitCategory>> Function() loadCustomCategories;
  final Future<bool> Function(HabitSettings, List<HabitCategory>?) onSave;

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  static const _maximumDailyAmount = 999999;

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
    Color(0xFFE53935),
    Color(0xFF3F51E5),
    Color(0xFF00897B),
    Color(0xFFFFAB91),
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetController;
  late final TextEditingController _quitLimitController;
  late final TextEditingController _unitController;
  late int _colorValue;
  late String _icon;
  late HabitType _type;
  late TrackingMode _trackingMode;
  late TapAction _tapAction;
  late GoalPeriod _goalPeriod;
  late int _weeklyGoalTarget;
  late int _monthlyGoalTarget;
  late BuildRepeatOptions _buildRepeat;
  late final List<Object> _initialValues;
  late List<HabitCategory> _categories;
  List<HabitCategory>? _initialCustomCategories;
  List<HabitCategory>? _customCategories;
  bool _loadingCategories = false;
  bool _saving = false;
  bool _saveFailed = false;

  List<Object> get _values => [
    _nameController.text,
    _descriptionController.text,
    _targetController.text,
    _quitLimitController.text,
    _unitController.text,
    _colorValue,
    _icon,
    _type,
    _trackingMode,
    _tapAction,
    _goalPeriod,
    _weeklyGoalTarget,
    _monthlyGoalTarget,
    _buildRepeat,
  ];

  bool get _hasUnsavedChanges {
    if (!listEquals(_categories, widget.habit?.categories ?? const []) ||
        _customCategoriesChanged) {
      return true;
    }
    final values = _values;
    for (var i = 0; i < values.length; i++) {
      if (values[i] != _initialValues[i]) return true;
    }
    return false;
  }

  bool get _customCategoriesChanged =>
      !listEquals(_customCategories, _initialCustomCategories);

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
    final quitLimit = habit?.quitLimit ?? 0;
    _quitLimitController = TextEditingController(
      text:
          quitLimit == quitLimit.truncateToDouble()
              ? quitLimit.toInt().toString()
              : quitLimit.toString(),
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
    _buildRepeat = habit?.buildRepeat ?? defaultBuildRepeat;
    _categories = habit?.categories ?? const [];
    _initialValues = _values;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _quitLimitController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text.trim());
    final quitLimit = double.tryParse(_quitLimitController.text.trim());
    final quitLimitError = _dailyAmountError(quitLimit, isQuit: true);
    final unit = _unitController.text.trim();
    final dailyAmountError = switch ((_type, _trackingMode)) {
      (_, TrackingMode.yesNo) => null,
      (HabitType.quit, _) => quitLimitError,
      (HabitType.build, _) => _dailyAmountError(target, isQuit: false),
    };
    final error =
        name.isEmpty
            ? 'Enter a habit name.'
            : dailyAmountError ??
                (_trackingMode == TrackingMode.measure && unit.isEmpty
                    ? 'Enter a measurement unit, such as minutes or km.'
                    : null);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await widget.onSave(
      HabitSettings(
        name: name,
        description: _descriptionController.text.trim(),
        colorValue: _colorValue,
        icon: _icon,
        type: _type,
        trackingMode: _trackingMode,
        target: target ?? 1,
        quitLimit:
            quitLimitError == null ? quitLimit! : widget.habit?.quitLimit ?? 0,
        unit:
            _trackingMode == TrackingMode.measure
                ? unit
                : _trackingMode == TrackingMode.count
                ? 'times'
                : '',
        tapAction: _tapAction,
        goalPeriod: _effectiveGoalPeriod,
        weeklyGoalTarget: _weeklyGoalTarget,
        monthlyGoalTarget: _monthlyGoalTarget,
        buildRepeat: _buildRepeat,
        categories: _categories,
      ),
      _customCategoriesChanged ? _customCategories : null,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _saveFailed = true;
    });
  }

  String? _dailyAmountError(double? amount, {required bool isQuit}) {
    final label = isQuit ? 'Daily limit' : 'Daily goal';
    if (amount != null && amount > _maximumDailyAmount) {
      return '$label must be 999,999 or less.';
    }
    if (amount == null || !amount.isFinite) {
      return '$label must be a number.';
    }
    if (isQuit) {
      if (amount < 0) return 'Daily limit must be 0 or more.';
      if (_trackingMode == TrackingMode.count &&
          amount != amount.truncateToDouble()) {
        return 'Daily limit must be a whole number.';
      }
    } else if (amount <= 0) {
      return 'Daily goal must be greater than 0.';
    }
    return null;
  }

  TextEditingController get _dailyAmountController =>
      _type == HabitType.quit ? _quitLimitController : _targetController;

  void _adjustDailyGoal(int amount) {
    final minimum = _type == HabitType.quit ? 0 : 1;
    final enteredAmount = double.tryParse(_dailyAmountController.text);
    final current =
        enteredAmount != null && enteredAmount.isFinite
            ? enteredAmount.clamp(minimum, _maximumDailyAmount).toInt()
            : minimum;
    final next = (current + amount).clamp(minimum, _maximumDailyAmount);
    setState(() => _dailyAmountController.text = '$next');
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    color: Color(_colorValue),
    hasUnsavedChanges: () => _hasUnsavedChanges,
    isSaving: () => _saving,
    onSave: _save,
    child: AbsorbPointer(absorbing: _saving, child: _buildForm(context)),
  );

  Widget _buildForm(BuildContext context) {
    final accent = Color(_colorValue);
    final isQuit = _type == HabitType.quit;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit == null ? 'New Habit' : 'Edit Habit'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
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
                        : _trackingMode == TrackingMode.yesNo
                        ? 'Days without a recorded slip count as successful.'
                        : 'Days under your daily limit count as successful.',
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
                  if (_trackingMode == TrackingMode.count) ...[
                    const SizedBox(height: 20),
                    _label(isQuit ? 'Daily limit' : 'Daily goal'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('habit-goal'),
                            controller: _dailyAmountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _decoration(
                              isQuit ? '0 / Day' : '1 / Day',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip:
                              isQuit
                                  ? 'Decrease daily limit'
                                  : 'Decrease daily goal',
                          onPressed: () => _adjustDailyGoal(-1),
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip:
                              isQuit
                                  ? 'Increase daily limit'
                                  : 'Increase daily goal',
                          onPressed: () => _adjustDailyGoal(1),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                  if (_trackingMode == TrackingMode.measure) ...[
                    _label(isQuit ? 'Daily limit' : 'Daily goal'),
                    TextField(
                      key: const Key('habit-goal'),
                      controller: _dailyAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: _decoration(isQuit ? 'Limit' : 'Goal'),
                    ),
                  ],
                  if (isQuit && _trackingMode != TrackingMode.yesNo) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Stay below this amount. Set it to 0 for slip-free days.',
                      style: _hintStyle(context),
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
                      switch (_tapAction) {
                        TapAction.addOne when isQuit =>
                          'Adds one below your daily limit. At the limit, the next tap opens the editor.',
                        TapAction.addOne =>
                          'Adds one up to your daily goal. At the goal, the next tap opens the editor.',
                        TapAction.enterTotal =>
                          'The corner button opens today’s total for editing.',
                      },
                      textAlign: TextAlign.center,
                      style: _hintStyle(context),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(
                        _type == HabitType.build ? 'Repeat' : 'Streak Goal',
                      ),
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
                  const SizedBox(height: 24),
                  _label('Categories'),
                  ListTile(
                    key: const Key('habit-categories'),
                    tileColor: AppColors.charcoalGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppColors.coolGrey.withValues(alpha: 0.2),
                      ),
                    ),
                    title: Text(
                      _categories.isEmpty
                          ? 'None'
                          : _categories
                              .map((category) => category.name)
                              .join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing:
                        _loadingCategories
                            ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.coolGrey,
                            ),
                    onTap: _loadingCategories ? null : _chooseCategories,
                  ),
                ],
              ),
            ),
            if (_saveFailed)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'Could not save the habit. Try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.burntOrange),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: AppColors.carbon,
                  ),
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : widget.habit == null
                        ? 'Save habit'
                        : 'Save changes',
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
          ? 'Record the amount for the day.'
          : 'Log amounts with a unit, such as 2 L of water or 7.5 km.',
  };

  GoalPeriod get _effectiveGoalPeriod =>
      _type == HabitType.quit && !_quitGoalPeriods.contains(_goalPeriod)
          ? GoalPeriod.none
          : _goalPeriod;

  String get _goalPeriodLabel => switch (_effectiveGoalPeriod) {
    GoalPeriod.none => _type == HabitType.build ? 'No repeat goal' : 'None',
    GoalPeriod.daily => _type == HabitType.build ? 'Every day' : 'Daily',
    GoalPeriod.weekly => '$_weeklyGoalTarget days / week',
    GoalPeriod.monthly => '$_monthlyGoalTarget days / month',
    GoalPeriod.specificDays => specificDaysLabel(_buildRepeat.weekdays),
    GoalPeriod.everyFewDays => 'Every ${_buildRepeat.gapDays} days',
  };

  Future<void> _chooseGoalPeriod() async {
    if (_type == HabitType.build) {
      final habit =
          widget.habit ?? Habit(id: '', name: '', startDate: DateTime.now());
      final target = double.tryParse(_targetController.text);
      final selection = await showModalBottomSheet<RepeatSelection>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder:
            (_) => RepeatPickerScreen(
              habit: habit.copyWith(
                colorValue: _colorValue,
                type: HabitType.build,
                trackingMode: _trackingMode,
                target:
                    target != null && target.isFinite && target > 0
                        ? target
                        : habit.target,
                goalPeriod: _goalPeriod,
                weeklyGoalTarget: _weeklyGoalTarget,
                monthlyGoalTarget: _monthlyGoalTarget,
                buildRepeat: _buildRepeat,
              ),
            ),
      );
      if (selection == null || !mounted) return;
      setState(() {
        _goalPeriod = selection.period;
        _weeklyGoalTarget = selection.weeklyTarget;
        _monthlyGoalTarget = selection.monthlyTarget;
        _buildRepeat = selection.options;
      });
      return;
    }

    final selection = await showDialog<(GoalPeriod, int, int)>(
      context: context,
      builder:
          (_) => _GoalPeriodDialog(
            color: Color(_colorValue),
            initialPeriod: _effectiveGoalPeriod,
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

  Future<void> _chooseCategories() async {
    if (_customCategories == null) {
      setState(() => _loadingCategories = true);
      try {
        final categories = await widget.loadCustomCategories();
        if (!mounted) return;
        _initialCustomCategories = categories;
        _customCategories = categories;
      } catch (_) {
        if (mounted && !_saving) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load categories. Try again.'),
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _loadingCategories = false);
      }
    }
    if (_saving || ModalRoute.of(context)?.isCurrent != true) return;
    final selection = await showHabitCategoryPicker(
      context,
      selected: _categories,
      customCategories: _customCategories!,
      color: Color(_colorValue),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _categories = selection.categories;
      _customCategories = selection.customCategories;
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

const _quitGoalPeriods = [
  GoalPeriod.none,
  GoalPeriod.daily,
  GoalPeriod.weekly,
  GoalPeriod.monthly,
];

class _GoalPeriodDialog extends StatefulWidget {
  const _GoalPeriodDialog({
    required this.color,
    required this.initialPeriod,
    required this.weeklyTarget,
    required this.monthlyTarget,
  });

  final GoalPeriod initialPeriod;
  final Color color;
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

  void _save() {
    if (!_isValid) return;
    Navigator.pop(context, (
      _period,
      int.tryParse(_weeklyController.text) ?? 1,
      int.tryParse(_monthlyController.text) ?? 1,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasTarget =
        _period == GoalPeriod.weekly || _period == GoalPeriod.monthly;
    return UnsavedChangesGuard(
      color: widget.color,
      hasUnsavedChanges:
          () =>
              _period != widget.initialPeriod ||
              _weeklyController.text != '${widget.weeklyTarget}' ||
              _monthlyController.text != '${widget.monthlyTarget}',
      onSave: _save,
      child: AlertDialog(
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
              for (final period in _quitGoalPeriods)
                RadioListTile<GoalPeriod>(
                  value: period,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text(switch (period) {
                    GoalPeriod.daily => 'Daily',
                    GoalPeriod.weekly => 'Weekly',
                    GoalPeriod.monthly => 'Monthly',
                    _ => 'None',
                  }),
                  subtitle: switch (period) {
                    GoalPeriod.daily => const Text('Meet the daily habit goal'),
                    GoalPeriod.weekly => const Text(
                      '1–7 successful days each week',
                    ),
                    GoalPeriod.monthly => const Text(
                      '1–31 successful days each month',
                    ),
                    _ => const Text('No period goal'),
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
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isValid ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
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
