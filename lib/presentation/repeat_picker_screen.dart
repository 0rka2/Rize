import 'package:flutter/material.dart';

import '../domain/habit.dart';

typedef RepeatSelection =
    ({
      GoalPeriod period,
      int weeklyTarget,
      int monthlyTarget,
      BuildRepeatOptions options,
    });

String specificDaysLabel(int weekdays) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return switch (weekdays) {
    repeatAllDays => 'Every day',
    repeatWeekdays => 'Mon–Fri',
    _ => [
      for (var index = 0; index < names.length; index++)
        if (weekdays & (1 << index) != 0) names[index],
    ].join(', '),
  };
}

const _background = Color(0xFF111113);
const _surface = Color(0xFF19191B);
const _border = Color(0xFF2C2C2E);
const _muted = Color(0xFFA1A1AA);
const _text = Color(0xFFF4F4F5);

class RepeatPickerScreen extends StatefulWidget {
  const RepeatPickerScreen({required this.habit, super.key});

  final Habit habit;

  @override
  State<RepeatPickerScreen> createState() => _RepeatPickerScreenState();
}

class _RepeatPickerScreenState extends State<RepeatPickerScreen> {
  static const _periods = [
    GoalPeriod.daily,
    GoalPeriod.specificDays,
    GoalPeriod.weekly,
    GoalPeriod.monthly,
    GoalPeriod.everyFewDays,
  ];

  late final RepeatSelection _initial;
  late RepeatSelection _draft;
  bool _showWeekdays = false;

