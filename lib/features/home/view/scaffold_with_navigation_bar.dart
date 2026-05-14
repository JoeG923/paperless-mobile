import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/app_drawer/view/app_drawer.dart';
import 'package:paperless_mobile/features/inbox/cubit/inbox_cubit.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/theme.dart';

class ScaffoldWithNavigationBar extends StatefulWidget {
  final UserModel authenticatedUser;
  final StatefulNavigationShell navigationShell;
  const ScaffoldWithNavigationBar({
    super.key,
    required this.authenticatedUser,
    required this.navigationShell,
  });

  @override
  State<ScaffoldWithNavigationBar> createState() =>
      ScaffoldWithNavigationBarState();
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool enabled;
  final Widget Function(BuildContext context, Widget child)? badgeBuilder;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.enabled,
    this.badgeBuilder,
  });
}

class ScaffoldWithNavigationBarState extends State<ScaffoldWithNavigationBar> {
  List<_NavItem> _buildItems(BuildContext context) {
    final user = widget.authenticatedUser;
    final l10n = S.of(context)!;
    return [
      _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: l10n.home,
        enabled: true,
      ),
      _NavItem(
        icon: Icons.description_outlined,
        selectedIcon: Icons.description_rounded,
        label: l10n.documents,
        enabled: user.canViewDocuments,
      ),
      _NavItem(
        icon: Icons.document_scanner_outlined,
        selectedIcon: Icons.document_scanner_rounded,
        label: l10n.scanner,
        enabled: user.canCreateDocuments,
      ),
      _NavItem(
        icon: Icons.sell_outlined,
        selectedIcon: Icons.sell_rounded,
        label: l10n.labels,
        enabled: user.canViewAnyLabel,
      ),
      _NavItem(
        icon: Icons.inbox_outlined,
        selectedIcon: Icons.inbox_rounded,
        label: l10n.inbox,
        enabled: user.canViewInbox,
        badgeBuilder: (context, child) => BlocBuilder<InboxCubit, InboxState>(
          builder: (context, state) {
            return Badge.count(
              isLabelVisible: state.itemsInInboxCount > 0 && user.canViewInbox,
              count: state.itemsInInboxCount,
              child: child,
            );
          },
        ),
      ),
    ];
  }

  void _onSelected(int index, bool enabled) {
    if (!enabled) return;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _buildItems(context);
    final currentIndex = widget.navigationShell.currentIndex;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: buildOverlayStyle(theme),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useRail = constraints.maxWidth >= PmBreakpoints.mediumWidth;
          if (useRail) {
            return Scaffold(
              drawer: const AppDrawer(),
              body: Row(
                children: [
                  _buildRail(context, items, currentIndex),
                  VerticalDivider(
                    width: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Expanded(child: widget.navigationShell),
                ],
              ),
            );
          }
          return Scaffold(
            drawer: const AppDrawer(),
            bottomNavigationBar: _buildBottomNav(context, items, currentIndex),
            body: widget.navigationShell,
          );
        },
      ),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    List<_NavItem> items,
    int currentIndex,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        _onSelected(index, items[index].enabled);
      },
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: _wrapIcon(item, item.icon, scheme.onSurfaceVariant),
            selectedIcon: _wrapIcon(item, item.selectedIcon, null),
            label: item.label,
            tooltip: item.label,
          ),
      ],
    );
  }

  Widget _wrapIcon(_NavItem item, IconData iconData, Color? disabledColor) {
    final icon = Icon(iconData, color: item.enabled ? null : disabledColor);
    final wrapped = item.badgeBuilder?.call(context, icon) ?? icon;
    return Opacity(opacity: item.enabled ? 1.0 : 0.45, child: wrapped);
  }

  Widget _buildRail(
    BuildContext context,
    List<_NavItem> items,
    int currentIndex,
  ) {
    final extended =
        MediaQuery.sizeOf(context).width >= PmBreakpoints.largeWidth;
    return NavigationRail(
      extended: extended,
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        _onSelected(index, items[index].enabled);
      },
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: _wrapIcon(
              item,
              item.icon,
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selectedIcon: _wrapIcon(item, item.selectedIcon, null),
            label: Text(item.label),
          ),
      ],
    );
  }
}
