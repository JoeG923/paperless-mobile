import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/constants.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/app_drawer/view/app_drawer.dart';
import 'package:paperless_mobile/features/document_search/cubit/document_search_cubit.dart';
import 'package:paperless_mobile/features/document_search/view/document_search_page.dart';
import 'package:paperless_mobile/features/inbox/cubit/inbox_cubit.dart';
import 'package:paperless_mobile/features/landing/view/widgets/inbox_preview_card.dart';
import 'package:paperless_mobile/features/landing/view/widgets/quick_action_tile.dart';
import 'package:paperless_mobile/features/landing/view/widgets/stats_card.dart';
import 'package:paperless_mobile/features/saved_view/cubit/saved_view_cubit.dart';
import 'package:paperless_mobile/features/saved_view_details/view/saved_view_preview.dart';
import 'package:paperless_mobile/features/settings/view/widgets/user_avatar.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/routing/routes/changelog_route.dart';
import 'package:paperless_mobile/routing/routes/documents_route.dart';
import 'package:paperless_mobile/routing/routes/inbox_route.dart';
import 'package:paperless_mobile/routing/routes/saved_views_route.dart';
import 'package:paperless_mobile/routing/routes/scanner_route.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // Incremented on pull-to-refresh to force FutureBuilder widgets to re-fetch.
  int _statsKey = 0;

  Future<bool> get _shouldShowChangelog async {
    try {
      final sp = await SharedPreferences.getInstance();
      final currentBuild = packageInfo.buildNumber;
      final existingVersions = sp.getStringList('changelogSeenForBuilds') ?? [];
      if (existingVersions.contains(currentBuild)) {
        return false;
      } else {
        existingVersions.add(currentBuild);
        await sp.setStringList('changelogSeenForBuilds', existingVersions);
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (await _shouldShowChangelog && mounted) {
        ChangelogRoute().push(context);
      }
    });
    // Pre-load inbox documents for the preview card, separately so there is
    // no async gap before the context access (avoids use_build_context_synchronously).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<LocalUserAccount>().paperlessUser;
      if (user.canViewInbox) {
        context.read<InboxCubit>().reloadInbox();
      }
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _statsKey++);
    final user = context.read<LocalUserAccount>().paperlessUser;
    final inboxCubit = user.canViewInbox ? context.read<InboxCubit>() : null;
    final savedViewCubit = context.read<SavedViewCubit>();
    await inboxCubit?.reloadInbox();
    await savedViewCubit.reload();
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<LocalUserAccount>();
    final user = account.paperlessUser;

    return Scaffold(
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            _GreetingAppBar(account: account),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                PmSpacing.lg,
                PmSpacing.lg,
                PmSpacing.lg,
                PmSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: _QuickActionsRow(user: user, outerContext: context),
              ),
            ),
            if (user.canViewInbox)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PmSpacing.lg,
                  vertical: PmSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: InboxPreviewCard(
                    onViewAll: () => InboxRoute().go(context),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: PmSpacing.lg,
                vertical: PmSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: StatsCard(key: ValueKey(_statsKey)),
              ),
            ),
            if (user.canViewSavedViews) ..._buildSavedViewsSection(context),
            const SliverPadding(
              padding: EdgeInsets.only(bottom: PmSpacing.xxl),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSavedViewsSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          PmSpacing.lg,
          PmSpacing.lg,
          PmSpacing.lg,
          PmSpacing.sm,
        ),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Icon(Icons.saved_search_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: PmSpacing.sm),
              Text(
                S.of(context)!.views,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      BlocBuilder<SavedViewCubit, SavedViewState>(
        builder: (context, state) {
          return state.maybeWhen(
            loaded: (savedViews) {
              final dashboardViews = savedViews.values
                  .where((v) => v.showOnDashboard)
                  .toList();
              if (dashboardViews.isEmpty) {
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: PmSpacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context)!.youDidNotSaveAnyViewsYet,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => const CreateSavedViewRoute(
                            showOnDashboard: true,
                          ).push(context),
                          icon: const Icon(Icons.add),
                          label: Text(S.of(context)!.newView),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverList.builder(
                itemCount: dashboardViews.length,
                itemBuilder: (context, index) => SavedViewPreview(
                  savedView: dashboardViews[index],
                  expanded: index == 0,
                ),
              );
            },
            orElse: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(PmSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        },
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Greeting SliverAppBar
// ---------------------------------------------------------------------------

class _GreetingAppBar extends StatelessWidget {
  final LocalUserAccount account;

  const _GreetingAppBar({required this.account});

  @override
  Widget build(BuildContext context) {
    final user = account.paperlessUser;
    final displayName = user.fullName ?? user.username;
    final host = Uri.tryParse(account.serverUrl)?.host.isNotEmpty == true
        ? Uri.parse(account.serverUrl).host
        : account.serverUrl;

    return SliverAppBar(
      pinned: true,
      floating: true,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: MaterialLocalizations.of(ctx).openAppDrawerTooltip,
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.of(context)!.welcomeUser(displayName),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            host,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: PmSpacing.md),
          child: UserAvatar(account: account),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-actions row
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  final UserModel user;

  /// The landing page's [BuildContext], needed so [OpenContainer]'s openBuilder
  /// can read providers from the widget tree.
  final BuildContext outerContext;

  const _QuickActionsRow({required this.user, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan
        Expanded(
          child: QuickActionTile(
            icon: Icons.document_scanner_rounded,
            label: S.of(context)!.scan,
            containerColor: scheme.primaryContainer,
            iconColor: scheme.onPrimaryContainer,
            onTap: () => const ScannerRoute().go(context),
          ),
        ),
        const SizedBox(width: PmSpacing.sm),
        // Search uses OpenContainer for the same fade-through as the search bar.
        if (user.canViewDocuments) ...[
          Expanded(child: _SearchTile(outerContext: outerContext)),
          const SizedBox(width: PmSpacing.sm),
        ],
        // Inbox
        if (user.canViewInbox) ...[
          Expanded(child: _InboxTile(scheme: scheme)),
          const SizedBox(width: PmSpacing.sm),
        ],
        // Documents
        if (user.canViewDocuments)
          Expanded(
            child: QuickActionTile(
              icon: Icons.folder_rounded,
              label: S.of(context)!.documents,
              containerColor: scheme.tertiaryContainer,
              iconColor: scheme.onTertiaryContainer,
              onTap: () => DocumentsRoute().go(context),
            ),
          ),
      ],
    );
  }
}

/// Search quick-action tile using [OpenContainer] for a fade-through transition
/// identical to the search bar used elsewhere in the app.
class _SearchTile extends StatelessWidget {
  final BuildContext outerContext;

  const _SearchTile({required this.outerContext});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final containerColor = scheme.secondaryContainer;
    final contentColor = scheme.onSecondaryContainer;

    return OpenContainer<void>(
      transitionDuration: PmDurations.medium,
      transitionType: ContainerTransitionType.fadeThrough,
      closedElevation: 0,
      closedColor: containerColor,
      openColor: scheme.surface,
      closedShape: RoundedRectangleBorder(borderRadius: PmRadii.rmd),
      openBuilder: (ctx, closeFn) => Provider(
        create: (_) => DocumentSearchCubit(
          outerContext.read<PaperlessDocumentsApi>(),
          outerContext.read<DocumentChangedNotifier>(),
          Hive.box<LocalUserAppState>(
            HiveBoxes.localUserAppState,
          ).get(outerContext.read<LocalUserAccount>().id)!,
          outerContext.read<ConnectivityStatusService>(),
        ),
        child: const DocumentSearchPage(),
      ),
      closedBuilder: (_, action) => InkWell(
        onTap: action,
        borderRadius: PmRadii.rmd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PmSpacing.sm,
              vertical: PmSpacing.md,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_rounded, size: 32, color: contentColor),
                const SizedBox(height: PmSpacing.xs),
                Text(
                  S.of(context)!.search,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: contentColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inbox quick-action tile with a badge showing the unread count.
class _InboxTile extends StatelessWidget {
  final ColorScheme scheme;

  const _InboxTile({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InboxCubit, InboxState>(
      builder: (context, state) {
        final count = state.itemsInInboxCount;
        return QuickActionTile(
          icon: Icons.inbox_rounded,
          label: S.of(context)!.inbox,
          containerColor: scheme.secondaryContainer,
          iconColor: scheme.onSecondaryContainer,
          onTap: () => InboxRoute().go(context),
          badge: count > 0 ? _CountBadge(count: count, scheme: scheme) : null,
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final ColorScheme scheme;

  const _CountBadge({required this.count, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PmSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(PmRadii.xs),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: scheme.onError,
        ),
      ),
    );
  }
}
