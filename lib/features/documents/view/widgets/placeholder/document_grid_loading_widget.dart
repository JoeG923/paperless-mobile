import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/shimmer_placeholder.dart';

class DocumentGridLoadingWidget extends StatelessWidget {
  final bool _isSliver;
  @override
  const DocumentGridLoadingWidget({super.key}) : _isSliver = false;

  const DocumentGridLoadingWidget.sliver({super.key}) : _isSliver = true;

  @override
  Widget build(BuildContext context) {
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      mainAxisExtent: 324,
    );
    if (_isSliver) {
      return SliverGrid.builder(
        gridDelegate: delegate,
        itemCount: 6,
        itemBuilder: (context, index) => _buildPlaceholderGridItem(context),
      );
    }
    return GridView.builder(
      gridDelegate: delegate,
      itemCount: 6,
      itemBuilder: (context, index) => _buildPlaceholderGridItem(context),
    );
  }

  Widget _buildPlaceholderGridItem(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ShimmerPlaceholder(
        child: Card.filled(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail placeholder
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(PmRadii.lg),
                    ),
                  ),
                ),
              ),
              // Content placeholder
              Padding(
                padding: const EdgeInsets.all(PmSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: PmRadii.rsm,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 14,
                      width: 100,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: PmRadii.rsm,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 120,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: PmRadii.rsm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
