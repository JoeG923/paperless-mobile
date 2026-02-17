import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_extensions.dart';
import 'package:paperless_mobile/features/login/cubit/authentication_cubit.dart';
import 'package:paperless_mobile/features/users/view/widgets/user_account_list_tile.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/routing/routes/login_route.dart';

class LoginToExistingAccountPage extends StatelessWidget {
  const LoginToExistingAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.localUserAccountBox.listenable(),
      builder: (context, value, _) {
        final localAccounts = value.values;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(S.of(context)!.logInToExistingAccount),
          ),
          bottomNavigationBar: BottomAppBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  child: Text(S.of(context)!.addAnotherAccount),
                  onPressed: () {
                    const LoginRoute().go(context);
                  },
                ),
              ],
            ),
          ),
          body: ListView.builder(
            itemBuilder: (context, index) {
              final account = localAccounts.elementAt(index);
              return Card(
                child: UserAccountListTile(
                  account: account,
                  onTap: () {
                    context.read<AuthenticationCubit>().switchAccount(
                      account.id,
                    );
                  },
                  trailing: IconButton(
                    tooltip: S.of(context)!.remove,
                    icon: Icon(Icons.close),
                    onPressed: () {
                      context.read<AuthenticationCubit>().removeAccount(
                        account.id,
                      );
                    },
                  ),
                ),
              );
            },
            itemCount: localAccounts.length,
          ),
        );
      },
    );
  }
}
