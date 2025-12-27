import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';
import 'package:paperless_mobile/features/documents/view/widgets/selection/bulk_delete_confirmation_dialog.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_confirm_button.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:paperless_mobile/routing/routes/documents_route.dart';

class DocumentSelectionSliverAppBar extends StatelessWidget {
  final DocumentsState state;
  const DocumentSelectionSliverAppBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      stretch: false,
      pinned: true,
      floating: true,
      snap: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      title: Text(
        S.of(context)!.countSelected(state.selection.length),
      ),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => context.read<DocumentsCubit>().resetSelection(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) =>
                      BulkDeleteConfirmationDialog(state: state),
                ) ??
                false;
            if (shouldDelete) {
              try {
                if (!context.mounted) return;
                await context
                    .read<DocumentsCubit>()
                    .bulkDelete(state.selection);
                if (!context.mounted) return;
                showSnackBar(
                  context,
                  S.of(context)!.documentsSuccessfullyDeleted,
                );
                context.read<DocumentsCubit>().resetSelection();
              } on PaperlessApiException catch (error, stackTrace) {
                if (!context.mounted) return;
                showErrorMessage(context, error, stackTrace);
              }
            }
          },
        ),
        PopupMenuButton<_BulkSelectionAction>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) =>
              _handleBulkAction(context, action, state.selection),
          itemBuilder: (context) {
            final selectionCount = state.selection.length;
            final hasSelection = selectionCount > 0;
            final canMerge = selectionCount > 1;
            final isSingle = selectionCount == 1;
            return [
              PopupMenuItem(
                value: _BulkSelectionAction.reprocess,
                enabled: hasSelection,
                child: const Text('Reprocess'),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.merge,
                enabled: canMerge,
                child: const Text('Merge'),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.rotate,
                enabled: hasSelection,
                child: const Text('Rotate'),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.split,
                enabled: isSingle,
                child: const Text('Split'),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.deletePages,
                enabled: isSingle,
                child: const Text('Delete pages'),
              ),
            ];
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kTextTabBarHeight),
        child: SizedBox(
          height: kTextTabBarHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ActionChip(
                label: Text(S.of(context)!.correspondent),
                avatar: const Icon(Icons.edit),
                onPressed: () {
                  BulkEditDocumentsRoute(BulkEditExtraWrapper(
                    state.selection,
                    LabelType.correspondent,
                  )).push(context);
                },
              ).paddedOnly(left: 8, right: 4),
              ActionChip(
                label: Text(S.of(context)!.documentType),
                avatar: const Icon(Icons.edit),
                onPressed: () async {
                  BulkEditDocumentsRoute(BulkEditExtraWrapper(
                    state.selection,
                    LabelType.documentType,
                  )).push(context);
                },
              ).paddedOnly(left: 8, right: 4),
              ActionChip(
                label: Text(S.of(context)!.storagePath),
                avatar: const Icon(Icons.edit),
                onPressed: () async {
                  BulkEditDocumentsRoute(BulkEditExtraWrapper(
                    state.selection,
                    LabelType.storagePath,
                  )).push(context);
                },
              ).paddedOnly(left: 8, right: 4),
              _buildBulkEditTagsChip(context).paddedOnly(left: 4, right: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulkEditTagsChip(BuildContext context) {
    return ActionChip(
      label: Text(S.of(context)!.tags),
      avatar: const Icon(Icons.edit),
      onPressed: () {
        BulkEditDocumentsRoute(BulkEditExtraWrapper(
          state.selection,
          LabelType.tag,
        )).push(context);
      },
    );
  }
}

enum _BulkSelectionAction {
  reprocess,
  merge,
  rotate,
  split,
  deletePages,
}

Future<void> _handleBulkAction(
  BuildContext context,
  _BulkSelectionAction action,
  List<DocumentModel> selection,
) async {
  if (selection.isEmpty) {
    showSnackBar(context, 'No documents selected.'); // TODO: INTL
    return;
  }
  final documentsCubit = context.read<DocumentsCubit>();
  try {
    switch (action) {
      case _BulkSelectionAction.reprocess:
        final confirmed = await _showConfirmDialog(
          context,
          title: 'Reprocess documents', // TODO: INTL
          message:
              'The selected documents will be reprocessed on the server.', // TODO: INTL
        );
        if (!confirmed || !context.mounted) return;
        await documentsCubit.bulkReprocess(selection);
        if (!context.mounted) return;
        showSnackBar(context, 'Reprocess queued.'); // TODO: INTL
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.merge:
        if (selection.length < 2) {
          showSnackBar(
            context,
            'Select at least two documents to merge.', // TODO: INTL
          );
          return;
        }
        final options = await _showMergeDialog(context);
        if (options == null || !context.mounted) return;
        await documentsCubit.bulkMerge(
          selection,
          deleteOriginals: options.deleteOriginals,
          archiveFallback: options.archiveFallback,
        );
        if (!context.mounted) return;
        showSnackBar(context, 'Merge queued.'); // TODO: INTL
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.rotate:
        final degrees = await _showRotateDialog(context);
        if (degrees == null || !context.mounted) return;
        await documentsCubit.bulkRotate(selection, degrees: degrees);
        if (!context.mounted) return;
        showSnackBar(context, 'Rotate queued.'); // TODO: INTL
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.split:
        if (selection.length != 1) {
          showSnackBar(
            context,
            'Select exactly one document to split.', // TODO: INTL
          );
          return;
        }
        final options = await _showSplitDialog(context);
        if (options == null || !context.mounted) return;
        await documentsCubit.bulkSplit(
          selection.first,
          pages: options.pages,
          deleteOriginals: options.deleteOriginals,
        );
        if (!context.mounted) return;
        showSnackBar(context, 'Split queued.'); // TODO: INTL
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.deletePages:
        if (selection.length != 1) {
          showSnackBar(
            context,
            'Select exactly one document to edit pages.', // TODO: INTL
          );
          return;
        }
        final pages = await _showDeletePagesDialog(context);
        if (pages == null || !context.mounted) return;
        await documentsCubit.bulkDeletePages(
          selection.first,
          pages: pages,
        );
        if (!context.mounted) return;
        showSnackBar(context, 'Pages deleted.'); // TODO: INTL
        documentsCubit.resetSelection();
        break;
    }
  } on PaperlessApiException catch (error, stackTrace) {
    if (!context.mounted) return;
    showErrorMessage(context, error, stackTrace);
  }
}

Future<bool> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.of(context)!.cancel),
            ),
            const DialogConfirmButton(returnValue: true),
          ],
        ),
      ) ??
      false;
}

