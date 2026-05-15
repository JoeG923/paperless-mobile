import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';

/// Quick-filter chips for common document queries.
/// Shows: All, Untagged, + active saved view chip with close action.
class DocumentFilterChipsRow extends StatelessWidget {
  const DocumentFilterChipsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentsCubit, DocumentsState>(
      builder: (context, state) {
        final hasActiveView = state.filter.selectedView != null;
        final hasUntaggedFilter = _hasUntaggedFilter(state.filter);
        final hasAnyFilter =
            state.filter.appliedFiltersCount > 0 || hasActiveView;

        return Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(
            horizontal: PmSpacing.md,
            vertical: PmSpacing.xs,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Clear all filter chip (if any filters active)
                if (hasAnyFilter) ...[
                  FilterChip(
                    label: Text('Clear filters'), // TODO(l10n)
                    onSelected: (_) => _clearAllFilters(context),
                    selected: false,
                    avatar: const Icon(Icons.close, size: 18),
                  ),
                  const SizedBox(width: PmSpacing.sm),
                ],
                // "Untagged" quick filter
                FilterChip(
                  label: Text('Untagged'), // TODO(l10n)
                  onSelected: (_) => _toggleUntaggedFilter(context),
                  selected: hasUntaggedFilter,
                ),
                const SizedBox(width: PmSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasUntaggedFilter(DocumentFilter filter) {
    return filter.tags is NotAssignedTagsQuery;
  }

  void _toggleUntaggedFilter(BuildContext context) {
    final cubit = context.read<DocumentsCubit>();
    final currentFilter = cubit.state.filter;
    final isActive = _hasUntaggedFilter(currentFilter);

    if (isActive) {
      cubit.updateCurrentFilter(
        (f) => f.copyWith(tags: DocumentFilter.initial.tags),
      );
    } else {
      cubit.updateCurrentFilter(
        (f) => f.copyWith(tags: const NotAssignedTagsQuery()),
      );
    }
  }

  void _clearAllFilters(BuildContext context) {
    context.read<DocumentsCubit>().resetFilter();
  }
}
