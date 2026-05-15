import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/documents/view/widgets/document_preview.dart';
import 'package:paperless_mobile/features/inbox/cubit/inbox_cubit.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/routing/routes/documents_route.dart';

/// Shows a card preview of the most recent inbox documents (up to 3).
///
/// Tapping a document opens its details. The "View all" button navigates to
/// the full inbox page via [onViewAll].
class InboxPreviewCard extends StatelessWidget {
  static const _previewCount = 3;

  final VoidCallback onViewAll;

  const InboxPreviewCard({super.key, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      shape: PmRadii.cardShape,
      elevation: PmElevations.level1,
      child: Padding(
        padding: PmSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inbox_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: PmSpacing.sm),
                Expanded(
                  child: Text(
                    S.of(context)!.inbox,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    S.of(context)!.documentsInInbox, // TODO(l10n): "View all"
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PmSpacing.sm),
            BlocBuilder<InboxCubit, InboxState>(
              builder: (context, state) {
                if (state.isLoading && !state.hasLoaded) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: PmSpacing.lg),
                    child: LinearProgressIndicator(),
                  );
                }

                if (!state.hasLoaded) {
                  // Cubit has not loaded yet — show a subtle placeholder.
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: PmSpacing.lg),
                    child: LinearProgressIndicator(),
                  );
                }

                final docs = state.documents.take(_previewCount).toList();

                if (docs.isEmpty) {
                  return _InlineEmptyState(scheme: scheme, theme: theme);
                }

                return Column(
                  children: [
                    for (final doc in docs) ...[
                      _InboxDocumentRow(document: doc),
                      if (doc != docs.last)
                        Divider(
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact single-row preview of an inbox document.
class _InboxDocumentRow extends StatelessWidget {
  static const _a4AspectRatio = 1 / 1.4142;
  static const _thumbWidth = 44.0;

  final DocumentModel document;

  const _InboxDocumentRow({required this.document});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateFormat = DateFormat.yMMMd();

    return InkWell(
      onTap: () => DocumentDetailsRoute(id: document.id).push(context),
      borderRadius: PmRadii.rsm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PmSpacing.sm),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: PmRadii.rsm,
              child: Container(
                width: _thumbWidth,
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant, width: 0.5),
                  borderRadius: PmRadii.rsm,
                ),
                child: AspectRatio(
                  aspectRatio: _a4AspectRatio,
                  child: DocumentPreview(
                    documentId: document.id,
                    title: document.title,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    enableHero: false,
                    isClickable: false,
                    borderRadius: PmRadii.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: PmSpacing.md),
            // Title + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title.isEmpty ? '-' : document.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFormat.format(document.created),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small inline empty state shown when the inbox has no documents.
class _InlineEmptyState extends StatelessWidget {
  final ColorScheme scheme;
  final ThemeData theme;

  const _InlineEmptyState({required this.scheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PmSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: scheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: PmSpacing.sm),
          Text(
            // TODO(l10n): "No new documents"
            'No new documents',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
