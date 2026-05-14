import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';

class ExpansionCard extends StatelessWidget {
  final Widget title;
  final Widget content;

  final bool initiallyExpanded;

  const ExpansionCard({
    super.key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainer,
      margin: const EdgeInsets.symmetric(
        horizontal: PmSpacing.lg,
        vertical: PmSpacing.sm,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: ExpansionTileThemeData(
            shape: RoundedRectangleBorder(borderRadius: PmRadii.rmd),
            collapsedShape: RoundedRectangleBorder(borderRadius: PmRadii.rmd),
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            tilePadding: const EdgeInsets.symmetric(horizontal: PmSpacing.lg),
            childrenPadding: const EdgeInsets.fromLTRB(
              PmSpacing.lg,
              0,
              PmSpacing.lg,
              PmSpacing.lg,
            ),
          ),
          listTileTheme: ListTileThemeData(
            shape: RoundedRectangleBorder(borderRadius: PmRadii.rmd),
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: title,
          children: [content],
        ),
      ),
    );
  }
}
