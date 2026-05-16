import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_mobile/accessibility/accessibility_utils.dart';
import 'package:paperless_mobile/core/extensions/document_extensions.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/state/pm_empty_state.dart';
import 'package:paperless_mobile/features/document_search/cubit/document_search_cubit.dart';
import 'package:paperless_mobile/features/document_search/view/remove_history_entry_dialog.dart';
import 'package:paperless_mobile/features/documents/view/widgets/adaptive_documents_view.dart';
import 'package:paperless_mobile/features/documents/view/widgets/selection/view_type_selection_widget.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/routing/routes/documents_route.dart';

class DocumentSearchPage extends StatefulWidget {
  const DocumentSearchPage({super.key});

  @override
  State<DocumentSearchPage> createState() => _DocumentSearchPageState();
}

class _DocumentSearchPageState extends State<DocumentSearchPage> {
  final _queryController = TextEditingController(text: '');
  final _queryFocusNode = FocusNode();

  Timer? _debounceTimer;

  String get query => _queryController.text.trim();

  @override
  Widget build(BuildContext context) {
    const double progressIndicatorHeight = 4;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        toolbarHeight: 72 - progressIndicatorHeight,
        leading: BackButton(color: scheme.onSurfaceVariant),
        title: Hero(
          tag: "search_hero_tag",
          child: TextField(
            autofocus: true,
            focusNode: _queryFocusNode,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.zero,
              hintText: S.of(context)!.searchDocuments,
              border: InputBorder.none,
            ),
            controller: _queryController,
            onChanged: (query) {
              setState(() {});
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                context.read<DocumentSearchCubit>().suggest(query);
              });
            },
            textInputAction: TextInputAction.search,
            onSubmitted: (query) {
              if (query.trim().isNotEmpty) {
                FocusScope.of(context).unfocus();
                _debounceTimer?.cancel();
                context.read<DocumentSearchCubit>().search(query);
              }
            },
          ),
        ).accessible(),
        actions: [
          if (_queryController.text.isNotEmpty)
            IconButton(
              color: scheme.onSurfaceVariant,
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _queryController.clear();
                });
                context.read<DocumentSearchCubit>().reset();
                _queryFocusNode.requestFocus();
              },
            ).padded(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(progressIndicatorHeight),
          child: BlocBuilder<DocumentSearchCubit, DocumentSearchState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const LinearProgressIndicator();
              }
              return const Divider(height: 1, thickness: 1);
            },
          ),
        ),
      ),
      body: BlocBuilder<DocumentSearchCubit, DocumentSearchState>(
        builder: (context, state) {
          switch (state.view) {
            case SearchView.suggestions:
              return _buildSuggestionsView(state);
            case SearchView.results:
              return _buildResultsView(state);
          }
        },
      ),
    );
  }

  Widget _buildSuggestionsView(DocumentSearchState state) {
    final suggestions = state.suggestions
        .whereNot((element) => state.searchHistory.contains(element))
        .toList();
    final historyMatches = query.isEmpty
        ? <String>[]
        : state.searchHistory
              .where(
                (element) =>
                    element.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();

    final showRecentSearches = query.isEmpty && state.searchHistory.isNotEmpty;

    if (!showRecentSearches &&
        historyMatches.isEmpty &&
        suggestions.isEmpty &&
        state.hasLoaded) {
      return PmEmptyState(
        icon: Icons.search_off_outlined,
        title: S.of(context)!.noMatchesFound,
      );
    }

    return CustomScrollView(
      slivers: [
        if (showRecentSearches) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PmSpacing.lg,
                PmSpacing.md,
                PmSpacing.sm,
                PmSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent searches', // TODO(l10n)
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _onClearAllHistory(),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: PmSpacing.md,
              vertical: PmSpacing.xs,
            ),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: PmSpacing.sm,
                runSpacing: PmSpacing.sm,
                children: state.searchHistory.take(10).map((entry) {
                  return InputChip(
                    avatar: const Icon(Icons.history, size: 18),
                    label: Text(entry),
                    onDeleted: () => _onDeleteHistoryEntry(entry),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onPressed: () => _selectSuggestion(entry),
                  );
                }).toList(),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: PmSpacing.md)),
        ],
        if (historyMatches.isNotEmpty && query.isNotEmpty) ...[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ListTile(
                dense: true,
                title: Text(historyMatches[index]),
                leading: const Icon(Icons.history),
                onTap: () => _selectSuggestion(historyMatches[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.north_west),
                  onPressed: () => _insertSuggestion(historyMatches[index]),
                ),
              ),
              childCount: historyMatches.length,
            ),
          ),
        ],
        if (suggestions.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ListTile(
                dense: true,
                title: Text(suggestions[index]),
                leading: const Icon(Icons.search),
                onTap: () => _selectSuggestion(suggestions[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.north_west),
                  onPressed: () => _insertSuggestion(suggestions[index]),
                ),
              ),
              childCount: suggestions.length,
            ),
          ),
      ],
    );
  }

  void _onDeleteHistoryEntry(String entry) async {
    final shouldRemove =
        await showDialog<bool>(
          context: context,
          builder: (context) => RemoveHistoryEntryDialog(entry: entry),
        ) ??
        false;
    if (shouldRemove && mounted) {
      context.read<DocumentSearchCubit>().removeHistoryEntry(entry);
    }
  }

  void _onClearAllHistory() async {
    final shouldClear =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog.adaptive(
            title: const Text('Clear all search history'), // TODO(l10n)
            content: const Text(
              'This will remove all recent searches.',
            ), // TODO(l10n)
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(S.of(context)!.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Clear'), // TODO(l10n)
              ),
            ],
          ),
        ) ??
        false;

    if (shouldClear && mounted) {
      final cubit = context.read<DocumentSearchCubit>();
      for (final entry in cubit.state.searchHistory.toList()) {
        cubit.removeHistoryEntry(entry);
      }
    }
  }

  void _insertSuggestion(String suggestion) {
    setState(() {
      _queryController.text = '$suggestion ';
      _queryController.selection = TextSelection.fromPosition(
        TextPosition(offset: _queryController.text.length),
      );
    });
    _queryFocusNode.requestFocus();
  }

  Widget _buildResultsView(DocumentSearchState state) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        PmSpacing.lg,
        PmSpacing.md,
        PmSpacing.sm,
        PmSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Results for "$query"', // TODO(l10n)
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ViewTypeSelectionWidget(
            viewType: state.viewType,
            onChanged: (type) =>
                context.read<DocumentSearchCubit>().updateViewType(type),
          ),
        ],
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        if (state.hasLoaded && !state.isLoading && state.documents.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: PmEmptyState(
              icon: Icons.find_in_page_outlined,
              title: S.of(context)!.noDocumentsFound,
            ),
          )
        else
          SliverAdaptiveDocumentsView(
            viewType: state.viewType,
            documents: state.documents,
            isLabelClickable: false,
            isLoading: state.isLoading,
            hasLoaded: state.hasLoaded,
            enableHeroAnimation: false,
            onTap: (document) {
              DocumentDetailsRoute(
                title: document.title,
                id: document.id,
                isLabelClickable: false,
                thumbnailUrl: document.buildThumbnailUrl(context),
              ).push(context);
            },
          ),
      ],
    );
  }

  void _selectSuggestion(String suggestion) {
    setState(() {
      _queryController.text = suggestion;
    });
    context.read<DocumentSearchCubit>().search(suggestion);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
