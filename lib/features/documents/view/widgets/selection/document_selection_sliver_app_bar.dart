import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/core/repository/group_repository.dart';
import 'package:paperless_mobile/core/repository/user_repository.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/core/widgets/form_fields/user_group_multi_select_field.dart';
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
      title: Text(S.of(context)!.countSelected(state.selection.length)),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => context.read<DocumentsCubit>().resetSelection(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            final shouldDelete =
                await showDialog<bool>(
                  context: context,
                  builder: (context) =>
                      BulkDeleteConfirmationDialog(state: state),
                ) ??
                false;
            if (shouldDelete) {
              try {
                if (!context.mounted) return;
                await context.read<DocumentsCubit>().bulkDelete(
                  state.selection,
                );
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
                child: Text(S.of(context)!.bulkActionReprocess),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.merge,
                enabled: canMerge,
                child: Text(S.of(context)!.bulkActionMerge),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.rotate,
                enabled: hasSelection,
                child: Text(S.of(context)!.bulkActionRotate),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.split,
                enabled: isSingle,
                child: Text(S.of(context)!.bulkActionSplit),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.deletePages,
                enabled: isSingle,
                child: Text(S.of(context)!.bulkActionDeletePages),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.editPdf,
                enabled: hasSelection,
                child: Text(S.of(context)!.bulkActionEditPdf),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.modifyCustomFields,
                enabled: hasSelection,
                child: Text(S.of(context)!.bulkActionModifyCustomFields),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.setPermissions,
                enabled: hasSelection,
                child: Text(S.of(context)!.bulkActionSetPermissions),
              ),
              PopupMenuItem(
                value: _BulkSelectionAction.removePassword,
                enabled: hasSelection,
                child: Text(S.of(context)!.bulkActionRemovePassword),
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
                  BulkEditDocumentsRoute(
                    BulkEditExtraWrapper(
                      state.selection,
                      LabelType.correspondent,
                    ),
                  ).push(context);
                },
              ).paddedOnly(left: 8, right: 4),
              ActionChip(
                label: Text(S.of(context)!.documentType),
                avatar: const Icon(Icons.edit),
                onPressed: () async {
                  BulkEditDocumentsRoute(
                    BulkEditExtraWrapper(
                      state.selection,
                      LabelType.documentType,
                    ),
                  ).push(context);
                },
              ).paddedOnly(left: 8, right: 4),
              ActionChip(
                label: Text(S.of(context)!.storagePath),
                avatar: const Icon(Icons.edit),
                onPressed: () async {
                  BulkEditDocumentsRoute(
                    BulkEditExtraWrapper(
                      state.selection,
                      LabelType.storagePath,
                    ),
                  ).push(context);
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
        BulkEditDocumentsRoute(
          BulkEditExtraWrapper(state.selection, LabelType.tag),
        ).push(context);
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
  editPdf,
  modifyCustomFields,
  setPermissions,
  removePassword,
}

Future<void> _handleBulkAction(
  BuildContext context,
  _BulkSelectionAction action,
  List<DocumentModel> selection,
) async {
  if (selection.isEmpty) {
    showSnackBar(context, S.of(context)!.noDocumentsSelected);
    return;
  }
  final documentsCubit = context.read<DocumentsCubit>();
  try {
    switch (action) {
      case _BulkSelectionAction.reprocess:
        final confirmed = await _showConfirmDialog(
          context,
          title: S.of(context)!.reprocessDocumentsTitle,
          message: S.of(context)!.reprocessDocumentsMessage,
        );
        if (!confirmed || !context.mounted) return;
        await documentsCubit.bulkReprocess(selection);
        if (!context.mounted) return;
        showSnackBar(context, S.of(context)!.reprocessQueued);
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.merge:
        if (selection.length < 2) {
          showSnackBar(
            context,
            S.of(context)!.selectAtLeastTwoDocumentsToMerge,
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
        showSnackBar(context, S.of(context)!.mergeQueued);
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.rotate:
        final degrees = await _showRotateDialog(context);
        if (degrees == null || !context.mounted) return;
        await documentsCubit.bulkRotate(selection, degrees: degrees);
        if (!context.mounted) return;
        showSnackBar(context, S.of(context)!.rotateQueued);
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.split:
        if (selection.length != 1) {
          showSnackBar(context, S.of(context)!.selectExactlyOneDocumentToSplit);
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
        showSnackBar(context, S.of(context)!.splitQueued);
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.deletePages:
        if (selection.length != 1) {
          showSnackBar(
            context,
            S.of(context)!.selectExactlyOneDocumentToEditPages,
          );
          return;
        }
        final pages = await _showDeletePagesDialog(context);
        if (pages == null || !context.mounted) return;
        await documentsCubit.bulkDeletePages(selection.first, pages: pages);
        if (!context.mounted) return;
        showSnackBar(context, S.of(context)!.pagesDeleted);
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.editPdf:
        final editResult = await _showEditPdfDialog(context);
        if (editResult == null || !context.mounted) return;
        await documentsCubit.bulkEditPdf(
          selection,
          operations: editResult.operations,
          updateDocument: editResult.updateDocument,
          includeMetadata: editResult.includeMetadata,
        );
        if (!context.mounted) return;
        showSnackBar(context, S.of(context)!.editPdfQueued);
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.modifyCustomFields:
        final customFieldResult = await _showModifyCustomFieldDialog(context);
        if (customFieldResult == null || !context.mounted) return;
        if (customFieldResult.remove) {
          await documentsCubit.bulkModifyCustomFields(
            selection,
            addCustomFields: BulkCustomFieldPayload.ids(const []),
            removeCustomFields: [customFieldResult.fieldId],
          );
        } else {
          await documentsCubit.bulkModifyCustomFields(
            selection,
            addCustomFields: BulkCustomFieldPayload.values({
              customFieldResult.fieldId: customFieldResult.value,
            }),
          );
        }
        if (!context.mounted) return;
        showSnackBar(context, S.of(context)!.customFieldsQueued);
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.setPermissions:
        final permissionsResult = await _showSetPermissionsDialog(context);
        if (permissionsResult == null || !context.mounted) return;
        await documentsCubit.bulkSetPermissions(
          selection,
          permissions: permissionsResult.permissions,
          merge: permissionsResult.merge,
          owner: permissionsResult.owner,
        );
        if (!context.mounted) return;
        showSnackBar(context, S.of(context)!.setPermissionsQueued);
        documentsCubit.resetSelection();
        break;
      case _BulkSelectionAction.removePassword:
        final password = await _showRemovePasswordDialog(context);
        if (password == null || !context.mounted) return;
        await documentsCubit.bulkRemovePassword(selection, password: password);
        if (!context.mounted) return;
        showSnackBar(context, S.of(context)!.removePasswordQueued);
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
            title: Text(S.of(context)!.mergeDocumentsTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(S.of(context)!.mergeDocumentsOrderHint),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(S.of(context)!.deleteOriginals),
                  value: deleteOriginals,
                  onChanged: (value) {
                    setState(() => deleteOriginals = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(S.of(context)!.archiveFallback),
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
            title: Text(S.of(context)!.rotateDocumentsTitle),
            content: DropdownButtonFormField<int>(
              initialValue: selectedDegrees,
              decoration: InputDecoration(labelText: S.of(context)!.degrees),
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
            title: Text(S.of(context)!.splitDocumentTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: S.of(context)!.pages,
                    hintText: S.of(context)!.pageRangeExample,
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(S.of(context)!.deleteOriginal),
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
                      errorText = S.of(context)!.enterPageRanges;
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
            title: Text(S.of(context)!.deletePagesTitle),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: S.of(context)!.pages,
                hintText: S.of(context)!.pageListExample,
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
                      errorText = S.of(context)!.enterValidPageNumbers;
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

class _EditPdfDialogResult {
  final List<Map<String, Object?>> operations;
  final bool updateDocument;
  final bool includeMetadata;

  const _EditPdfDialogResult({
    required this.operations,
    required this.updateDocument,
    required this.includeMetadata,
  });
}

Future<_EditPdfDialogResult?> _showEditPdfDialog(BuildContext context) async {
  return showDialog<_EditPdfDialogResult>(
    context: context,
    builder: (context) {
      final operationsController = TextEditingController(text: '[]');
      bool updateDocument = false;
      bool includeMetadata = true;
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(S.of(context)!.editPdfTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: operationsController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: S.of(context)!.editPdfOperationsJson,
                      hintText: S.of(context)!.editPdfOperationsHint,
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.of(context)!.editPdfUpdateDocument),
                    value: updateDocument,
                    onChanged: (value) =>
                        setState(() => updateDocument = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.of(context)!.editPdfIncludeMetadata),
                    value: includeMetadata,
                    onChanged: (value) =>
                        setState(() => includeMetadata = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context)!.cancel),
              ),
              DialogConfirmButton(
                onPressed: () {
                  final parsedOperations = _parseEditPdfOperations(
                    operationsController.text,
                  );
                  if (parsedOperations == null || parsedOperations.isEmpty) {
                    setState(() {
                      errorText = S.of(context)!.enterValidEditPdfOperations;
                    });
                    return;
                  }
                  Navigator.of(context).pop(
                    _EditPdfDialogResult(
                      operations: parsedOperations,
                      updateDocument: updateDocument,
                      includeMetadata: includeMetadata,
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

List<Map<String, Object?>>? _parseEditPdfOperations(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return null;
    }
    final result = <Map<String, Object?>>[];
    for (final entry in decoded) {
      if (entry is! Map) {
        return null;
      }
      result.add({for (final kv in entry.entries) kv.key.toString(): kv.value});
    }
    return result;
  } catch (_) {
    return null;
  }
}

Future<String?> _showRemovePasswordDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(S.of(context)!.removePasswordTitle),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: S.of(context)!.password,
                errorText: errorText,
              ),
              obscureText: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context)!.cancel),
              ),
              DialogConfirmButton(
                onPressed: () {
                  final password = controller.text.trim();
                  if (password.isEmpty) {
                    setState(() {
                      errorText = S.of(context)!.passwordMustNotBeEmpty;
                    });
                    return;
                  }
                  Navigator.of(context).pop(password);
                },
              ),
            ],
          );
        },
      );
    },
  );
}

class _ModifyCustomFieldDialogResult {
  final int fieldId;
  final Object? value;
  final bool remove;

  const _ModifyCustomFieldDialogResult({
    required this.fieldId,
    required this.value,
    required this.remove,
  });
}

Future<_ModifyCustomFieldDialogResult?> _showModifyCustomFieldDialog(
  BuildContext context,
) async {
  final customFields =
      context
          .read<CustomFieldRepository>()
          .customFields
          .values
          .where((field) => field.id != null)
          .toList()
        ..sort(
          (a, b) => (a.name ?? 'Custom field ${a.id}').toLowerCase().compareTo(
            (b.name ?? 'Custom field ${b.id}').toLowerCase(),
          ),
        );
  if (customFields.isEmpty) {
    showSnackBar(context, S.of(context)!.noCustomFieldsAvailable);
    return null;
  }

  return showDialog<_ModifyCustomFieldDialogResult>(
    context: context,
    builder: (context) {
      int selectedFieldId = customFields.first.id!;
      final valueController = TextEditingController();
      bool boolValue = false;
      bool remove = false;
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          final selectedField = customFields.firstWhere(
            (field) => field.id == selectedFieldId,
          );
          final isBoolean =
              selectedField.dataType == CustomFieldDataType.boolean;
          return AlertDialog(
            title: Text(S.of(context)!.modifyCustomFieldTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedFieldId,
                    decoration: InputDecoration(
                      labelText: S.of(context)!.selectCustomField,
                    ),
                    items: [
                      for (final field in customFields)
                        DropdownMenuItem<int>(
                          value: field.id!,
                          child: Text(field.name ?? 'Custom field ${field.id}'),
                        ),
                    ],
                    onChanged: (newId) {
                      if (newId == null) {
                        return;
                      }
                      setState(() {
                        selectedFieldId = newId;
                        errorText = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isBoolean)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(S.of(context)!.customFieldValue),
                      value: boolValue,
                      onChanged: remove
                          ? null
                          : (value) => setState(() => boolValue = value),
                    )
                  else
                    TextField(
                      controller: valueController,
                      enabled: !remove,
                      keyboardType: _keyboardTypeFor(selectedField.dataType),
                      decoration: InputDecoration(
                        labelText: S.of(context)!.customFieldValue,
                        errorText: errorText,
                      ),
                    ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.of(context)!.clearCustomFieldValue),
                    value: remove,
                    onChanged: (value) => setState(() {
                      remove = value;
                      errorText = null;
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context)!.cancel),
              ),
              DialogConfirmButton(
                onPressed: () {
                  if (remove) {
                    Navigator.of(context).pop(
                      _ModifyCustomFieldDialogResult(
                        fieldId: selectedFieldId,
                        value: null,
                        remove: true,
                      ),
                    );
                    return;
                  }

                  final value = isBoolean
                      ? boolValue
                      : _parseCustomFieldValue(
                          selectedField.dataType,
                          valueController.text,
                        );
                  if (!isBoolean && value == null) {
                    setState(() {
                      errorText = S.of(context)!.enterCustomFieldValue;
                    });
                    return;
                  }
                  Navigator.of(context).pop(
                    _ModifyCustomFieldDialogResult(
                      fieldId: selectedFieldId,
                      value: value,
                      remove: false,
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

TextInputType _keyboardTypeFor(CustomFieldDataType dataType) {
  switch (dataType) {
    case CustomFieldDataType.integer:
      return TextInputType.number;
    case CustomFieldDataType.float:
    case CustomFieldDataType.monetary:
      return const TextInputType.numberWithOptions(decimal: true, signed: true);
    default:
      return TextInputType.text;
  }
}

Object? _parseCustomFieldValue(CustomFieldDataType dataType, String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    return null;
  }
  switch (dataType) {
    case CustomFieldDataType.integer:
      return int.tryParse(value);
    case CustomFieldDataType.float:
    case CustomFieldDataType.monetary:
      return double.tryParse(value);
    default:
      return value;
  }
}

class _SetPermissionsDialogResult {
  final Map<String, dynamic> permissions;
  final bool merge;
  final int? owner;

  const _SetPermissionsDialogResult({
    required this.permissions,
    required this.merge,
    required this.owner,
  });
}

Future<_SetPermissionsDialogResult?> _showSetPermissionsDialog(
  BuildContext context,
) async {
  final users = context.read<UserRepository>().state.users;
  final groups = context.read<GroupRepository>().state.groups;

  return showDialog<_SetPermissionsDialogResult>(
    context: context,
    builder: (context) {
      int? owner;
      List<int> viewUsers = [];
      List<int> viewGroups = [];
      List<int> changeUsers = [];
      List<int> changeGroups = [];
      bool merge = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(S.of(context)!.setPermissionsTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OwnerSelectField(
                    label: S.of(context)!.ownerIdOptional,
                    selectedId: owner,
                    availableUsers: users,
                    onChanged: (value) => setState(() => owner = value),
                  ),
                  const SizedBox(height: 16),
                  UserMultiSelectField(
                    label: S.of(context)!.permissionViewUsers,
                    selectedIds: viewUsers,
                    availableUsers: users,
                    onChanged: (value) => setState(() => viewUsers = value),
                  ),
                  const SizedBox(height: 12),
                  GroupMultiSelectField(
                    label: S.of(context)!.permissionViewGroups,
                    selectedIds: viewGroups,
                    availableGroups: groups,
                    onChanged: (value) => setState(() => viewGroups = value),
                  ),
                  const SizedBox(height: 12),
                  UserMultiSelectField(
                    label: S.of(context)!.permissionChangeUsers,
                    selectedIds: changeUsers,
                    availableUsers: users,
                    onChanged: (value) => setState(() => changeUsers = value),
                  ),
                  const SizedBox(height: 12),
                  GroupMultiSelectField(
                    label: S.of(context)!.permissionChangeGroups,
                    selectedIds: changeGroups,
                    availableGroups: groups,
                    onChanged: (value) => setState(() => changeGroups = value),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.of(context)!.setPermissionsMergeExisting),
                    value: merge,
                    onChanged: (value) => setState(() => merge = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context)!.cancel),
              ),
              DialogConfirmButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    _SetPermissionsDialogResult(
                      permissions: {
                        'view': {'users': viewUsers, 'groups': viewGroups},
                        'change': {
                          'users': changeUsers,
                          'groups': changeGroups,
                        },
                      },
                      merge: merge,
                      owner: owner,
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
