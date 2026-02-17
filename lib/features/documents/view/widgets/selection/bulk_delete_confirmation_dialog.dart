import 'package:flutter/material.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_cancel_button.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_confirm_button.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class BulkDeleteConfirmationDialog extends StatelessWidget {
  final DocumentsState state;
  const BulkDeleteConfirmationDialog({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    assert(state.selection.isNotEmpty);
    return AlertDialog(
      title: Text(S.of(context)!.confirmDeletion),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S
                .of(context)!
                .areYouSureYouWantToDeleteTheFollowingDocuments(
                  state.selection.length,
                ),
          ),
          const SizedBox(height: 16),
          ...state.selection.map(_buildBulletPoint),
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

  Widget _buildBulletPoint(DocumentModel doc) {
    return ListTile(
      dense: true,
      title: Text(
        doc.title.isEmpty ? '-' : doc.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
