import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/documents/view/widgets/document_preview.dart';
import 'package:paperless_mobile/features/documents/view/widgets/items/document_item.dart';
import 'package:provider/provider.dart';

class DocumentGridItem extends DocumentItem {
  const DocumentGridItem({
    super.key,
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
    required super.enableHeroAnimation,
  });

  @override
  Widget build(BuildContext context) {
    var currentUser = context.watch<LocalUserAccount>().paperlessUser;
    final labelRepository = context.watch<LabelRepository>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Stack(
      children: [
        Card.filled(
          color: isSelected ? scheme.primaryContainer : null,
          child: InkWell(
            borderRadius: PmRadii.rlg,
            onTap: _onTap,
            onLongPress: onSelected != null
                ? () => onSelected!(document)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(PmRadii.lg),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DocumentPreview(
                          documentId: document.id,
                          borderRadius: 0,
                          enableHero: enableHeroAnimation,
                          title: document.title,
                          fit: BoxFit.cover,
                        ),
                        // Selection check overlay
                        if (isSelectionActive)
                          Positioned(
                            top: PmSpacing.sm,
                            left: PmSpacing.sm,
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
                                color: isSelected
                                    ? scheme.primary
                                    : scheme.outline,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(PmSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        document.title.isEmpty ? '-' : document.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      // Metadata
                      Text(
                        _buildMetadataText(context, labelRepository),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      // Tag indicators (up to 2 dots + overflow)
                      if (currentUser.canViewTags &&
                          document.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _buildTagIndicators(labelRepository, theme, scheme),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _buildMetadataText(
    BuildContext context,
    LabelRepository labelRepository,
  ) {
    final parts = <String>[];

    // Created date
    parts.add(
      DateFormat.yMd(
        Localizations.localeOf(context).toString(),
      ).format(document.created),
    );

    // ASN if present
    if (document.archiveSerialNumber != null) {
      parts.add('#${document.archiveSerialNumber}');
    }

    return parts.join(' · ');
  }

  Widget _buildTagIndicators(
    LabelRepository labelRepository,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final tags = document.tags
        .map((e) => labelRepository.tags[e])
        .whereType<Tag>()
        .toList();

    const maxDots = 2;
    final visibleTags = tags.take(maxDots).toList();
    final overflow = tags.length - maxDots;

    return Row(
      children: [
        ...visibleTags.map(
          (tag) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: tag.color, shape: BoxShape.circle),
          ),
        ),
        if (overflow > 0)
          Text(
            '+$overflow',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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
