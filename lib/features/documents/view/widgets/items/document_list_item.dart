import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/documents/view/widgets/document_preview.dart';
import 'package:paperless_mobile/features/documents/view/widgets/items/document_item.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_widget.dart';
import 'package:provider/provider.dart';

class DocumentListItem extends DocumentItem {
  static const _a4AspectRatio = 1 / 1.4142;

  final Color? backgroundColor;
  const DocumentListItem({
    super.key,
    this.backgroundColor,
    required super.document,
    required super.isSelected,
    required super.isSelectionActive,
    required super.isLabelClickable,
    super.onCorrespondentSelected,
    super.onDocumentTypeSelected,
    super.onSelected,
    super.onStoragePathSelected,
    super.onTagSelected,
    super.onTap,
    super.enableHeroAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    final labelRepository = context.watch<LabelRepository>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PmSpacing.md,
        vertical: PmSpacing.xs,
      ),
      child: InkWell(
        onTap: _onTap,
        onLongPress: onSelected != null ? () => onSelected!(document) : null,
        borderRadius: PmRadii.rmd,
        child: Container(
          padding: const EdgeInsets.all(PmSpacing.sm),
          decoration: isSelected
              ? BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: PmRadii.rmd,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading thumbnail
              ClipRRect(
                borderRadius: PmRadii.rmd,
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: scheme.outlineVariant,
                      width: 0.5,
                    ),
                    borderRadius: PmRadii.rmd,
                  ),
                  child: AspectRatio(
                    aspectRatio: _a4AspectRatio,
                    child: DocumentPreview(
                      documentId: document.id,
                      title: document.title,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      enableHero: enableHeroAnimation,
                      borderRadius: PmRadii.md,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PmSpacing.md),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      document.title.isEmpty ? '-' : document.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Metadata row
                    Text(
                      _buildMetadataText(context, labelRepository),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Tags row
                    if (document.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      AbsorbPointer(
                        absorbing: isSelectionActive,
                        child: _buildTagsRow(labelRepository),
                      ),
                    ],
                  ],
                ),
              ),
              // Trailing selection indicator
              if (isSelectionActive) ...[
                const SizedBox(width: PmSpacing.sm),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: isSelected ? scheme.primary : scheme.outline,
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildMetadataText(
    BuildContext context,
    LabelRepository labelRepository,
  ) {
    final parts = <String>[];

    // Correspondent
    final correspondent =
        labelRepository.correspondents[document.correspondent];
    if (correspondent != null) {
      parts.add(correspondent.name);
    }

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

  Widget _buildTagsRow(LabelRepository labelRepository) {
    final tags = document.tags
        .where((e) => labelRepository.tags.containsKey(e))
        .map((e) => labelRepository.tags[e]!)
        .toList();

    // Show max 4 tags + overflow indicator
    const maxVisible = 4;
    final visibleTags = tags.take(maxVisible).toList();
    final overflow = tags.length - maxVisible;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...visibleTags.map(
          (tag) => TagsWidget(
            isClickable: isLabelClickable,
            tags: [tag],
            onTagSelected: onTagSelected,
          ),
        ),
        if (overflow > 0)
          Chip(
            label: Text('+$overflow'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          ),
      ],
    );
  }

  void _onTap() {
    if (isSelectionActive || isSelected) {
      onSelected?.call(document);
    } else {
      onTap?.call(document);
    }
  }
}
