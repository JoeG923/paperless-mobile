import 'package:flutter/material.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_cancel_button.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_confirm_button.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class DeleteDocumentConfirmationDialog extends StatelessWidget {
  final DocumentModel document;
  const DeleteDocumentConfirmationDialog({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context)!.confirmDeletion),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.of(context)!.areYouSureYouWantToDeleteTheFollowingDocuments(1),
          ),
          const SizedBox(height: 16),
          Text(
            document.title.isEmpty ? '(no title)' : document.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(S.of(context)!.thisActionIsIrreversibleDoYouWishToProceedAnyway),
        ],
      ),
      actions: [
        const DialogCancelButton(),
        DialogConfirmButton(
          label: S.of(context)!.delete,
          style: DialogConfirmButtonStyle.danger,
        ),
      ],
    );
  }
}
