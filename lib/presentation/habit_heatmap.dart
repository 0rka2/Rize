import 'package:flutter/material.dart';

import '../domain/habit.dart';
import '../theme/app_colors.dart';

class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({
    required this.habit,
    required this.startDate,
    required this.endDate,
    this.showMonthLabels = true,
    this.showWeekdayLabels = true,
    this.selectedDay,
    this.noteDays = const {},
    this.onSelectDay,
    super.key,
  });

  final Habit habit;
  final DateTime startDate;
  final DateTime endDate;
  final bool showMonthLabels;
  final bool showWeekdayLabels;
  final DateTime? selectedDay;
  final Set<String> noteDays;
  final ValueChanged<DateTime>? onSelectDay;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final gridStart = DateTime(
      start.year,
      start.month,
      start.day - (start.weekday - 1),
    );
    final calendarDayCount =
        DateTime.utc(end.year, end.month, end.day)
            .difference(
              DateTime.utc(gridStart.year, gridStart.month, gridStart.day),
            )
            .inDays +
        1;
    final weekCount = (calendarDayCount / 7).ceil();
    final labelWidth = showWeekdayLabels ? 24.0 : 0.0;
    const gap = 3.0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize =
            ((constraints.maxWidth - labelWidth - (weekCount - 1) * gap) /
                    weekCount)
                .clamp(5.0, 14.0)
                .toDouble();
        return Column(
          children: [
            if (showMonthLabels) ...[
              Row(
                children: [
                  if (showWeekdayLabels) SizedBox(width: labelWidth),
                  SizedBox(
                    width: cellSize * weekCount + gap * (weekCount - 1),
                    height: 14,
                    child: Stack(
                      children: [
                        for (var week = 0; week < weekCount; week++)
                          if (_monthLabel(
                            gridStart,
                            week,
                            start,
                            end,
                          ).isNotEmpty)
                            Positioned(
                              left: _monthLabelPosition(
                                week,
                                cellSize,
                                gap,
                                weekCount,
                              ),
                              top: 0,
                              width: 30,
                              height: 14,
                              child: Text(
                                _monthLabel(gridStart, week, start, end),
                                maxLines: 1,
                                softWrap: false,
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color: AppColors.coolGrey,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
            ],
            for (var weekday = 0; weekday < 7; weekday++) ...[
              if (weekday > 0) const SizedBox(height: gap),
              Row(
                children: [
                  if (showWeekdayLabels)
                    SizedBox(
                      width: labelWidth,
                      child: Text(
                        const [
                          'Mo',
                          'Tu',
                          'We',
                          'Th',
                          'Fr',
                          'Sa',
                          'Su',
                        ][weekday],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.coolGrey,
                        ),
                      ),
                    ),
                  for (var week = 0; week < weekCount; week++) ...[
                    if (week > 0) const SizedBox(width: gap),
                    _HeatmapDay(
                      day: DateTime(
                        gridStart.year,
                        gridStart.month,
                        gridStart.day + week * 7 + weekday,
                      ),
                      startDate: start,
                      endDate: end,
                      today: today,
                      habit: habit,
                      selectedDay: selectedDay,
                      hasNote: noteDays.contains(
                        dayKey(
                          DateTime(
                            gridStart.year,
                            gridStart.month,
                            gridStart.day + week * 7 + weekday,
                          ),
                        ),
                      ),
                      color: Color(habit.colorValue),
                      size: cellSize,
                      onSelectDay: onSelectDay,
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

double _monthLabelPosition(
  int week,
  double cellSize,
  double gap,
  int weekCount,
) {
  const labelWidth = 30.0;
  final gridWidth = cellSize * weekCount + gap * (weekCount - 1);
  final lastStart = (gridWidth - labelWidth).clamp(0.0, gridWidth);
  return (week * (cellSize + gap)).clamp(0.0, lastStart).toDouble();
}

class _HeatmapDay extends StatelessWidget {
  const _HeatmapDay({
    required this.day,
    required this.startDate,
    required this.endDate,
    required this.today,
    required this.habit,
    required this.selectedDay,
    required this.hasNote,
    required this.color,
    required this.size,
    required this.onSelectDay,
  });

  final DateTime day;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime today;
  final Habit habit;
  final DateTime? selectedDay;
  final bool hasNote;
  final Color color;
  final double size;
  final ValueChanged<DateTime>? onSelectDay;

  @override
  Widget build(BuildContext context) {
    final inRange = !day.isBefore(startDate) && !day.isAfter(endDate);
    final isFuture = day.isAfter(today);
    final count = habit.countOn(day);
    final complete = inRange && !isFuture && habit.isCompleteOn(day);
    final partial =
        inRange &&
        !isFuture &&
        count > 0 &&
        !complete &&
        habit.type != HabitType.quit;
    final slip =
        inRange && !isFuture && habit.type == HabitType.quit && count > 0;
    final selected =
        inRange && selectedDay != null && dayKey(day) == dayKey(selectedDay!);
    final fill =
        !inRange
            ? AppColors.carbon
            : slip
            ? AppColors.burntOrange
            : complete
            ? (habit.type == HabitType.quit ? AppColors.successGreen : color)
            : partial
            ? color.withValues(alpha: 0.48)
            : AppColors.carbon;

    final cell = Container(
      key: inRange ? ValueKey('habit-heatmap-${dayKey(day)}') : null,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color:
              selected
                  ? color
                  : hasNote
                  ? AppColors.offWhite.withValues(alpha: 0.8)
                  : (complete || partial || slip)
                  ? fill
                  : Colors.transparent,
        ),
      ),
    );

    if (!inRange || onSelectDay == null) return cell;
    return Tooltip(
      message: MaterialLocalizations.of(context).formatMediumDate(day),
      child: InkWell(
        borderRadius: BorderRadius.circular(size * 0.3),
        onTap: () => onSelectDay!(day),
        child: cell,
      ),
    );
  }
}

class HabitProgressIndicators extends StatelessWidget {
  const HabitProgressIndicators({
    required this.streakLabel,
    required this.goalLabel,
    super.key,
  });

  final String streakLabel;
  final String goalLabel;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _ProgressPill(
        icon: Icons.local_fire_department_outlined,
        label: streakLabel,
        color: Color(0xFFFF7A00),
      ),
      _ProgressPill(
        icon: Icons.track_changes_rounded,
        label: goalLabel,
        color: AppColors.coolGrey,
      ),
    ],
  );
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.carbon,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

String _monthLabel(
  DateTime firstWeekDay,
  int week,
  DateTime start,
  DateTime end,
) {
  final monday = DateTime(
    firstWeekDay.year,
    firstWeekDay.month,
    firstWeekDay.day + week * 7,
  );
  for (var offset = 0; offset < 7; offset++) {
    final day = DateTime(monday.year, monday.month, monday.day + offset);
    if (!day.isBefore(start) && !day.isAfter(end) && day.day == 1) {
      return const [
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
      ][day.month - 1];
    }
  }
  return week == 0
      ? const [
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
      ][start.month - 1]
      : '';
}
