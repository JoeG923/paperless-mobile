import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_mobile/core/widgets/state/pm_empty_state.dart';
import 'package:paperless_mobile/features/inbox/cubit/inbox_cubit.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class InboxEmptyWidget extends StatelessWidget {
  const InboxEmptyWidget({
    super.key,
    required GlobalKey<RefreshIndicatorState> emptyStateRefreshIndicatorKey,
  }) : _emptyStateRefreshIndicatorKey = emptyStateRefreshIndicatorKey;

  final GlobalKey<RefreshIndicatorState> _emptyStateRefreshIndicatorKey;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      key: _emptyStateRefreshIndicatorKey,
      onRefresh: () => context.read<InboxCubit>().loadInbox(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: PmEmptyState(
            icon: Icons.mark_email_read_outlined,
            title: S.of(context)!.youDoNotHaveUnseenDocuments,
            message: 'Inbox zero! All caught up.', // TODO(l10n)
            actionLabel: S.of(context)!.refresh,
            onAction: () => _emptyStateRefreshIndicatorKey.currentState?.show(),
          ),
        ),
      ),
    );
  }
}
