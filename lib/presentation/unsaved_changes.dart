import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum UnsavedChangesChoice { save, discard, cancel }

Future<UnsavedChangesChoice?> showUnsavedChangesDialog(
  BuildContext context, {
  required Color color,
}) => showDialog<UnsavedChangesChoice>(
  context: context,
  builder:
      (context) => AlertDialog(
        backgroundColor: AppColors.carbon,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: AppColors.coolGrey.withValues(alpha: 0.2)),
        ),
        title: const Text('Save your changes?', textAlign: TextAlign.center),
        content: const Text(
          'Your changes have not been saved.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.coolGrey),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor:
                      ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                          ? AppColors.offWhite
                          : AppColors.carbon,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed:
                    () => Navigator.pop(context, UnsavedChangesChoice.save),
                child: const Text('Save'),
              ),
              for (final choice in [
                UnsavedChangesChoice.discard,
                UnsavedChangesChoice.cancel,
              ]) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coolGrey,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.pop(context, choice),
                  child: Text(
                    choice == UnsavedChangesChoice.discard
                        ? 'Discard'
                        : 'Cancel',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
);

class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    required this.hasUnsavedChanges,
    required this.onSave,
    required this.color,
    required this.child,
    this.isSaving,
    super.key,
  });

  final bool Function() hasUnsavedChanges;
  final bool Function()? isSaving;
  final FutureOr<void> Function() onSave;
  final Color color;
  final Widget child;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _showingPrompt = false;

  Future<void> _confirmExit() async {
    if (_showingPrompt || (widget.isSaving?.call() ?? false)) return;
    if (!widget.hasUnsavedChanges()) {
      Navigator.of(context).pop();
      return;
    }
    _showingPrompt = true;
    final choice = await showUnsavedChangesDialog(context, color: widget.color);
    _showingPrompt = false;
    if (!mounted) return;
    switch (choice) {
      case UnsavedChangesChoice.save:
        await widget.onSave();
      case UnsavedChangesChoice.discard:
        Navigator.of(context).pop();
      case UnsavedChangesChoice.cancel:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Read the current edits when leaving, even before the next rebuild.
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmExit();
    },
    child: widget.child,
  );
}
