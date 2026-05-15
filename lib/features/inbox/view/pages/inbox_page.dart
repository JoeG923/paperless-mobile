import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/exception/server_message_exception.dart';
import 'package:paperless_mobile/core/extensions/dart_extensions.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_cancel_button.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_confirm_button.dart';
import 'package:paperless_mobile/core/widgets/state/pm_empty_state.dart';
import 'package:paperless_mobile/core/widgets/state/pm_loading_state.dart';
import 'package:paperless_mobile/features/app_drawer/view/app_drawer.dart';
import 'package:paperless_mobile/features/inbox/cubit/inbox_cubit.dart';
import 'package:paperless_mobile/features/inbox/view/widgets/inbox_item.dart';
import 'package:paperless_mobile/features/paged_document_view/view/document_paging_view_mixin.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/connectivity_aware_action_wrapper.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage>
    with DocumentPagingViewMixin<InboxPage, InboxCubit> {
  @override
  final pagingScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<InboxCubit>().reloadInbox();
  }

  @override
  Widget build(BuildContext context) {
    final canEditDocument = context
        .watch<LocalUserAccount>()
        .paperlessUser
        .canEditDocuments;
    return Scaffold(
      drawer: const AppDrawer(),
      floatingActionButton: _buildFab(context, canEditDocument),
      body: BlocBuilder<InboxCubit, InboxState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<InboxCubit>().reload(),
            child: CustomScrollView(
              controller: pagingScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildSliverAppBar(context, state),
                ..._buildSliverContent(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, InboxState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = state.itemsInInboxCount;
    return SliverAppBar.large(
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(
          left: PmSpacing.lg,
          bottom: PmSpacing.lg,
          right: 80,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.of(context)!.inbox, style: theme.textTheme.titleLarge),
            if (state.hasLoaded && count > 0)
              Text(
                '$count ${count == 1 ? "document" : "documents"}', // TODO(l10n)
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSliverContent(BuildContext context, InboxState state) {
    // Initial loading — no cached data yet
    if (!state.hasLoaded && state.documents.isEmpty) {
      return [
        SliverList.builder(
          itemCount: 5,
          itemBuilder: (_, _) => const PmShimmerListItem(height: 88),
        ),
      ];
    }

    // Loaded, empty inbox
    if (state.hasLoaded && state.documents.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PmEmptyState(
            icon: Icons.mark_email_read_outlined,
            title: S.of(context)!.youDoNotHaveUnseenDocuments,
            message: 'Inbox zero! All caught up.', // TODO(l10n)
            actionLabel: S.of(context)!.refresh,
            onAction: () => context.read<InboxCubit>().loadInbox(),
          ),
        ),
      ];
    }

    // Loaded with documents — date-grouped list
    final groups = _groupByDate(state.documents);
    return [
      ...groups.entries.expand(
        (entry) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: PmSpacing.lg,
                right: PmSpacing.lg,
                top: PmSpacing.md,
                bottom: PmSpacing.xs,
              ),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: entry.value.length,
            itemBuilder: (context, index) =>
                _buildDismissibleTile(entry.value[index]),
          ),
        ],
      ),
      // Bottom padding to clear the FAB
      const SliverToBoxAdapter(child: SizedBox(height: 88)),
    ];
  }

  Widget _buildDismissibleTile(DocumentModel doc) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.startToEnd,
      background: ColoredBox(
        color: scheme.primary,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: PmSpacing.xl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.done_all, color: scheme.onPrimary),
                const SizedBox(width: PmSpacing.sm),
                Text(
                  S.of(context)!.markAsSeen,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      confirmDismiss: (_) => _onItemDismissed(doc),
      child: InboxItem(document: doc),
    );
  }

  Widget _buildFab(BuildContext context, bool canEditDocument) {
    return ConnectivityAwareActionWrapper(
      offlineBuilder: (context, child) => const SizedBox.shrink(),
      child: BlocBuilder<InboxCubit, InboxState>(
        builder: (context, state) {
          if (!state.hasLoaded || state.documents.isEmpty || !canEditDocument) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            heroTag: 'inbox_page_fab',
            icon: const Icon(Icons.done_all),
            label: Text(S.of(context)!.allSeen),
            onPressed: () => _onMarkAllAsSeen(state.documents, state.inboxTags),
          );
        },
      ),
    );
  }

  Future<void> _onMarkAllAsSeen(
    Iterable<DocumentModel> documents,
    Iterable<int> inboxTags,
  ) async {
    final isActionConfirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(S.of(context)!.markAllAsSeen),
            content: Text(
              S.of(context)!.areYouSureYouWantToMarkAllDocumentsAsSeen,
            ),
            actions: [
              const DialogCancelButton(),
              DialogConfirmButton(
                label: S.of(context)!.markAsSeen,
                style: DialogConfirmButtonStyle.danger,
              ),
            ],
          ),
        ) ??
        false;
    if (isActionConfirmed && mounted) {
      await context.read<InboxCubit>().clearInbox();
    }
  }

  Future<bool> _onItemDismissed(DocumentModel doc) async {
    if (!context.read<LocalUserAccount>().paperlessUser.canEditDocuments) {
      showSnackBar(context, S.of(context)!.missingPermissions);
      return false;
    }
    final isConnectedToInternet = await context
        .read<ConnectivityStatusService>()
        .isConnectedToInternet();
    if (!isConnectedToInternet) {
      if (mounted) showSnackBar(context, S.of(context)!.youAreCurrentlyOffline);
      return false;
    }
    try {
      if (mounted) {
        final removedTags = await context.read<InboxCubit>().removeFromInbox(
          doc,
        );
        if (mounted) {
          showSnackBar(
            context,
            S.of(context)!.removeDocumentFromInbox,
            action: SnackBarActionConfig(
              label: S.of(context)!.undo,
              onPressed: () => _onUndoMarkAsSeen(doc, removedTags),
            ),
          );
        }
      }
      return true;
    } on PaperlessApiException catch (error, stackTrace) {
      if (mounted) showErrorMessage(context, error, stackTrace);
    } on ServerMessageException catch (error) {
      if (mounted) showGenericError(context, error.message);
    } catch (error) {
      if (mounted) {
        showErrorMessage(context, const PaperlessApiException.unknown());
      }
    }
    return false;
  }

  Future<void> _onUndoMarkAsSeen(
    DocumentModel document,
    Iterable<int> removedTags,
  ) async {
    try {
      await context.read<InboxCubit>().undoRemoveFromInbox(
        document,
        removedTags,
      );
    } on PaperlessApiException catch (error, stackTrace) {
      if (mounted) showErrorMessage(context, error, stackTrace);
    }
  }

  Map<String, List<DocumentModel>> _groupByDate(
    Iterable<DocumentModel> documents,
  ) {
    return groupBy<DocumentModel, String>(documents, (doc) {
      if (doc.added.isToday) return S.of(context)!.today;
      if (doc.added.isYesterday) return S.of(context)!.yesterday;
      return DateFormat.yMMMMd(
        Localizations.localeOf(context).toString(),
      ).format(doc.added);
    });
  }
}
