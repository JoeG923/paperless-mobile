import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';

/// A reusable error-state widget for surfaces that fail to load.
///
/// Pair with a retry callback when available.
class PmErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final IconData icon;

  const PmErrorState({
    super.key,
    required this.title,
    this.message,
    this.retryLabel,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.xl,
          vertical: PmSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(PmSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.onErrorContainer),
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
            if (retryLabel != null && onRetry != null) ...[
              const SizedBox(height: PmSpacing.lg),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