class _MergeDialogResult {
  final bool deleteOriginals;
  final bool archiveFallback;

  const _MergeDialogResult({
    required this.deleteOriginals,
    required this.archiveFallback,
  });
}

Future<_MergeDialogResult?> _showMergeDialog(BuildContext context) async {
  return showDialog<_MergeDialogResult>(
    context: context,
    builder: (context) {
      bool deleteOriginals = false;
      bool archiveFallback = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Merge documents'), // TODO: INTL
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The merged document order follows the selected order.', // TODO: INTL
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Delete originals'), // TODO: INTL
                  value: deleteOriginals,
                  onChanged: (value) {
                    setState(() => deleteOriginals = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Archive fallback'), // TODO: INTL
                  value: archiveFallback,
                  onChanged: (value) {
                    setState(() => archiveFallback = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context)!.cancel),
              ),
              DialogConfirmButton(
                returnValue: _MergeDialogResult(
                  deleteOriginals: deleteOriginals,
                  archiveFallback: archiveFallback,
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<int?> _showRotateDialog(BuildContext context) async {
  return showDialog<int>(
    context: context,
    builder: (context) {
      int selectedDegrees = 90;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rotate documents'), // TODO: INTL
            content: DropdownButtonFormField<int>(
              value: selectedDegrees,
              decoration: const InputDecoration(
                labelText: 'Degrees', // TODO: INTL
              ),
              items: const [
                DropdownMenuItem(value: 90, child: Text('90°')),
                DropdownMenuItem(value: 180, child: Text('180°')),
                DropdownMenuItem(value: 270, child: Text('270°')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedDegrees = value);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context)!.cancel),
              ),
              DialogConfirmButton(returnValue: selectedDegrees),
            ],
          );
        },
      );
    },
  );
}

class _SplitDialogResult {
  final String pages;
  final bool deleteOriginals;

  const _SplitDialogResult({
    required this.pages,
    required this.deleteOriginals,
  });
}

Future<_SplitDialogResult?> _showSplitDialog(BuildContext context) async {
  return showDialog<_SplitDialogResult>(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      String? errorText;
      bool deleteOriginals = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Split document'), // TODO: INTL
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Pages', // TODO: INTL
                    hintText: '1,2-3,4', // TODO: INTL
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Delete original'), // TODO: INTL
                  value: deleteOriginals,
                  onChanged: (value) {
                    setState(() => deleteOriginals = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context)!.cancel),
              ),
              DialogConfirmButton(
                onPressed: () {
                  final pages = controller.text.trim();
                  if (pages.isEmpty) {
                    setState(() {
                      errorText = 'Enter page ranges.'; // TODO: INTL
                    });
                    return;
                  }
                  Navigator.of(context).pop(
                    _SplitDialogResult(
                      pages: pages,
                      deleteOriginals: deleteOriginals,
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<List<int>?> _showDeletePagesDialog(BuildContext context) async {
  return showDialog<List<int>>(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Delete pages'), // TODO: INTL
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Pages', // TODO: INTL
                hintText: '2,3,4', // TODO: INTL
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context)!.cancel),
              ),
              DialogConfirmButton(
                onPressed: () {
                  final parsed = _parsePageList(controller.text);
                  if (parsed == null || parsed.isEmpty) {
                    setState(() {
                      errorText = 'Enter valid page numbers.'; // TODO: INTL
                    });
                    return;
                  }
                  Navigator.of(context).pop(parsed);
                },
              ),
            ],
          );
        },
      );
    },
  );
}

List<int>? _parsePageList(String input) {
  final rawParts = input.split(',');
  final pages = <int>[];
  for (final raw in rawParts) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      continue;
    }
    final parsed = int.tryParse(cleaned);
    if (parsed == null || parsed < 1) {
      return null;
    }
    pages.add(parsed);
  }
  return pages.isEmpty ? null : pages;
}
