import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_cancel_button.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class RemoveHistoryEntryDialog extends StatelessWidget {
  final String entry;
  const RemoveHistoryEntryDialog({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog.adaptive(
      icon: Icon(Icons.delete_outline, color: scheme.error),
      title: Text(entry),
      content: Text(S.of(context)!.removeQueryFromSearchHistory),
      actions: [
        const DialogCancelButton(),
        FilledButton(
          style: FilledButton.styleFrom(foregroundColor: scheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(S.of(context)!.remove),
        ),
      ],
    );
  }
}
