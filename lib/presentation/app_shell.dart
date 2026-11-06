import 'package:flutter/material.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'habit_icons.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.repository, super.key});

  final HabitRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _topSections = [
    'Summary',
    'Savings',
    'Calendar',
    'Urges',
    'Reasons',
    'Settings',
  ];
  static const _bottomSections = ['Progress', 'Today', 'Motivation', 'Support'];
  int _bottomIndex = 1;
  String? _topSection;
  Habit? _focusHabit;
  bool _choosingFocus = false;
  final _homeKey = GlobalKey<HomeScreenState>();

  void _habitsChanged(List<Habit> habits) {
    if (!mounted) return;
    setState(() {
      _focusHabit =
          habits.isEmpty
              ? null
              : habits.firstWhere(
                (habit) => habit.id == _focusHabit?.id,
                orElse: () => habits.first,
              );
    });
  }

  String get _focusDays {
    final habit = _focusHabit;
    if (habit == null) return 'Choose a habit to focus on';
    final days = habit.currentStreak(DateTime.now());
    return '${habit.type == HabitType.quit ? 'Sober for' : 'Streak'}: $days ${days == 1 ? 'day' : 'days'}';
  }

  Widget get _focusStatus {
    final complete = _focusHabit?.isCompleteOn(DateTime.now()) ?? false;
    return Tooltip(
      message: complete ? 'Done for today' : 'Not done for today',
      child: Icon(
        complete ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        size: 20,
        color: complete ? Color(_focusHabit!.colorValue) : AppColors.coolGrey,
      ),
    );
  }

  Future<void> _addFromMenu() async {
    Navigator.pop(context);
    setState(() {
      _bottomIndex = 1;
      _topSection = null;
    });
    await _homeKey.currentState?.addHabit();
    await _refreshFocus();
  }

  Future<void> _refreshFocus() async {
    try {
      final habits = await widget.repository.loadHabits();
      if (!mounted) return;
      setState(() {
        _focusHabit =
            habits.isEmpty
                ? null
                : habits.firstWhere(
                  (habit) => habit.id == _focusHabit?.id,
                  orElse: () => habits.first,
                );
      });
    } catch (_) {
      // Keep the existing focus when an optional label refresh fails.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialFocus();
  }

  Future<void> _loadInitialFocus() async {
    try {
      final habits = await widget.repository.loadHabits();
      if (!mounted || _focusHabit != null || habits.isEmpty) return;
      setState(
        () =>
            _focusHabit = habits.firstWhere(
              (habit) => habit.type == HabitType.quit,
              orElse: () => habits.first,
            ),
      );
    } catch (_) {
      // Today owns the storage error and retry UI.
    }
  }

  Future<void> _chooseFocus({bool editList = false}) async {
    if (_choosingFocus) return;
    _choosingFocus = true;
    try {
      final habits = await widget.repository.loadHabits();
      if (!mounted) return;
      final ordered = [
        ...habits.where((habit) => habit.type == HabitType.quit),
        ...habits.where((habit) => habit.type != HabitType.quit),
      ];
      final selected = await showModalBottomSheet<Habit>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder:
            (context) => SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.55,
                child: Column(
                  children: [
                    Text(
                      editList ? 'Edit habit list' : 'Choose your focus',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        editList
                            ? 'Choose a habit to edit.'
                            : 'Highlight a habit at the top of Rize.',
                      ),
                    ),
                    Expanded(
                      child:
                          ordered.isEmpty
                              ? const Center(
                                child: Text(
                                  'Add a habit in Today to choose a focus.',
                                ),
                              )
                              : ListView.builder(
                                itemCount: ordered.length,
                                itemBuilder: (context, index) {
                                  final habit = ordered[index];
                                  return ListTile(
                                    leading: Icon(
                                      habitIcon(habit.icon),
                                      color: Color(habit.colorValue),
                                    ),
                                    title: Text(habit.name),
                                    subtitle: Text(
                                      habit.type == HabitType.quit
                                          ? 'Quit habit'
                                          : 'Build habit',
                                    ),
                                    trailing:
                                        editList
                                            ? const Icon(Icons.edit_outlined)
                                            : habit.id == _focusHabit?.id
                                            ? const Icon(
                                              Icons.check_rounded,
                                              color: AppColors.burntOrange,
                                            )
                                            : null,
                                    onTap: () => Navigator.pop(context, habit),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ),
      );
      if (mounted && selected != null) {
        if (editList) {
          await _homeKey.currentState?.editHabitById(selected.id);
          await _refreshFocus();
        } else {
          setState(() => _focusHabit = selected);
        }
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load your habits. Please try again.'),
          ),
        );
    } finally {
      _choosingFocus = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showToday = _bottomIndex == 1 && _topSection == null;
    final section =
        _topSection ?? (showToday ? 'Summary' : _bottomSections[_bottomIndex]);
    return Scaffold(
      drawer: Drawer(
        backgroundColor: AppColors.carbon,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Material(
                color: Color(
                  _focusHabit?.colorValue ?? AppColors.burntOrange.toARGB32(),
                ).withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Color(
                      _focusHabit?.colorValue ??
                          AppColors.burntOrange.toARGB32(),
                    ).withValues(alpha: 0.45),
                  ),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  horizontalTitleGap: 10,
                  minLeadingWidth: 24,
                  leading: Icon(
                    _focusHabit == null
                        ? Icons.local_fire_department_outlined
                        : habitIcon(_focusHabit!.icon),
                    color:
                        _focusHabit == null
                            ? AppColors.burntOrange
                            : Color(_focusHabit!.colorValue),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CURRENT FOCUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(
                            _focusHabit?.colorValue ??
                                AppColors.burntOrange.toARGB32(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _focusHabit?.name ?? 'Your habits',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _focusDays,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.coolGrey,
                    ),
                  ),
                  trailing: _focusHabit == null ? null : _focusStatus,
                  onTap: () {
                    Navigator.pop(context);
                    _chooseFocus();
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addFromMenu,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add new habit'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Edit list',
                    onPressed: () {
                      Navigator.pop(context);
                      _chooseFocus(editList: true);
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.burntOrange.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.burntOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/app_icon.png',
                            width: 36,
                            height: 36,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Rize',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            color: AppColors.burntOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: "Don't let your spark fade. "),
                          TextSpan(
                            text: 'Surge',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.burntOrange,
                            ),
                          ),
                          const TextSpan(text: ' your tracking capacity.'),
                        ],
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Try 7 days free, cancel anytime',
                      style: TextStyle(color: AppColors.coolGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Then 9.99 per year',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.burntOrange,
                          foregroundColor: AppColors.carbon,
                          minimumSize: const Size(48, 56),
                        ),
                        onPressed:
                            () => showDialog<void>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Rize Surge preview'),
                                    content: const Text(
                                      'Subscriptions are not available yet. No trial will start and you will not be charged.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Got it'),
                                      ),
                                    ],
                                  ),
                            ),
                        child: const Text(
                          'Try for free 7 days',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  Builder(
                    builder:
                        (context) => IconButton(
                          tooltip: 'Open menu',
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu_rounded),
                        ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('focus-habit-picker'),
                      onPressed: _chooseFocus,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.offWhite,
                        backgroundColor: AppColors.charcoalGrey,
                        minimumSize: const Size(48, 48),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _focusHabit == null
                                ? Icons.local_fire_department_outlined
                                : habitIcon(_focusHabit!.icon),
                            color:
                                _focusHabit == null
                                    ? AppColors.burntOrange
                                    : Color(_focusHabit!.colorValue),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _focusHabit?.name ?? 'Focus habit',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _focusDays,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.coolGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_focusHabit != null) ...[
                            const SizedBox(width: 6),
                            _focusStatus,
                          ],
                          const Icon(Icons.expand_more_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Account',
                    onPressed: () => setState(() => _topSection = 'Account'),
                    icon: const Icon(Icons.account_circle_outlined),
                  ),
                ],
              ),
            ),
            if (_bottomIndex == 0)
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  itemCount: _topSections.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final label = _topSections[index];
                    final selected = _topSection == label;
                    return TextButton(
                      onPressed: () => setState(() => _topSection = label),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            selected
                                ? AppColors.burntOrange
                                : AppColors.coolGrey,
                        backgroundColor:
                            selected
                                ? AppColors.burntOrange.withValues(alpha: 0.1)
                                : Colors.transparent,
                        minimumSize: const Size(48, 48),
                      ),
                      child: Semantics(selected: selected, child: Text(label)),
                    );
                  },
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: showToday ? 0 : 1,
                children: [
                  HomeScreen(
                    key: _homeKey,
                    repository: widget.repository,
                    onHabitsChanged: _habitsChanged,
                  ),
                  _SectionPreview(section: section),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected:
            (index) => setState(() {
              _bottomIndex = index;
              _topSection = null;
            }),
        backgroundColor: AppColors.charcoalGrey,
        indicatorColor: AppColors.burntOrange.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.burntOrange,
            ),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            label: 'Motivation',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: 'Support',
          ),
        ],
      ),
    );
  }
}

