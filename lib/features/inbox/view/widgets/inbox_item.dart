import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/extensions/document_extensions.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/util/lambda_utils.dart';
import 'package:paperless_mobile/core/widgets/shimmer_placeholder.dart';
import 'package:paperless_mobile/features/documents/view/widgets/delete_document_confirmation_dialog.dart';
import 'package:paperless_mobile/features/documents/view/widgets/document_preview.dart';
import 'package:paperless_mobile/features/documents/view/widgets/placeholder/tags_placeholder.dart';
import 'package:paperless_mobile/features/documents/view/widgets/placeholder/text_placeholder.dart';
import 'package:paperless_mobile/features/inbox/cubit/inbox_cubit.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_widget.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/connectivity_aware_action_wrapper.dart';
import 'package:paperless_mobile/routing/routes/documents_route.dart';

/// Shimmer skeleton shown during inbox loading.
class InboxItemPlaceholder extends StatelessWidget {
  const InboxItemPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PmSpacing.md,
        vertical: PmSpacing.xs,
      ),
      child: ShimmerPlaceholder(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail skeleton
            ClipRRect(
              borderRadius: PmRadii.rmd,
              child: Container(
                width: 72,
                height: 102, // 72 / a4AspectRatio ≈ 102
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: PmRadii.rmd,
                ),
              ),
            ),
            const SizedBox(width: PmSpacing.md),
            // Text skeletons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TextPlaceholder(length: 200, fontSize: 14),
                  const SizedBox(height: PmSpacing.xs),
                  const TextPlaceholder(length: 130, fontSize: 12),
                  const SizedBox(height: PmSpacing.sm),
                  const TagsPlaceholder(count: 3, dense: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InboxItem extends StatefulWidget {
  static const a4AspectRatio = 1 / 1.4142;

  final DocumentModel document;

  const InboxItem({super.key, required this.document});

  @override
  State<InboxItem> createState() => _InboxItemState();
}

class _InboxItemState extends State<InboxItem> {
  bool _isAsnAssignLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelRepository = context.watch<LabelRepository>();
    final currentUser = context.watch<LocalUserAccount>().paperlessUser;

    return InkWell(
      onTap: () => DocumentDetailsRoute(
        title: widget.document.title,
        id: widget.document.id,
        thumbnailUrl: widget.document.buildThumbnailUrl(context),
        isLabelClickable: false,
      ).push(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.md,
          vertical: PmSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large thumbnail
            ClipRRect(
              borderRadius: PmRadii.rmd,
              child: Container(
                width: 72,
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant, width: 0.5),
                  borderRadius: PmRadii.rmd,
                ),
                child: AspectRatio(
                  aspectRatio: InboxItem.a4AspectRatio,
                  child: DocumentPreview(
                    documentId: widget.document.id,
                    title: widget.document.title,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    enableHero: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: PmSpacing.md),
            // Content column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.document.title.isEmpty ? '-' : widget.document.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Metadata: correspondent · date
                  Text(
                    _buildMetadataText(context, labelRepository),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Tag chips (max 3 + overflow)
                  if (widget.document.tags.isNotEmpty) ...[
                    const SizedBox(height: PmSpacing.xs),
                    _buildTagsRow(labelRepository),
                  ],
                  // Quick-action chips
                  if (currentUser.canEditDocuments ||
                      currentUser.canDeleteDocuments) ...[
                    const SizedBox(height: PmSpacing.sm),
                    ConnectivityAwareActionWrapper(
                      child: _buildActionRow(context, currentUser),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildMetadataText(
    BuildContext context,
    LabelRepository labelRepository,
  ) {
    final parts = <String>[];
    final correspondent =
        labelRepository.correspondents[widget.document.correspondent];
    if (correspondent != null) {
      parts.add(correspondent.name);
    }
    parts.add(
      DateFormat.yMMMMd(
        Localizations.localeOf(context).toString(),
      ).format(widget.document.added),
    );
    return parts.join(' · ');
  }

  Widget _buildTagsRow(LabelRepository labelRepository) {
    final tags = widget.document.tags
        .where((e) => labelRepository.tags.containsKey(e))
        .map((e) => labelRepository.tags[e]!)
        .where(isNotNull)
        .toList()
        .cast<Tag>();

    const maxVisible = 3;
    final visibleTags = tags.take(maxVisible).toList();
    final overflow = tags.length - maxVisible;

    return Wrap(
      spacing: PmSpacing.xs,
      runSpacing: PmSpacing.xs,
      children: [
        ...visibleTags.map(
          (tag) => TagsWidget(isClickable: false, tags: [tag]),
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

  Widget _buildActionRow(BuildContext context, UserModel currentUser) {
    final chipShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(32),
    );
    final actions = <Widget>[
      if (currentUser.canEditDocuments) _buildAssignAsnChip(chipShape, context),
      if (currentUser.canEditDocuments && currentUser.canDeleteDocuments)
        const SizedBox(width: PmSpacing.sm),
      if (currentUser.canDeleteDocuments) _buildDeleteChip(chipShape, context),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }

  Widget _buildAssignAsnChip(
    RoundedRectangleBorder chipShape,
    BuildContext context,
  ) {
    final hasAsn = widget.document.archiveSerialNumber != null;
    return ActionChip(
      avatar: _isAsnAssignLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : hasAsn
          ? null
          : const Icon(Icons.archive_outlined),
      shape: chipShape,
      label: hasAsn
          ? Text(
              '${S.of(context)!.asn} #${widget.document.archiveSerialNumber}',
            )
          : Text(S.of(context)!.assignAsn),
      onPressed: (!hasAsn && !_isAsnAssignLoading)
          ? () {
              setState(() => _isAsnAssignLoading = true);
              context
                  .read<InboxCubit>()
                  .assignAsn(widget.document)
                  .whenComplete(
                    () => setState(() => _isAsnAssignLoading = false),
                  );
            }
          : null,
    );
  }

  Widget _buildDeleteChip(
    RoundedRectangleBorder chipShape,
    BuildContext context,
  ) {
    return ActionChip(
      avatar: const Icon(Icons.delete_outline),
      shape: chipShape,
      label: Text(S.of(context)!.deleteDocument),
      onPressed: () async {
        final shouldDelete =
            await showDialog<bool>(
              context: context,
              builder: (context) =>
                  DeleteDocumentConfirmationDialog(document: widget.document),
            ) ??
            false;
        if (shouldDelete && context.mounted) {
          context.read<InboxCubit>().delete(widget.document);
        }
      },
    );
  }
}
