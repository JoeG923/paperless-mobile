import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/unsaved_changes_warning_dialog.dart';

class PopWithUnsavedChanges extends StatelessWidget {
  final bool Function() hasChangesPredicate;
  final Widget child;

  const PopWithUnsavedChanges({
    super.key,
    required this.hasChangesPredicate,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (hasChangesPredicate()) {
          final shouldPop =
              await showDialog<bool>(
                context: context,
                builder: (context) => const UnsavedChangesWarningDialog(),
              ) ??
              false;
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop(result);
          }
        } else if (context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }
}
