import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';

/// A reusable empty-state widget that follows the app's Material 3 language.
///
/// Use this anywhere a screen would otherwise render an ad-hoc `Center` with a
/// plain `Text`. Provides consistent spacing, hierarchy, and an optional CTA.
class PmEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const PmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(
      horizontal: PmSpacing.xl,
      vertical: PmSpacing.xxl,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(PmSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: PmSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: PmSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: PmSpacing.lg),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
