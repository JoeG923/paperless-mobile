import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/documents/view/widgets/document_preview.dart';
import 'package:paperless_mobile/features/documents/view/widgets/items/document_item.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_widget.dart';
import 'package:provider/provider.dart';

class DocumentDetailedItem extends DocumentItem {
  final String? highlights;
  const DocumentDetailedItem({
    super.key,
    this.highlights,
    required super.document,
    required super.isSelected,
    required super.isSelectionActive,
    required super.isLabelClickable,
    required super.enableHeroAnimation,
    super.onCorrespondentSelected,
    super.onDocumentTypeSelected,
    super.onSelected,
    super.onStoragePathSelected,
    super.onTagSelected,
    super.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = Hive.box<GlobalSettings>(
      HiveBoxes.globalSettings,
    ).getValue()!.loggedInUserId;
    final paperlessUser = Hive.box<LocalUserAccount>(
      HiveBoxes.localUserAccount,
    ).get(currentUserId)!.paperlessUser;
    final size = MediaQuery.of(context).size;
    final insets = MediaQuery.of(context).viewInsets;
    final padding = MediaQuery.of(context).viewPadding;
    final availableHeight =
        size.height -
        insets.top -
        insets.bottom -
        padding.top -
        padding.bottom -
        kBottomNavigationBarHeight -
        kToolbarHeight;
    final maxHeight = highlights != null
        ? min(600.0, availableHeight)
        : min(500.0, availableHeight);
    final labelRepository = context.watch<LabelRepository>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: isSelected ? scheme.primaryContainer : null,
      child: InkWell(
        enableFeedback: true,
        borderRadius: PmRadii.rmd,
        onTap: () {
          if (isSelectionActive) {
            onSelected?.call(document);
          } else {
            onTap?.call(document);
          }
        },
        onLongPress: () {
          onSelected?.call(document);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ConstrainedBox(
              constraints: BoxConstraints.tightFor(
                width: double.infinity,
                height: maxHeight / 2,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(PmRadii.md),
                    ),
                    child: DocumentPreview(
                      documentId: document.id,
                      title: document.title,
                      borderRadius: 0,
                    ),
                  ),
                  // Selection indicator
                  if (isSelectionActive)
                    Positioned(
                      top: PmSpacing.sm,
                      right: PmSpacing.sm,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected ? scheme.primary : scheme.outline,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Metadata content
            Padding(
              padding: const EdgeInsets.all(PmSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Correspondent
                  if (paperlessUser.canViewCorrespondents &&
                      document.correspondent != null) ...[
                    Text(
                      labelRepository
                              .correspondents[document.correspondent]
                              ?.name ??
                          '',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Title
                  Text(
                    document.title.isEmpty ? '(-)' : document.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Metadata row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _buildMetadataText(context, labelRepository),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (document.archiveSerialNumber != null)
                        Text(
                          '#${document.archiveSerialNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  // Tags
                  if (paperlessUser.canViewTags &&
                      document.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TagsWidget(
                      tags: document.tags
                          .map((e) => labelRepository.tags[e])
                          .whereType<Tag>()
                          .toList(),
                      onTagSelected: onTagSelected,
                      isClickable: isLabelClickable,
                    ),
                  ],
                  // Highlights
                  if (highlights != null) ...[
                    const SizedBox(height: 8),
                    Html(
                      data: '<p>$highlights</p>',
                      style: {
                        "span": Style(
                          backgroundColor: Colors.yellow,
                          color: Colors.black,
                        ),
                        "p": Style(
                          maxLines: 3,
                          textOverflow: TextOverflow.ellipsis,
                        ),
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).padded();
  }

  String _buildMetadataText(
    BuildContext context,
    LabelRepository labelRepository,
  ) {
    final parts = <String>[];

    // Created date
    parts.add(
      DateFormat.yMMMMd(
        Localizations.localeOf(context).toString(),
      ).format(document.created),
    );

    // Document type
    final docType = labelRepository.documentTypes[document.documentType];
    if (docType != null) {
      parts.add(docType.name);
    }

    return parts.join(' · ');
  }
}
