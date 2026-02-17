import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';

class TagsPlaceholder extends StatelessWidget {
  static const _lengths = <double>[90, 70, 130];
  final int count;
  final bool dense;
  const TagsPlaceholder({super.key, required this.count, required this.dense});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: List.generate(count, (index) => index)
              .map(
                (index) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  width: _lengths[index % _lengths.length],
                  height: 32,
                ).paddedOnly(right: 4),
              )
              .toList(),
        ),
      ),
    );
  }
}
