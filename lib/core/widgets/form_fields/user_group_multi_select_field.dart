import 'package:flutter/material.dart';
import 'package:paperless_api/paperless_api.dart';

/// A chip-based multi-select field for choosing users from a list.
/// Displays selected users as chips and provides a dropdown to add more.
class UserMultiSelectField extends StatelessWidget {
  final String label;
  final List<int> selectedIds;
  final Map<int, UserModel> availableUsers;
  final ValueChanged<List<int>> onChanged;

  const UserMultiSelectField({
    super.key,
    required this.label,
    required this.selectedIds,
    required this.availableUsers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final unselected =
        availableUsers.entries
            .where((e) => !selectedIds.contains(e.key))
            .toList()
          ..sort((a, b) => a.value.username.compareTo(b.value.username));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final id in selectedIds)
              InputChip(
                label: Text(_userLabel(id)),
                onDeleted: () =>
                    onChanged(selectedIds.where((i) => i != id).toList()),
                avatar: const Icon(Icons.person, size: 18),
              ),
            if (unselected.isNotEmpty)
              ActionChip(
                label: const Icon(Icons.add, size: 18),
                onPressed: () => _showAddDialog(context, unselected),
              ),
          ],
        ),
      ],
    );
  }

  String _userLabel(int id) {
    final user = availableUsers[id];
    if (user == null) return '#$id';
    final full = user.fullName;
    if (full != null && full.isNotEmpty) return '$full (${user.username})';
    return user.username;
  }

  void _showAddDialog(
    BuildContext context,
    List<MapEntry<int, UserModel>> unselected,
  ) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => _SelectionDialog(
        items: unselected
            .map((e) => _SelectionItem(id: e.key, label: _userLabel(e.key)))
            .toList(),
      ),
    );
    if (selected != null) {
      onChanged([...selectedIds, selected]);
    }
  }
}

/// A chip-based multi-select field for choosing groups from a list.
class GroupMultiSelectField extends StatelessWidget {
  final String label;
  final List<int> selectedIds;
  final Map<int, GroupModel> availableGroups;
  final ValueChanged<List<int>> onChanged;

  const GroupMultiSelectField({
    super.key,
    required this.label,
    required this.selectedIds,
    required this.availableGroups,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final unselected =
        availableGroups.entries
            .where((e) => !selectedIds.contains(e.key))
            .toList()
          ..sort((a, b) => a.value.name.compareTo(b.value.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final id in selectedIds)
              InputChip(
                label: Text(_groupLabel(id)),
                onDeleted: () =>
                    onChanged(selectedIds.where((i) => i != id).toList()),
                avatar: const Icon(Icons.group, size: 18),
              ),
            if (unselected.isNotEmpty)
              ActionChip(
                label: const Icon(Icons.add, size: 18),
                onPressed: () => _showAddDialog(context, unselected),
              ),
          ],
        ),
      ],
    );
  }

  String _groupLabel(int id) {
    return availableGroups[id]?.name ?? '#$id';
  }

  void _showAddDialog(
    BuildContext context,
    List<MapEntry<int, GroupModel>> unselected,
  ) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => _SelectionDialog(
        items: unselected
            .map((e) => _SelectionItem(id: e.key, label: e.value.name))
            .toList(),
      ),
    );
    if (selected != null) {
      onChanged([...selectedIds, selected]);
    }
  }
}

/// A single-select dropdown for choosing an owner (user).
class OwnerSelectField extends StatelessWidget {
  final String label;
  final int? selectedId;
  final Map<int, UserModel> availableUsers;
  final ValueChanged<int?> onChanged;

  const OwnerSelectField({
    super.key,
    required this.label,
    required this.selectedId,
    required this.availableUsers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sortedUsers = availableUsers.entries.toList()
      ..sort((a, b) => a.value.username.compareTo(b.value.username));

    return DropdownButtonFormField<int?>(
      initialValue: selectedId,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(
            '—',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final entry in sortedUsers)
          DropdownMenuItem<int?>(
            value: entry.key,
            child: Text(_userLabel(entry.key)),
          ),
      ],
      onChanged: onChanged,
    );
  }

  String _userLabel(int id) {
    final user = availableUsers[id];
    if (user == null) return '#$id';
    final full = user.fullName;
    if (full != null && full.isNotEmpty) return '$full (${user.username})';
    return user.username;
  }
}

class _SelectionItem {
  final int id;
  final String label;
  const _SelectionItem({required this.id, required this.label});
}

class _SelectionDialog extends StatefulWidget {
  final List<_SelectionItem> items;
  const _SelectionDialog({required this.items});

  @override
  State<_SelectionDialog> createState() => _SelectionDialogState();
}

class _SelectionDialogState extends State<_SelectionDialog> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty
        ? widget.items
        : widget.items
              .where(
                (i) => i.label.toLowerCase().contains(_filter.toLowerCase()),
              )
              .toList();

    return AlertDialog(
      contentPadding: const EdgeInsets.only(top: 16),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _filter = value),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return ListTile(
                    title: Text(item.label),
                    onTap: () => Navigator.of(context).pop(item.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
