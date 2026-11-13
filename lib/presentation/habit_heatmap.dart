import 'package:flutter/material.dart';

import '../domain/habit.dart';
import '../theme/app_colors.dart';

class HabitHeatmap extends StatefulWidget {
  const HabitHeatmap({
    required this.habit,
    required this.startDate,
    required this.endDate,
    this.showMonthLabels = true,
    this.showWeekdayLabels = true,
    this.noteDays = const {},
    this.onSelectDay,
    this.scrollable = false,
    super.key,
  });

  final Habit habit;
  final DateTime startDate;
  final DateTime endDate;
  final bool showMonthLabels;
  final bool showWeekdayLabels;
  final Set<String> noteDays;
  final ValueChanged<DateTime>? onSelectDay;
  final bool scrollable;

  @override
  State<HabitHeatmap> createState() => _HabitHeatmapState();
}

class _HabitHeatmapState extends State<HabitHeatmap> {
  final ScrollController _scrollController = ScrollController();
  bool _initialScrollScheduled = false;

  @override
  void didUpdateWidget(HabitHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dateRangeChanged =
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate;
    final wasAtLatestDates =
        _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent -
                _scrollController.position.pixels <
            1;
    if (widget.scrollable && dateRangeChanged && wasAtLatestDates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final showMonthLabels = widget.showMonthLabels;
    final showWeekdayLabels = widget.showWeekdayLabels;
    final noteDays = widget.noteDays;
    final onSelectDay = widget.onSelectDay;
    final start = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
    );
    final end = DateTime(
      widget.endDate.year,
      widget.endDate.month,
      widget.endDate.day,
    );
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
    final repeatMarks = habit.repeatMarks(start, end, today: today);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize =
            widget.scrollable
                ? 11.0
                : ((constraints.maxWidth - labelWidth - (weekCount - 1) * gap) /
                        weekCount)
                    .clamp(5.0, 14.0)
                    .toDouble();
        final gridWidth = cellSize * weekCount + gap * (weekCount - 1);
        final labels = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showMonthLabels) ...[
              SizedBox(
                width: gridWidth,
                height: 14,
                child: Stack(
                  children: [
                    for (var week = 0; week < weekCount; week++)
                      if (_monthLabel(gridStart, week, start, end).isNotEmpty)
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
              const SizedBox(height: 5),
            ],
            for (var weekday = 0; weekday < 7; weekday++) ...[
              if (weekday > 0) const SizedBox(height: gap),
              Row(
                children: [
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
                      repeatMarks: repeatMarks,
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

        if (!widget.scrollable) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showWeekdayLabels)
                SizedBox(
                  width: labelWidth,
                  child: Column(
                    children: [
                      if (showMonthLabels) ...[const SizedBox(height: 19)],
                      for (var weekday = 0; weekday < 7; weekday++) ...[
                        if (weekday > 0) const SizedBox(height: gap),
                        SizedBox(
                          height: cellSize,
                          child: Align(
                            alignment: Alignment.topLeft,
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
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: AppColors.coolGrey,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              labels,
            ],
          );
        }

        if (!_initialScrollScheduled) {
          _initialScrollScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          });
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showWeekdayLabels)
              SizedBox(
                width: labelWidth,
                child: Column(
                  children: [
                    if (showMonthLabels) const SizedBox(height: 19),
                    for (var weekday = 0; weekday < 7; weekday++) ...[
                      if (weekday > 0) const SizedBox(height: gap),
                      SizedBox(
                        height: cellSize,
                        child: Align(
                          alignment: Alignment.topLeft,
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
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: AppColors.coolGrey,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: labels,
              ),
            ),
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
    required this.repeatMarks,
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
  final Map<String, RepeatMark> repeatMarks;
  final bool hasNote;
  final Color color;
  final double size;
  final ValueChanged<DateTime>? onSelectDay;

  @override
  Widget build(BuildContext context) {
    final inRange = !day.isBefore(startDate) && !day.isAfter(endDate);
    final isFuture = day.isAfter(today);
    final progress = inRange && !isFuture ? habit.dailyProgressOn(day) : 0.0;
    final mark = inRange ? repeatMarks[dayKey(day)] : null;
    final fill =
        progress > 0
            ? color.withValues(alpha: progress)
            : mark == RepeatMark.filled
            ? color.withValues(alpha: 0.18)
            : AppColors.carbon;

    final cell = Container(
      key: inRange ? ValueKey('habit-heatmap-${dayKey(day)}') : null,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color:
              hasNote
                  ? AppColors.offWhite.withValues(alpha: 0.8)
                  : progress == 1
                  ? fill
                  : Colors.transparent,
        ),
      ),
      child:
          mark == null
              ? null
              : Container(
                width: size * (mark == RepeatMark.filled ? 0.42 : 0.24),
                height: size * (mark == RepeatMark.filled ? 0.42 : 0.24),
                decoration: BoxDecoration(
                  color: mark == RepeatMark.filled ? color : AppColors.coolGrey,
                  borderRadius: BorderRadius.circular(1),
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
    required this.goalTitle,
    required this.goalLabel,
    required this.goalReached,
    required this.color,
    super.key,
  });

  final String streakLabel;
  final String goalTitle;
  final String goalLabel;
  final bool goalReached;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 10.0;
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final minCardWidth = 144 * textScale;
      final streakCard = _ProgressCard(
        icon: Icons.local_fire_department_rounded,
        title: 'Current streak',
        value: streakLabel,
        color: AppColors.burntOrange,
      );
      final goalCard = _ProgressCard(
        icon: goalReached ? Icons.check_rounded : Icons.track_changes_rounded,
        iconLabel: goalReached ? 'Repeat goal reached' : null,
        title: goalTitle,
        value: goalLabel,
        color: color,
      );

      if (constraints.maxWidth < minCardWidth * 2 + spacing) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: [streakCard, goalCard],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: [Expanded(child: streakCard), Expanded(child: goalCard)],
        ),
      );
    },
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.iconLabel,
  });

  final IconData icon;
  final String? iconLabel;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.charcoalGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.coolGrey.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(icon, size: 19, color: color, semanticLabel: iconLabel),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  title,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.coolGrey,
                  ),
                ),
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
