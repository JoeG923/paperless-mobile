import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class OfflineBanner extends StatelessWidget implements PreferredSizeWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PmSpacing.lg,
            vertical: PmSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: PmSpacing.sm),
              Text(
                S.of(context)!.youreOffline,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(36);
}
