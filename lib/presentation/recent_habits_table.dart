import 'package:flutter/material.dart';

import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'habit_icons.dart';

const _tileRadius = 8.0;

class RecentHabitsTable extends StatelessWidget {
  const RecentHabitsTable({
    required this.today,
    required this.habits,
    required this.isActiveOn,
    required this.onOpenHabit,
    required this.onTrackDay,
    super.key,
  });

  final DateTime today;
  final List<Habit> habits;
  final bool Function(Habit, DateTime) isActiveOn;
  final ValueChanged<Habit> onOpenHabit;
  final void Function(Habit, DateTime) onTrackDay;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(5, (index) => shiftHabitDay(today, index - 4));
    final dates = MaterialLocalizations.of(context);
    final range =
        days.first.year == today.year
            ? '${dates.formatShortMonthDay(days.first)} – ${dates.formatShortMonthDay(today)}'
            : '${dates.formatShortDate(days.first)} – ${dates.formatShortDate(today)}';
    final border = BorderSide(
      color: AppColors.coolGrey.withValues(alpha: 0.16),
    );
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Last 5 days',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                range,
                textAlign: TextAlign.end,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.coolGrey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: AppColors.charcoalGrey,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: border,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const habitColumnWeight = 2.7;
              final dayColumnWidth =
                  constraints.maxWidth / (habitColumnWeight + days.length);
              final tileSize = (dayColumnWidth * 0.75).clamp(0.0, 48.0);
              return Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(horizontalInside: border),
                columnWidths: const {0: FlexColumnWidth(habitColumnWeight)},
                children: [
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${habits.length} ${habits.length == 1 ? 'habit' : 'habits'}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.coolGrey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final day in days)
                        _dateHeading(context, day, tileSize),
                    ],
                  ),
                  for (final habit in habits)
                    _habitRow(context, habit, days, tileSize),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static const _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  Widget _dateHeading(BuildContext context, DateTime day, double tileSize) {
    final dates = MaterialLocalizations.of(context);
    final isToday = day == today;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 7),
        constraints: BoxConstraints(minWidth: tileSize),
        decoration:
            isToday
                ? BoxDecoration(
                  color: AppColors.burntOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                )
                : null,
        child: Semantics(
          label: '${isToday ? 'Today, ' : ''}${dates.formatFullDate(day)}',
          excludeSemantics: true,
          child: Column(
            children: [
              Text(
                _weekdays[day.weekday - 1],
                style: textTheme.labelMedium?.copyWith(
                  color: isToday ? AppColors.burntOrange : AppColors.coolGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dates.formatDecimal(day.day),
                style: textTheme.titleSmall?.copyWith(
                  color: isToday ? AppColors.burntOrange : AppColors.offWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _habitRow(
    BuildContext context,
    Habit habit,
    List<DateTime> days,
    double tileSize,
  ) {
    final color = Color(habit.colorValue);
    final streak = habit.calendarDayStreak(today);
    final streakCount = MaterialLocalizations.of(context).formatDecimal(streak);
    final repeat = habit.repeatMarks(days.first, today, today: today);
    final textTheme = Theme.of(context).textTheme;
    return TableRow(
      children: [
        InkWell(
          onTap: () => onOpenHabit(habit),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: tileSize,
                  height: tileSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(_tileRadius),
                  ),
                  child: Icon(
                    habitIcon(habit.icon),
                    color: color,
                    size: tileSize * 0.6,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '🔥$streakCount',
                        semanticsLabel:
                            '$streakCount ${streak == 1 ? 'day' : 'days'} streak',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.coolGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final day in days)
          _DayMarker(
            habit: habit,
            day: day,
            size: tileSize,
            repeat: repeat[dayKey(day)],
            onTap: isActiveOn(habit, day) ? () => onTrackDay(habit, day) : null,
          ),
      ],
    );
  }
}

class _DayMarker extends StatelessWidget {
  const _DayMarker({
    required this.habit,
    required this.day,
    required this.size,
    required this.repeat,
    required this.onTap,
  });

  final Habit habit;
  final DateTime day;
  final double size;
  final RepeatMark? repeat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.colorValue);
    final active = onTap != null;
    final slip = active && habit.isQuitSlipOn(day);
    final progress = active ? habit.dailyProgressOn(day) : 0.0;
    final complete = progress == 1;
    final partial = progress > 0 && !complete;
    final status = switch ((active, slip, complete, partial, repeat)) {
      (false, _, _, _, _) => 'Not started',
      (_, true, _, _, _) => 'Slip recorded',
      (_, _, _, true, _) when habit.type == HabitType.quit =>
        '${(progress * 100).round()}% of daily allowance left',
      (_, _, true, _, _) => 'Complete',
      (_, _, _, true, _) => 'In progress',
      (_, _, _, _, RepeatMark.free) => 'Day off',
      (_, _, _, _, RepeatMark.filled) => 'Covered by repeat',
      _ => 'Incomplete',
    };
    final muted = !active || repeat != null;
    final date = MaterialLocalizations.of(context).formatFullDate(day);
    final label = '${habit.name}, $date, $status';

    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        button: true,
        enabled: active,
        child: InkWell(
          key: ValueKey('recent-${habit.id}-${dayKey(day)}'),
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color:
                      complete
                          ? color
                          : color.withValues(alpha: muted ? 0.07 : 0.13),
                  borderRadius: BorderRadius.circular(_tileRadius),
                ),
                alignment: Alignment.center,
                child:
                    slip
                        ? Icon(Icons.close_rounded, size: 20, color: color)
                        : partial
                        ? SizedBox.square(
                          dimension: size * 0.7,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.5,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.25),
                          ),
                        )
                        : !complete && !muted
                        ? Container(
                          width: size * 0.7,
                          height: size * 0.7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.withValues(alpha: 0.60),
                              width: 2,
                            ),
                          ),
                        )
                        : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
