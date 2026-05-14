import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/widgets/state/pm_empty_state.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class OfflineWidget extends StatelessWidget {
  const OfflineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return PmEmptyState(
      icon: Icons.wifi_off_rounded,
      title: S.of(context)!.anInternetConnectionCouldNotBeEstablished,
    );
  }
}
