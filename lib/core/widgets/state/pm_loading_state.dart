import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/shimmer_placeholder.dart';

/// Reusable shimmer skeleton row used for list/loading states.
class PmShimmerListItem extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry padding;

  const PmShimmerListItem({
    super.key,
    this.height = 72,
    this.padding = const EdgeInsets.symmetric(
      horizontal: PmSpacing.lg,
      vertical: PmSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: ShimmerPlaceholder(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: PmRadii.rmd,
          ),
        ),
      ),
    );
  }
}

/// Full-page loading state composed of shimmer skeletons.
class PmLoadingState extends StatelessWidget {
  final int itemCount;

  const PmLoadingState({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: PmSpacing.sm),
      children: List.generate(itemCount, (_) => const PmShimmerListItem()),
    );
  }
}
