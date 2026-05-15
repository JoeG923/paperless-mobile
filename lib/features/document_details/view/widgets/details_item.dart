import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';

class DetailsItem extends StatelessWidget {
  final String label;
  final Widget content;
  final IconData? icon;
  final VoidCallback? onTap;

  const DetailsItem({
    super.key,
    required this.label,
    required this.content,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: PmSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: PmSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                content,
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onTap,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PmRadii.sm),
        child: child,
      );
    }

    return child;
  }

  DetailsItem.text(
    String text, {
    super.key,
    required this.label,
    required BuildContext context,
    this.icon,
    this.onTap,
  }) : content = Text(text, style: Theme.of(context).textTheme.bodyMedium);
}
