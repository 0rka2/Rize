import 'package:flutter/material.dart';

import '../domain/habit_category.dart';
import '../theme/app_colors.dart';

typedef CategorySelection =
    ({List<HabitCategory> categories, List<HabitCategory> customCategories});

Future<CategorySelection?> showHabitCategoryPicker(
  BuildContext context, {
  required List<HabitCategory> selected,
  required List<HabitCategory> customCategories,
  required Color color,
}) => showModalBottomSheet<CategorySelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  enableDrag: false,
  builder:
      (_) => _CategoryPicker(
        selected: selected,
        customCategories: customCategories,
        color: color,
      ),
);

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({
    required this.selected,
    required this.customCategories,
    required this.color,
  });

  final List<HabitCategory> selected;
  final List<HabitCategory> customCategories;
  final Color color;

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  late final _selectedIds =
      widget.selected.map((category) => category.id).toSet();
  late final _customCategories = widget.customCategories.toList();
  bool _editing = false;

  List<HabitCategory> get _categories => [
    ...presetHabitCategories,
    ..._customCategories,
  ];

  Future<void> _createCategory() async {
    final category = await showModalBottomSheet<HabitCategory>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (_) => _CreateCategorySheet(
            existingNames:
                _categories.map((item) => item.name.toLowerCase()).toSet(),
            color: widget.color,
          ),
    );
    if (category == null || !mounted) return;
    setState(() {
      _customCategories.add(category);
      _selectedIds.add(category.id);
    });
  }

  Future<void> _deleteCategory(HabitCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete ${category.name}?'),
            content: const Text(
              'Saving will remove this category from every habit that uses it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _selectedIds.remove(category.id);
      _customCategories.remove(category);
    });
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.85,
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _editing ? 'Edit custom categories' : 'Categories',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (_editing || _customCategories.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _editing = !_editing),
                  child: Text(_editing ? 'Done' : 'Edit'),
                ),
              IconButton(
                tooltip: 'Close categories',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _editing ? _customCategoryList() : _categoryChips()),
          const SizedBox(height: 12),
          FilledButton(
            style: _saveStyle(widget.color),
            onPressed:
                () => Navigator.pop(context, (
                  categories: List<HabitCategory>.unmodifiable(
                    _categories.where(
                      (category) => _selectedIds.contains(category.id),
                    ),
                  ),
                  customCategories: List<HabitCategory>.unmodifiable(
                    _customCategories,
                  ),
                )),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  Widget _categoryChips() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pick one or multiple categories that your habit fits in'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in _categories)
              FilterChip(
                key: ValueKey(category.id),
                avatar: HabitCategoryIcon(category: category),
                label: Text(category.name),
                selected: _selectedIds.contains(category.id),
                selectedColor: widget.color.withValues(alpha: 0.24),
                onSelected:
                    (selected) => setState(() {
                      if (selected) {
                        _selectedIds.add(category.id);
                      } else {
                        _selectedIds.remove(category.id);
                      }
                    }),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Create your own'),
              onPressed: _createCategory,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _customCategoryList() {
    if (_customCategories.isEmpty) return const Text('No custom categories');
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorderItem:
          (oldIndex, newIndex) => setState(() {
            _customCategories.insert(
              newIndex,
              _customCategories.removeAt(oldIndex),
            );
          }),
      children: [
        for (final (index, category) in _customCategories.indexed)
          ListTile(
            key: ValueKey(category.id),
            contentPadding: EdgeInsets.zero,
            leading: HabitCategoryIcon(category: category),
            title: Text(category.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Delete ${category.name}',
                  onPressed: () => _deleteCategory(category),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: 'Reorder ${category.name}',
                    child: const ColoredBox(
                      color: Colors.transparent,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CreateCategorySheet extends StatefulWidget {
  const _CreateCategorySheet({
    required this.existingNames,
    required this.color,
  });

  final Set<String> existingNames;
  final Color color;

  @override
  State<_CreateCategorySheet> createState() => _CreateCategorySheetState();
}

class _CreateCategorySheetState extends State<_CreateCategorySheet> {
  static const _emojis = {
    '🏷️': 'Label',
    '🎨': 'Art',
    '💰': 'Money',
    '💪': 'Strength',
    '❤️': 'Heart',
    '🥗': 'Salad',
    '🤝': 'Handshake',
    '📚': 'Books',
    '💼': 'Briefcase',
    '☀️': 'Sun',
    '🌙': 'Moon',
    '🌱': 'Seedling',
    '🧘': 'Meditation',
    '🏃': 'Running',
    '🚲': 'Bicycle',
    '💧': 'Water',
    '🎵': 'Music',
    '🏠': 'Home',
    '🐾': 'Paw prints',
    '🧹': 'Broom',
    '✈️': 'Airplane',
    '🎯': 'Target',
    '✨': 'Sparkles',
    '😊': 'Smile',
  };

  String _name = '';
  String _emoji = '🏷️';

  Future<void> _chooseEmoji() async {
    final emoji = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose an emoji'),
            scrollable: true,
            content: Wrap(
              children: [
                for (final entry in _emojis.entries)
                  IconButton(
                    tooltip: entry.value,
                    isSelected: entry.key == _emoji,
                    onPressed: () => Navigator.pop(context, entry.key),
                    icon: Text(entry.key, style: const TextStyle(fontSize: 22)),
                  ),
              ],
            ),
          ),
    );
    if (emoji != null && mounted) setState(() => _emoji = emoji);
  }

  @override
  Widget build(BuildContext context) {
    final duplicate = widget.existingNames.contains(_name.toLowerCase());
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Category',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Pick an emoji and enter a name.'),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Choose an emoji',
                    onPressed: _chooseEmoji,
                    icon: Text(_emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('category-name'),
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged:
                          (value) => setState(() => _name = value.trim()),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Category name',
                        counterText: '',
                        errorText:
                            duplicate ? 'This category already exists.' : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to categories',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: _saveStyle(widget.color),
                      onPressed:
                          _name.isEmpty || duplicate
                              ? null
                              : () {
                                Navigator.pop<HabitCategory>(context, (
                                  id:
                                      'custom:${DateTime.now().microsecondsSinceEpoch}',
                                  name: _name,
                                  emoji: _emoji,
                                ));
                              },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HabitCategoryIcon extends StatelessWidget {
  const HabitCategoryIcon({required this.category, super.key});

  static const _presetIcons = <String, IconData>{
    'art': Icons.palette_outlined,
    'finances': Icons.payments_outlined,
    'fitness': Icons.directions_bike_outlined,
    'health': Icons.favorite_border_rounded,
    'nutrition': Icons.restaurant_outlined,
    'social': Icons.people_outline_rounded,
    'study': Icons.school_outlined,
    'work': Icons.work_outline_rounded,
    'other': Icons.diamond_outlined,
    'morning': Icons.wb_twilight_rounded,
    'day': Icons.light_mode_outlined,
    'evening': Icons.bedtime_outlined,
  };

  final HabitCategory category;

  @override
  Widget build(BuildContext context) {
    final emoji = category.emoji;
    return ExcludeSemantics(
      child:
          emoji == null
              ? Icon(_presetIcons[category.id], size: 18)
              : Text(emoji, style: const TextStyle(fontSize: 16)),
    );
  }
}

ButtonStyle _saveStyle(Color color) => FilledButton.styleFrom(
  backgroundColor: color,
  foregroundColor:
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? AppColors.offWhite
          : AppColors.carbon,
  minimumSize: const Size.fromHeight(50),
);
