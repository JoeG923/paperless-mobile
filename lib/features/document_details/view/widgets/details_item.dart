import 'package:flutter/material.dart';

class DetailsItem extends StatelessWidget {
  final String label;
  final Widget content;
  const DetailsItem({super.key, required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        content,
      ],
    );
  }

  DetailsItem.text(
    String text, {
    super.key,
    required this.label,
    required BuildContext context,
  }) : content = Text(text, style: Theme.of(context).textTheme.bodyLarge);
}
