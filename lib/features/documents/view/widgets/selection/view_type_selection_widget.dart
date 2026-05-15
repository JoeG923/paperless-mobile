import 'package:flutter/material.dart';
import 'package:paperless_mobile/features/settings/model/view_type.dart';

/// Meant to be used with blocbuilder.
class ViewTypeSelectionWidget extends StatelessWidget {
  final ViewType viewType;
  final void Function(ViewType type) onChanged;

  const ViewTypeSelectionWidget({
    super.key,
    required this.viewType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ViewType>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ViewType.list,
          icon: Icon(Icons.view_list, size: 20),
        ),
        ButtonSegment(
          value: ViewType.grid,
          icon: Icon(Icons.grid_view_rounded, size: 20),
        ),
        ButtonSegment(
          value: ViewType.detailed,
          icon: Icon(Icons.view_agenda_outlined, size: 20),
        ),
      ],
      selected: {viewType},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
