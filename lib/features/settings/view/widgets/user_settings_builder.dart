import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';

class UserAccountBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, LocalUserAccount? settings)
  builder;

  const UserAccountBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<LocalUserAccount>>(
      valueListenable: Hive.box<LocalUserAccount>(
        HiveBoxes.localUserAccount,
      ).listenable(),
      builder: (context, accountBox, _) {
        final currentUser = Hive.box<GlobalSettings>(
          HiveBoxes.globalSettings,
        ).getValue()!.loggedInUserId;
        if (currentUser != null) {
          final account = accountBox.get(currentUser);
          return builder(context, account);
        } else {
          return builder(context, null);
        }
      },
    );
  }
}
