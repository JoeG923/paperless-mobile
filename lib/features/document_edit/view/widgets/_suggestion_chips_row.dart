import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/workarounds/colored_chip.dart';

typedef ChipItemBuilder<T> = Widget Function(BuildContext context, T item);

/// A horizontal scrolling row of suggestion chips beneath a label.
class SuggestionChipsRow<T> extends StatelessWidget {
  final String label;
  final Iterable<T> suggestions;
  final ChipItemBuilder<T> itemBuilder;

  const SuggestionChipsRow({
    super.key,
    required this.label,
    required this.suggestions,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: PmSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PmSpacing.xs),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              itemBuilder: (context, index) => ColoredChipWrapper(
                child: itemBuilder(context, suggestions.elementAt(index)),
              ),
              separatorBuilder: (context, index) =>
                  const SizedBox(width: PmSpacing.xs),
            ),
          ),
        ],
      ),
    );
  }
}
