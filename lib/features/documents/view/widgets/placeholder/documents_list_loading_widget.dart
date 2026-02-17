import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/widgets/shimmer_placeholder.dart';
import 'package:paperless_mobile/features/documents/view/widgets/placeholder/tags_placeholder.dart';
import 'package:paperless_mobile/features/documents/view/widgets/placeholder/text_placeholder.dart';

class DocumentsListLoadingWidget extends StatelessWidget {
  final bool _isSliver;
  const DocumentsListLoadingWidget({super.key}) : _isSliver = false;

  const DocumentsListLoadingWidget.sliver({super.key}) : _isSliver = true;

  @override
  Widget build(BuildContext context) {
    if (_isSliver) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildFakeListItem(context),
        ),
      );
    } else {
      return ListView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => _buildFakeListItem(context),
      );
    }
  }

  Widget _buildFakeListItem(BuildContext context) {
    const fontSize = 14.0;
    return ShimmerPlaceholder(
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        dense: true,
        isThreeLine: true,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.white,
            height: double.infinity,
            width: 35,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TextPlaceholder(length: 120, fontSize: fontSize),
            const SizedBox(height: 2),
            TextPlaceholder(
              length: 220,
              fontSize: Theme.of(context).textTheme.titleMedium!.fontSize!,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const TagsPlaceholder(count: 2, dense: true),
              const SizedBox(height: 2),
              TextPlaceholder(
                length: 250,
                fontSize: Theme.of(context).textTheme.labelSmall!.fontSize!,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
