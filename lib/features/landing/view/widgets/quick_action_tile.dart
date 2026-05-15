import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';

/// A large, thumb-friendly action tile used in the landing page quick-actions row.
///
/// Designed to be wrapped in [Expanded] inside a [Row].
class QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color containerColor;
  final Color iconColor;

  /// Optional badge widget overlaid on the icon (e.g. inbox count).
  final Widget? badge;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.containerColor,
    required this.iconColor,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: containerColor,
      borderRadius: PmRadii.rmd,
      child: InkWell(
        onTap: onTap,
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
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topRight,
                  children: [
                    Icon(icon, size: 32, color: iconColor),
                    if (badge != null)
                      Positioned(top: -6, right: -6, child: badge!),
                  ],
                ),
                const SizedBox(height: PmSpacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: iconColor,
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