class _SectionPreview extends StatelessWidget {
  const _SectionPreview({required this.section});

  final String section;

  static const _details = {
    'Account': (
      Icons.account_circle_outlined,
      'A space for your Rize profile.',
    ),
    'Summary': (Icons.dashboard_outlined, 'Your habits at a glance.'),
    'Savings': (
      Icons.savings_outlined,
      'A space for the savings your habits create.',
    ),
    'Calendar': (
      Icons.calendar_month_outlined,
      'A space to explore your habit history.',
    ),
    'Urges': (
      Icons.waves_outlined,
      'A space to reflect on urges and patterns.',
    ),
    'Reasons': (
      Icons.lightbulb_outline,
      'Keep your reasons for starting close.',
    ),
    'Settings': (Icons.tune_rounded, 'A space to make Rize feel like yours.'),
    'Progress': (
      Icons.insights_outlined,
      'A space to see how far you have come.',
    ),
    'Motivation': (Icons.bolt_outlined, 'A little fuel to keep you moving.'),
    'Support': (
      Icons.favorite_outline,
      'A space for encouragement along the way.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, description) = _details[section]!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.burntOrange, size: 40),
            const SizedBox(height: 20),
            Text(
              section,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.coolGrey),
            ),
            const SizedBox(height: 20),
            const Chip(label: Text('Preview · Coming soon')),
          ],
        ),
      ),
    );
  }
}
