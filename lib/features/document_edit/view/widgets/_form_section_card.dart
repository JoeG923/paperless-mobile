import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';

/// A titled card that wraps a group of form fields into a visual section.
class FormSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const FormSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: PmSpacing.lg),
      shape: PmRadii.cardShape,
      elevation: PmElevations.level1,
      child: Padding(
        padding: PmSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: PmSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}
