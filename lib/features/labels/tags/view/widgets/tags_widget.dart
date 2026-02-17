import 'package:flutter/material.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tag_widget.dart';

class TagsWidget extends StatelessWidget {
  final List<Tag> tags;
  final void Function(int tagId)? onTagSelected;
  final bool isClickable;
  final bool showShortNames;
  final bool dense;

  const TagsWidget({
    super.key,
    required this.tags,
    this.onTagSelected,
    this.isClickable = true,
    this.showShortNames = false,
    this.dense = true,
  });

  List<Widget> get _children {
    return [
      for (var tag in tags)
        TagWidget(
          tag: tag,
          isClickable: isClickable,
          onSelected: () => onTagSelected?.call(tag.id!),
          showShortName: showShortNames,
          dense: dense,
        ),
    ];
  }

  const factory TagsWidget.multiLine({
    Key? key,
    required List<Tag> tags,
    required void Function(int tagId)? onTagSelected,
    required bool isClickable,
    required bool showShortNames,
    required bool dense,
  }) = _MultiLineTagsWidget;

  const factory TagsWidget.sliver({
    Key? key,
    required List<Tag> tags,
    void Function(int tagId)? onTagSelected,
    bool isClickable,
    bool showShortNames,
    bool dense,
  }) = _SliverTagsWidget;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: _children),
    );
  }
}

class _MultiLineTagsWidget extends TagsWidget {
  const _MultiLineTagsWidget({
    super.key,
    required super.tags,
    super.onTagSelected,
    super.isClickable,
    super.showShortNames,
    super.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runAlignment: WrapAlignment.start,
      runSpacing: 4,
      spacing: 4,
      children: _children,
    );
  }
}

class _SliverTagsWidget extends TagsWidget {
  const _SliverTagsWidget({
    super.key,
    required super.tags,
    super.isClickable,
    super.showShortNames,
    super.dense,
    super.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList.list(children: _children);
  }
}
