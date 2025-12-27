import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/widgets/highlighted_text.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/details_item.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_widget.dart';
import 'package:paperless_mobile/features/labels/view/widgets/label_text.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class DocumentOverviewWidget extends StatelessWidget {
  final DocumentModel document;
  final String? queryString;
  final double itemSpacing;

  const DocumentOverviewWidget({
    super.key,
    required this.document,
    this.queryString,
    required this.itemSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<LocalUserAccount>().paperlessUser;
    final labelRepository = context.watch<LabelRepository>();
    final children = <Widget>[];

    void addItem(Widget child) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: itemSpacing));
      }
      children.add(child);
    }

    if (document.title.isNotEmpty) {
      addItem(
        DetailsItem(
          label: S.of(context)!.title,
          content: HighlightedText(
            text: document.title,
            highlights: queryString?.split(" ") ?? [],
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    addItem(
      DetailsItem.text(
        DateFormat.yMMMMd(Localizations.localeOf(context).toString())
            .format(document.created),
        context: context,
        label: S.of(context)!.createdAt,
      ),
    );

    if (document.documentType != null && user.canViewDocumentTypes) {
      addItem(
        DetailsItem(
          label: S.of(context)!.documentType,
          content: LabelText<DocumentType>(
            style: Theme.of(context).textTheme.bodyLarge,
            label: labelRepository.documentTypes[document.documentType],
          ),
        ),
      );
    }

    if (document.correspondent != null && user.canViewCorrespondents) {
      addItem(
        DetailsItem(
          label: S.of(context)!.correspondent,
          content: LabelText<Correspondent>(
            style: Theme.of(context).textTheme.bodyLarge,
            label: labelRepository.correspondents[document.correspondent],
          ),
        ),
      );
    }

    if (document.storagePath != null && user.canViewStoragePaths) {
      addItem(
        DetailsItem(
          label: S.of(context)!.storagePath,
          content: LabelText<StoragePath>(
            label: labelRepository.storagePaths[document.storagePath],
          ),
        ),
      );
    }

    if (document.tags.isNotEmpty && user.canViewTags) {
      final tags = document.tags
          .map((e) => labelRepository.tags[e])
          .whereType<Tag>()
          .toList();
      if (tags.isNotEmpty) {
        addItem(
          DetailsItem(
            label: S.of(context)!.tags,
            content: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TagsWidget(
                isClickable: false,
                tags: tags,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
