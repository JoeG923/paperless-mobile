import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/widgets/state/pm_empty_state.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/paged_documents_state.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class DocumentsEmptyState extends StatelessWidget {
  final DocumentPagingState state;
  final VoidCallback? onReset;

  const DocumentsEmptyState({super.key, required this.state, this.onReset});

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter =
        state.filter != DocumentFilter.initial && onReset != null;
    return PmEmptyState(
      icon: Icons.description_outlined,
      title: S.of(context)!.noDocumentsFound,
      actionLabel: hasActiveFilter ? S.of(context)!.resetFilter : null,
      onAction: hasActiveFilter
          ? () {
              HapticFeedback.mediumImpact();
              onReset!();
            }
          : null,
    );
  }
}
