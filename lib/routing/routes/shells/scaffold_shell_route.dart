import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/features/home/view/scaffold_with_navigation_bar.dart';

class ScaffoldShellRoute extends StatefulShellRouteData {
  const ScaffoldShellRoute();

  static Widget $navigatorContainerBuilder(
    BuildContext context,
    StatefulNavigationShell navigationShell,
    List<Widget> children,
  ) {
    return children[navigationShell.currentIndex];
  }

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    final currentUserId = Hive.box<GlobalSettings>(
      HiveBoxes.globalSettings,
    ).getValue()!.loggedInUserId!;
    final authenticatedUser = Hive.box<LocalUserAccount>(
      HiveBoxes.localUserAccount,
    ).get(currentUserId)!;
    return ScaffoldWithNavigationBar(
      authenticatedUser: authenticatedUser.paperlessUser,
      navigationShell: navigationShell,
    );
  }
}
