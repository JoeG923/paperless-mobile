import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/hint_card.dart';
import 'package:paperless_mobile/core/widgets/hint_state_builder.dart';
import 'package:paperless_mobile/core/widgets/state/pm_empty_state.dart';
import 'package:paperless_mobile/features/document_details/cubit/document_details_cubit.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:markdown/markdown.dart' show markdownToHtml;
import 'package:url_launcher/url_launcher_string.dart';

class DocumentNotesWidget extends StatefulWidget {
  final DocumentModel document;
  const DocumentNotesWidget({super.key, required this.document});

  @override
  State<DocumentNotesWidget> createState() => _DocumentNotesWidgetState();
}

class _DocumentNotesWidgetState extends State<DocumentNotesWidget> {
  final _noteContentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isNoteSubmitting = false;

  @override
  Widget build(BuildContext context) {
    const hintKey = "hideMarkdownSyntaxHint";
    return Column(
      children: [
        Expanded(
          child: widget.document.notes.isEmpty
              ? Center(
                  child: PmEmptyState(
                    icon: Icons.note_outlined,
                    title: 'No notes yet', // TODO(l10n)
                    message: 'Add a note below to get started', // TODO(l10n)
                  ),
                )
              : ListView.separated(
                  padding: PmSpacing.pagePadding,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: PmSpacing.md),
                  itemBuilder: (context, index) {
                    final note = widget.document.notes.elementAt(index);
                    return Card.filled(
                      child: Padding(
                        padding: PmSpacing.cardPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Html(
                              data: markdownToHtml(note.note!),
                              onLinkTap: (url, attributes, element) async {
                                if (url?.isEmpty ?? true) {
                                  return;
                                }
                                if (await canLaunchUrlString(url!)) {
                                  launchUrlString(url);
                                }
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (note.created != null)
                                  Text(
                                    DateFormat.yMMMd(
                                          Localizations.localeOf(
                                            context,
                                          ).toString(),
                                        )
                                        .addPattern('•')
                                        .add_jm()
                                        .format(note.created!),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                IconButton(
                                  tooltip: S.of(context)!.delete,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    context
                                        .read<DocumentDetailsCubit>()
                                        .deleteNote(note);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  itemCount: widget.document.notes.length,
                ),
        ),
        Material(
          elevation: PmElevations.level1,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: PmSpacing.pagePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HintStateBuilder(
                    listenKey: hintKey,
                    builder: (context, box) {
                      return HintCard(
                        hintText: S.of(context)!.notesMarkdownSyntaxSupportHint,
                        show: !box.get(hintKey, defaultValue: false)!,
                        onHintAcknowledged: () {
                          box.put(hintKey, true);
                        },
                      );
                    },
                  ),
                  Form(
                    key: _formKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _noteContentController,
                            maxLines: null,
                            minLines: 1,
                            validator: (value) {
                              if (value?.trim().isEmpty ?? true) {
                                return S.of(context)!.thisFieldIsRequired;
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              labelText: S.of(context)!.newNote,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: PmSpacing.sm),
                        IconButton.filledTonal(
                          icon: _isNoteSubmitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          onPressed: _isNoteSubmitting ? null : _onSubmitNote,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onSubmitNote() async {
    _formKey.currentState?.save();
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isNoteSubmitting = true;
      });
      try {
        await context.read<DocumentDetailsCubit>().addNote(
          _noteContentController.text.trim(),
        );
        _noteContentController.clear();
      } catch (error) {
        if (mounted) {
          showGenericError(context, error);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isNoteSubmitting = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _noteContentController.dispose();
    super.dispose();
  }
}