  Color get _accent => Color(widget.habit.colorValue);
  Color get _selection =>
      Color.alphaBlend(_accent.withValues(alpha: 0.08), _surface);
  Color get _scheduled =>
      Color.alphaBlend(_accent.withValues(alpha: 0.15), _surface);
  Color get _onAccent =>
      ThemeData.estimateBrightnessForColor(_accent) == Brightness.dark
          ? _text
          : _background;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _initial = (
      period: habit.goalPeriod,
      weeklyTarget: habit.weeklyGoalTarget.clamp(1, 7).toInt(),
      monthlyTarget: habit.monthlyGoalTarget.clamp(1, 31).toInt(),
      options: habit.buildRepeat,
    );
    _draft = _initial;
  }

  void _update({
    GoalPeriod? period,
    int? weeklyTarget,
    int? monthlyTarget,
    int? weekdays,
    int? gapDays,
    bool? countWeeks,
    bool? countMonths,
    bool? fillWeeks,
    bool? fillMonths,
    bool? fillGaps,
  }) {
    final options = _draft.options;
    setState(() {
      _draft = (
        period: period ?? _draft.period,
        weeklyTarget: weeklyTarget ?? _draft.weeklyTarget,
        monthlyTarget: monthlyTarget ?? _draft.monthlyTarget,
        options: (
          weekdays: weekdays ?? options.weekdays,
          gapDays: gapDays ?? options.gapDays,
          countWeeks: countWeeks ?? options.countWeeks,
          countMonths: countMonths ?? options.countMonths,
          fillWeeks: fillWeeks ?? options.fillWeeks,
          fillMonths: fillMonths ?? options.fillMonths,
          fillGaps: fillGaps ?? options.fillGaps,
        ),
      );
    });
  }

  void _back() {
    if (_showWeekdays) {
      setState(() => _showWeekdays = false);
      return;
    }
    Navigator.of(context).pop(_draft == _initial ? null : _draft);
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit.copyWith(
      goalPeriod: _draft.period,
      weeklyGoalTarget: _draft.weeklyTarget,
      monthlyGoalTarget: _draft.monthlyTarget,
      buildRepeat: _draft.options,
    );
    final today = DateUtils.dateOnly(DateTime.now());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: FractionallySizedBox(
        heightFactor: 0.96,
        child: Material(
          color: _background,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 150) _back();
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: 14,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: _back,
                        style: IconButton.styleFrom(
                          backgroundColor: _surface,
                          foregroundColor: _text,
                          side: const BorderSide(color: _border),
                        ),
                        icon: const Icon(Icons.chevron_left_rounded, size: 21),
                      ),
                      Expanded(
                        child: Text(
                          _showWeekdays ? 'On specific days' : 'Goal & Streak',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: ValueKey(_showWeekdays),
                    padding: EdgeInsets.fromLTRB(
                      _showWeekdays ? 6 : 15,
                      24,
                      _showWeekdays ? 6 : 15,
                      32,
                    ),
                    children:
                        _showWeekdays
                            ? _weekdayContent(habit, today)
                            : _repeatContent(habit, today),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _repeatContent(Habit habit, DateTime today) => [
    _heading('Repeat'),
    _panel(
      Column(
        children: [
          for (final period in _periods) ...[
            if (period != _periods.first)
              const Divider(height: 1, color: _border),
            _option(period),
          ],
        ],
      ),
    ),
    if (habit.goalPeriod == GoalPeriod.weekly ||
        habit.goalPeriod == GoalPeriod.monthly)
      ..._quotaContent(habit, today),
    if (habit.goalPeriod == GoalPeriod.everyFewDays)
      ..._rollingContent(habit, today),
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _update(period: GoalPeriod.none),
        style: TextButton.styleFrom(
          foregroundColor: _draft.period == GoalPeriod.none ? _accent : _muted,
        ),
        icon: Icon(
          _draft.period == GoalPeriod.none
              ? Icons.check_circle
              : Icons.remove_circle_outline,
          size: 16,
        ),
        label: const Text('No repeat goal'),
      ),
    ),
  ];

  Widget _option(GoalPeriod period) {
    final selected = _draft.period == period;
    final specificDays = period == GoalPeriod.specificDays;
    final (label, dots) = switch (period) {
      GoalPeriod.daily => ('Every day', repeatAllDays),
      GoalPeriod.specificDays => ('On specific days', _draft.options.weekdays),
      GoalPeriod.weekly => ('Times a week', 0x15),
      GoalPeriod.monthly => ('Times a month', 0x4b),
      GoalPeriod.everyFewDays => ('Every few days', 0x49),
      GoalPeriod.none => ('No repeat goal', 0),
    };
    return Material(
      color: selected ? _selection : _surface,
      child: Column(
        children: [
          ListTile(
            selected: selected,
            selectedColor: _text,
            textColor: _text,
            minTileHeight: 48,
            minLeadingWidth: 46,
            horizontalTitleGap: 12,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            onTap: () {
              _update(period: period);
              if (period == GoalPeriod.specificDays) {
                setState(() => _showWeekdays = true);
              }
            },
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < 7; index++)
                  Padding(
                    padding: EdgeInsets.only(right: index == 6 ? 0 : 2.5),
                    child: _cell(
                      dots & (1 << index) != 0 ? _accent : _scheduled,
                      4.5,
                    ),
                  ),
              ],
            ),
            title: Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            subtitle:
                selected && specificDays
                    ? Text(
                      specificDaysLabel(dots),
                      style: TextStyle(
                        color: _accent,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    )
                    : null,
            trailing: SizedBox(
              width: selected && specificDays ? 46 : 24,
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (selected)
                    Icon(Icons.check_circle, size: 24, color: _accent),
                  if (specificDays)
                    const Icon(Icons.chevron_right, size: 18, color: _muted),
                ],
              ),
            ),
          ),
          if (selected)
            switch (period) {
              GoalPeriod.weekly => _stepper(
                _draft.weeklyTarget,
                1,
                7,
                'week',
                (value) => _update(weeklyTarget: value),
              ),
              GoalPeriod.monthly => _stepper(
                _draft.monthlyTarget,
                1,
                31,
                'month',
                (value) => _update(monthlyTarget: value),
              ),
              GoalPeriod.everyFewDays => _stepper(
                _draft.options.gapDays,
                2,
                31,
                'interval',
                (value) => _update(gapDays: value),
              ),
              _ => const SizedBox.shrink(),
            },
        ],
      ),
    );
  }

  Widget _stepper(
    int value,
    int minimum,
    int maximum,
    String interval,
    ValueChanged<int> change,
  ) {
    final rolling = interval == 'interval';
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(52, 48),
      backgroundColor: _surface,
      foregroundColor: _text,
      disabledForegroundColor: _muted.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: const BorderSide(color: _border),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 0, 15, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D21),
                borderRadius: BorderRadius.circular(14),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (rolling) const TextSpan(text: 'Every '),
                      TextSpan(
                        text: '$value',
                        style: const TextStyle(
                          color: _text,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: rolling ? ' days' : ' / $interval'),
                    ],
                  ),
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Decrease $interval target',
            style: buttonStyle,
            onPressed: value > minimum ? () => change(value - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Increase $interval target',
            style: buttonStyle,
            onPressed: value < maximum ? () => change(value + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }

  List<Widget> _weekdayContent(Habit habit, DateTime today) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final mask = habit.buildRepeat.weekdays;
    final monday = shiftHabitDay(today, 1 - today.weekday);
    final streak = habit.currentStreak(today);
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: _heading('Which days'),
      ),
      LayoutBuilder(
        builder:
            (context, constraints) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth >= 7 * 44 + 18 ? 9 : 0,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 6,
                children: [
                  for (var index = 0; index < names.length; index++)
                    _weekdayButton(names[index], 1 << index, mask),
                ],
              ),
            ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(9, 10, 9, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                _preset('Weekdays', repeatWeekdays, mask),
                _preset('Weekends', repeatWeekends, mask),
                _preset('Every day', repeatAllDays, mask),
              ],
            ),
            const SizedBox(height: 22),
            _heading('How it counts'),
            _panel(
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _streak(
                      streak,
                      streak == 1 ? 'day in a row' : 'days in a row',
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 252),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                for (final name in names)
                                  Expanded(
                                    child: Text(
                                      name[0],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            for (final offset in [-7, 0])
                              Row(
                                children: [
                                  for (var index = 0; index < 7; index++)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.5),
                                        child: AspectRatio(
                                          aspectRatio: 1,
                                          child: _weekdayPreviewCell(
                                            habit,
                                            shiftHabitDay(
                                              monday,
                                              offset + index,
                                            ),
                                            today,
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
                    const SizedBox(height: 12),
                    _body(
                      'Your streak counts the days you picked, in a row. The other days are free.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _body(
              'Did it on a free day anyway? It shows on the grid and counts in your total.',
            ),
          ],
        ),
      ),
    ];
  }

  Widget _weekdayButton(String name, int bit, int mask) {
    final selected = mask & bit != 0;
    return Semantics(
      selected: selected,
      child: IconButton(
        tooltip: name,
        onPressed: mask == bit ? null : () => _update(weekdays: mask ^ bit),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: selected ? _accent : _surface,
          foregroundColor: selected ? _onAccent : _muted,
          disabledBackgroundColor: _accent,
          disabledForegroundColor: _onAccent,
          side: BorderSide(color: selected ? _accent : _border),
        ),
        icon: Text(
          name[0],
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? _onAccent : _muted,
          ),
        ),
      ),
    );
  }

  Widget _preset(String label, int value, int mask) => ChoiceChip(
    label: Text(label),
    selected: value == mask,
    showCheckmark: false,
    backgroundColor: _surface,
    selectedColor: _scheduled,
    side: BorderSide(color: value == mask ? Colors.transparent : _border),
    shape: const StadiumBorder(),
    labelStyle: TextStyle(color: value == mask ? _accent : _text),
    onSelected: (_) => _update(weekdays: value),
  );

  Widget _weekdayPreviewCell(Habit habit, DateTime day, DateTime today) {
    final done = !day.isAfter(today) && habit.isCompleteOn(day);
    final scheduled = habit.isScheduledOn(day);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            done
                ? _accent
                : scheduled
                ? _scheduled
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: day == today ? Border.all(color: _accent) : null,
      ),
      child: !done && !scheduled ? _cell(_muted, 4) : null,
    );
  }

  List<Widget> _quotaContent(Habit habit, DateTime today) {
    final weekly = habit.goalPeriod == GoalPeriod.weekly;
    final unit = weekly ? 'week' : 'month';
    final target = weekly ? habit.weeklyGoalTarget : habit.monthlyGoalTarget;
    final streak = habit.quotaStreak(today);
    final inPeriods = habit.countsPeriods;
    final fill =
        weekly ? habit.buildRepeat.fillWeeks : habit.buildRepeat.fillMonths;

    return [
      const SizedBox(height: 20),
      _heading('Count my streak in'),
      _panel(
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _unit('Days', streak.days, !inPeriods, () {
                  if (weekly) {
                    _update(countWeeks: false);
                  } else {
                    _update(countMonths: false);
                  }
                }),
              ),
              Expanded(
                child: _unit(
                  weekly ? 'Weeks' : 'Months',
                  streak.periods,
                  inPeriods,
                  () {
                    if (weekly) {
                      _update(countWeeks: true);
                    } else {
                      _update(countMonths: true);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      _body(
        inPeriods
            ? 'Every $unit with $target or more adds one to your streak. Days off inside a good $unit never count against you.'
            : 'Every day you complete the habit counts, as long as the $unit reaches $target.',
      ),
      const SizedBox(height: 16),
      _panel(
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fillControl(
                'Fill in a met $unit',
                'Once you reach $target, other days in the $unit get a small mark.',
                fill,
                (value) =>
                    weekly
                        ? _update(fillWeeks: value)
                        : _update(fillMonths: value),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var index = 0; index < 7; index++)
                    _cell(
                      index.isEven && index < 6 ? _accent : _scheduled,
                      15,
                      center:
                          fill && (index.isOdd || index == 6) ? _accent : null,
                    ),
                  const Text(
                    ' Example',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _unit(String label, int count, bool selected, VoidCallback onTap) =>
      Semantics(
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _scheduled : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? _accent : _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'now $count',
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? _accent : _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  List<Widget> _rollingContent(Habit habit, DateTime today) {
    final gap = habit.buildRepeat.gapDays;
    final streak = habit.currentStreak(today);
    return [
      const SizedBox(height: 20),
      _heading('How it counts'),
      _panel(
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fillControl(
                'Fill in the days between check-ins',
                'Days you can skip get a small square instead of a dot.',
                habit.buildRepeat.fillGaps,
                (value) => _update(fillGaps: value),
              ),
              const Divider(height: 24, color: _border),
              _streak(
                streak,
                streak == 1 ? 'check-in in a row' : 'check-ins in a row',
              ),
              const SizedBox(height: 14),
              _rollingGrid(habit, today),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _legend(_accent, 'done'),
                  _legend(
                    habit.buildRepeat.fillGaps ? _scheduled : _muted,
                    'not needed',
                    size: habit.buildRepeat.fillGaps ? 8 : 3,
                    center: habit.buildRepeat.fillGaps ? _accent : null,
                  ),
                  _legend(_scheduled, 'missed'),
                ],
              ),
              const SizedBox(height: 14),
              _body(
                'Check in at least once every $gap days. You can skip up to ${gap - 1} days in between without losing your streak.',
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _rollingGrid(Habit habit, DateTime today) {
    const weeks = 28;
    final monday = shiftHabitDay(today, 1 - today.weekday - (weeks - 1) * 7);
    final marks = habit.repeatMarks(monday, today, today: today);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 2.0;
        final size =
            ((constraints.maxWidth - (weeks - 1) * spacing) / weeks)
                .clamp(1.0, 12.0)
                .toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var weekday = 0; weekday < 7; weekday++)
              Padding(
                padding: const EdgeInsets.only(bottom: spacing),
                child: Row(
                  children: [
                    for (var week = 0; week < weeks; week++)
                      Padding(
                        padding: EdgeInsets.only(
                          right: week == weeks - 1 ? 0 : spacing,
                        ),
                        child: _rollingCell(
                          habit,
                          shiftHabitDay(monday, week * 7 + weekday),
                          today,
                          marks,
                          size,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _rollingCell(
    Habit habit,
    DateTime day,
    DateTime today,
    Map<String, RepeatMark> marks,
    double size,
  ) {
    if (day.isAfter(today)) return SizedBox.square(dimension: size);
    if (habit.isCompleteOn(day)) return _cell(_accent, size);
    final mark = marks[dayKey(day)];
    return switch (mark) {
      RepeatMark.free => _cell(Colors.transparent, size, center: _muted),
      RepeatMark.filled => _cell(_scheduled, size, center: _accent),
      null => _cell(_scheduled.withValues(alpha: 0.55), size),
    };
  }

  Widget _fillControl(
    String title,
    String description,
    bool value,
    ValueChanged<bool> change,
  ) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            _body(description),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Semantics(
        label: title,
        child: Switch(
          value: value,
          onChanged: change,
          activeThumbColor: _text,
          activeTrackColor: _accent,
          inactiveThumbColor: _accent,
        ),
      ),
    ],
  );

  Widget _streak(int count, String unit) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        '$count',
        style: const TextStyle(
          color: _text,
          fontSize: 34,
          fontWeight: FontWeight.w700,
        ),
      ),
      _body(unit),
    ],
  );

  Widget _legend(Color color, String label, {double size = 8, Color? center}) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell(color, size, center: center),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      );

  Widget _heading(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: _muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _body(String label) => Text(
    label,
    style: const TextStyle(
      color: _muted,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
  );

  Widget _panel(Widget child) => Material(
    color: _surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: _border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _cell(Color color, double size, {Color? center}) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.25),
    ),
    child:
        center == null
            ? null
            : Container(
              width: size * 0.38,
              height: size * 0.38,
              decoration: BoxDecoration(
                color: center,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
  );
}
