import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/shimmer_placeholder.dart';

class DocumentsListLoadingWidget extends StatelessWidget {
  final bool _isSliver;
  const DocumentsListLoadingWidget({super.key}) : _isSliver = false;

  const DocumentsListLoadingWidget.sliver({super.key}) : _isSliver = true;

  @override
  Widget build(BuildContext context) {
    if (_isSliver) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildShimmerItem(context),
          childCount: 6,
        ),
      );
    } else {
      return ListView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (context, index) => _buildShimmerItem(context),
      );
    }
  }

  Widget _buildShimmerItem(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PmSpacing.md,
        vertical: PmSpacing.xs,
      ),
      child: ShimmerPlaceholder(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail placeholder
            Container(
              width: 56,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: PmRadii.rmd,
              ),
            ),
            const SizedBox(width: PmSpacing.md),
            // Content placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: PmRadii.rsm,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: PmRadii.rsm,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        height: 24,
                        width: 60,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: PmRadii.rsm,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 24,
                        width: 60,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: PmRadii.rsm,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
