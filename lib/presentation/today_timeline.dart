import 'package:flutter/material.dart';

import '../domain/habit.dart';
import '../theme/app_colors.dart';

class TodayTimeline extends StatefulWidget {
  const TodayTimeline({
    required this.today,
    required this.selectedDay,
    required this.completionForDay,
    required this.onSelectDay,
    required this.onAddHabit,
    this.showWeekStrip = true,
    super.key,
  });

  final DateTime today;
  final DateTime selectedDay;
  final ({int completed, int active}) Function(DateTime day) completionForDay;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback? onAddHabit;
  final bool showWeekStrip;

  @override
  State<TodayTimeline> createState() => _TodayTimelineState();
}

class _TodayTimelineState extends State<TodayTimeline> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final _weeks = PageController(keepPage: false);
  int _visibleWeekOffset = 0;

  @override
  void dispose() {
    _weeks.dispose();
    super.dispose();
  }

  void _returnToToday() {
    if (_weeks.hasClients) _weeks.jumpToPage(0);
    widget.onSelectDay(widget.today);
  }

  @override
  Widget build(BuildContext context) {
    final dates = MaterialLocalizations.of(context);
    final selectedDay = widget.selectedDay;
    final monday = shiftHabitDay(widget.today, 1 - widget.today.weekday);
    DateTime weekStart(int offset) => shiftHabitDay(monday, -7 * offset);
    final isCurrentWeek = _visibleWeekOffset == 0;
    final start = weekStart(_visibleWeekOffset);
    final end = shiftHabitDay(start, 6);
    final spansMonths = start.month != end.month;
    final String title;
    final String? subtitle;
    if (isCurrentWeek) {
      title = 'Today';
      subtitle = dates.formatMonthYear(widget.today);
    } else if (start.year != end.year) {
      title = '${dates.formatShortDate(start)} – ${dates.formatShortDate(end)}';
      subtitle = null;
    } else if (spansMonths) {
      title =
          '${dates.formatShortMonthDay(start)} – ${dates.formatShortMonthDay(end)}';
      subtitle = dates.formatYear(end);
    } else {
      title = _monthNames[start.month - 1];
      subtitle =
          '${dates.formatDecimal(start.day)} – '
          '${dates.formatDecimal(end.day)}, ${dates.formatYear(end)}';
    }
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 64,
              child: PopupMenuButton<String>(
                tooltip: 'Filter habits',
                itemBuilder:
                    (_) => const [
                      CheckedPopupMenuItem(
                        value: 'all',
                        checked: true,
                        child: Text('Show all'),
                      ),
                    ],
                child: Ink(
                  height: 44,
                  decoration: ShapeDecoration(
                    color: AppColors.burntOrange.withValues(alpha: 0.16),
                    shape: const StadiumBorder(),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'All',
                              style: TextStyle(color: AppColors.burntOrange),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: AppColors.burntOrange,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: _returnToToday,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.offWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                ),
                child: Tooltip(
                  message: isCurrentWeek ? '' : 'Back to today',
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: (isCurrentWeek
                                ? textTheme.headlineMedium
                                : textTheme.titleLarge)
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.7,
                            ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.coolGrey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton.filled(
                  tooltip: 'Add habit',
                  onPressed: widget.onAddHabit,
                  icon: const Icon(Icons.add_rounded, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.burntOrange,
                    foregroundColor: AppColors.carbon,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.showWeekStrip) const SizedBox(height: 10),
        if (widget.showWeekStrip)
          LayoutBuilder(
            builder: (context, constraints) {
              final diameter = (constraints.maxWidth / 7 - 6).clamp(0.0, 36.0);
              final labelHeight =
                  MediaQuery.textScalerOf(context).scale(12) * 1.3;
              return SizedBox(
                height: diameter + labelHeight + 22,
                child: PageView.builder(
                  key: const Key('today-week-timeline'),
                  controller: _weeks,
                  reverse: true,
                  onPageChanged:
                      (offset) => setState(() {
                        _visibleWeekOffset = offset;
                      }),
                  itemBuilder: (context, weekOffset) {
                    final start = weekStart(weekOffset);
                    return Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: _TimelineDay(
                              day: shiftHabitDay(start, i),
                              today: widget.today,
                              selectedDay: selectedDay,
                              diameter: diameter,
                              completionForDay: widget.completionForDay,
                              onSelectDay: widget.onSelectDay,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _TimelineDay extends StatelessWidget {
  const _TimelineDay({
    required this.day,
    required this.today,
    required this.selectedDay,
    required this.diameter,
    required this.completionForDay,
    required this.onSelectDay,
  });

  static const _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  final DateTime day;
  final DateTime today;
  final DateTime selectedDay;
  final double diameter;
  final ({int completed, int active}) Function(DateTime day) completionForDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final dates = MaterialLocalizations.of(context);
    final selected = day == selectedDay;
    final future = day.isAfter(today);
    final onTap = future ? null : () => onSelectDay(day);
    final fullDate = dates.formatFullDate(day);
    final weekdayColor = selected ? AppColors.burntOrange : AppColors.coolGrey;
    final numberColor = future ? AppColors.coolGrey : AppColors.offWhite;
    final completion = future ? null : completionForDay(day);
    final progress =
        completion == null || completion.active == 0
            ? 0.0
            : completion.completed / completion.active;
    final summary =
        completion == null
            ? null
            : '${(progress * 100).round()}% complete '
                '(${completion.completed} of ${completion.active} habits)';
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Semantics(
        key: ValueKey('today-date-${dayKey(day)}'),
        button: true,
        selected: selected,
        enabled: !future,
        label: day == today ? 'Today, $fullDate' : fullDate,
        value: summary,
        onTap: onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: summary == null ? fullDate : '$fullDate · $summary',
          excludeFromSemantics: true,
          child: Material(
            color:
                selected
                    ? AppColors.burntOrange.withValues(alpha: 0.10)
                    : Colors.transparent,
            shape: pill,
            child: InkWell(
              customBorder: pill,
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdays[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: weekdayColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox.square(
                    dimension: diameter,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!future)
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2,
                            strokeCap: StrokeCap.round,
                            trackGap: 0,
                            color: AppColors.burntOrange,
                            backgroundColor:
                                selected
                                    ? AppColors.burntOrange.withValues(
                                      alpha: 0.22,
                                    )
                                    : AppColors.coolGrey.withValues(
                                      alpha: 0.40,
                                    ),
                          )
                        else
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.coolGrey.withValues(
                                  alpha: 0.20,
                                ),
                              ),
                            ),
                          ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                dates.formatDecimal(day.day),
                                style: TextStyle(
                                  color: numberColor,
                                  fontWeight:
                                      selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
