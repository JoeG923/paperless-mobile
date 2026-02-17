import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/group_repository.dart';
import 'package:paperless_mobile/core/repository/user_repository.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_confirm_button.dart';
import 'package:paperless_mobile/core/widgets/form_fields/user_group_multi_select_field.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/details_item.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class DocumentPermissionsUpdate {
  final Map<String, dynamic> permissions;
  final bool merge;
  final int? owner;

  const DocumentPermissionsUpdate({
    required this.permissions,
    required this.merge,
    this.owner,
  });
}

typedef DocumentPermissionsUpdateCallback =
    Future<void> Function(DocumentPermissionsUpdate update);

class DocumentPermissionsWidget extends StatefulWidget {
  final DocumentModel document;
  final DocumentPermissionsUpdateCallback? onUpdatePermissions;

  const DocumentPermissionsWidget({
    super.key,
    required this.document,
    this.onUpdatePermissions,
  });

  @override
  State<DocumentPermissionsWidget> createState() =>
      _DocumentPermissionsWidgetState();
}

class _DocumentPermissionsWidgetState extends State<DocumentPermissionsWidget> {
  PaperlessApiException? _loadError;

  @override
  void initState() {
    super.initState();
    _loadUsersIfNeeded();
  }

  Future<void> _loadUsersIfNeeded() async {
    final repo = context.read<UserRepository>();
    if (repo.state.users.isNotEmpty) {
      return;
    }
    try {
      await repo.initialize();
    } on PaperlessApiException catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserRepository, UserRepositoryState>(
      builder: (context, userState) {
        final groupRepo = context.watch<GroupRepository>();
        final groupState = groupRepo.state;
        final permissions = widget.document.permissions;
        final owner = widget.document.owner == null
            ? S.of(context)!.documentOwnerUnassigned
            : _resolveUserLabel(widget.document.owner!, userState.users);

        if (permissions == null) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                S.of(context)!.permissionsUnavailable,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final viewUsers = permissions.view.users
            .map((id) => _resolveUserLabel(id, userState.users))
            .toList();
        final viewGroups = permissions.view.groups
            .map((id) => _resolveGroupLabel(id, groupState.groups))
            .toList();
        final changeUsers = permissions.change.users
            .map((id) => _resolveUserLabel(id, userState.users))
            .toList();
        final changeGroups = permissions.change.groups
            .map((id) => _resolveGroupLabel(id, groupState.groups))
            .toList();
        final hasAnyPermissions =
            viewUsers.isNotEmpty ||
            viewGroups.isNotEmpty ||
            changeUsers.isNotEmpty ||
            changeGroups.isNotEmpty;
        final canManagePermissions =
            (widget.document.userCanChange ?? false) &&
            widget.onUpdatePermissions != null;

        return SliverList.list(
          children: [
            DetailsItem.text(
              owner,
              label: S.of(context)!.documentOwner,
              context: context,
            ),
            if (canManagePermissions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _onManagePermissions,
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: Text(S.of(context)!.managePermissions),
                    ),
                  ],
                ),
              ),
            if (!hasAnyPermissions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(S.of(context)!.permissionsNoneMessage),
              ),
            if (viewUsers.isNotEmpty)
              DetailsItem(
                label: S.of(context)!.permissionViewUsers,
                content: _buildChips(viewUsers),
              ),
            if (viewGroups.isNotEmpty)
              DetailsItem(
                label: S.of(context)!.permissionViewGroups,
                content: _buildChips(viewGroups),
              ),
            if (changeUsers.isNotEmpty)
              DetailsItem(
                label: S.of(context)!.permissionChangeUsers,
                content: _buildChips(changeUsers),
              ),
            if (changeGroups.isNotEmpty)
              DetailsItem(
                label: S.of(context)!.permissionChangeGroups,
                content: _buildChips(changeGroups),
              ),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  S.of(context)!.permissionsUserLookupFailed,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }

  String _resolveUserLabel(int userId, Map<int, UserModel> users) {
    return users[userId]?.username ?? '#$userId';
  }

  String _resolveGroupLabel(int groupId, Map<int, GroupModel> groups) =>
      groups[groupId]?.name ?? '#$groupId';

  Widget _buildChips(List<String> labels) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final label in labels) Chip(label: Text(label))],
    );
  }

  Future<void> _onManagePermissions() async {
    final update = await _showSetPermissionsDialog(
      context,
      initialOwner: widget.document.owner,
      initialViewUsers: widget.document.permissions?.view.users ?? const [],
      initialViewGroups: widget.document.permissions?.view.groups ?? const [],
      initialChangeUsers: widget.document.permissions?.change.users ?? const [],
      initialChangeGroups:
          widget.document.permissions?.change.groups ?? const [],
    );
    if (!mounted || update == null || widget.onUpdatePermissions == null) {
      return;
    }
    try {
      await widget.onUpdatePermissions!(update);
    } on PaperlessApiException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.couldNotUpdateDocument)),
      );
    }
  }
}

Future<DocumentPermissionsUpdate?> _showSetPermissionsDialog(
  BuildContext context, {
  int? initialOwner,
  Iterable<int> initialViewUsers = const [],
  Iterable<int> initialViewGroups = const [],
  Iterable<int> initialChangeUsers = const [],
  Iterable<int> initialChangeGroups = const [],
}) async {
  final users = context.read<UserRepository>().state.users;
  final groups = context.read<GroupRepository>().state.groups;

  return showDialog<DocumentPermissionsUpdate>(
    context: context,
    builder: (context) {
      int? owner = initialOwner;
      List<int> viewUsers = initialViewUsers.toList();
      List<int> viewGroups = initialViewGroups.toList();
      List<int> changeUsers = initialChangeUsers.toList();
      List<int> changeGroups = initialChangeGroups.toList();
      bool merge = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(S.of(context)!.setPermissionsTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OwnerSelectField(
                    label: S.of(context)!.ownerIdOptional,
                    selectedId: owner,
                    availableUsers: users,
                    onChanged: (value) => setState(() => owner = value),
                  ),
                  const SizedBox(height: 16),
                  UserMultiSelectField(
                    label: S.of(context)!.permissionViewUsers,
                    selectedIds: viewUsers,
                    availableUsers: users,
                    onChanged: (value) => setState(() => viewUsers = value),
                  ),
                  const SizedBox(height: 12),
                  GroupMultiSelectField(
                    label: S.of(context)!.permissionViewGroups,
                    selectedIds: viewGroups,
                    availableGroups: groups,
                    onChanged: (value) => setState(() => viewGroups = value),
                  ),
                  const SizedBox(height: 12),
                  UserMultiSelectField(
                    label: S.of(context)!.permissionChangeUsers,
                    selectedIds: changeUsers,
                    availableUsers: users,
                    onChanged: (value) => setState(() => changeUsers = value),
                  ),
                  const SizedBox(height: 12),
                  GroupMultiSelectField(
                    label: S.of(context)!.permissionChangeGroups,
                    selectedIds: changeGroups,
                    availableGroups: groups,
                    onChanged: (value) => setState(() => changeGroups = value),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.of(context)!.setPermissionsMergeExisting),
                    value: merge,
                    onChanged: (value) => setState(() => merge = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context)!.cancel),
              ),
              DialogConfirmButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    DocumentPermissionsUpdate(
                      permissions: {
                        'view': {
                          'users': viewUsers,
                          'groups': viewGroups,
                        },
                        'change': {
                          'users': changeUsers,
                          'groups': changeGroups,
                        },
                      },
                      merge: merge,
                      owner: owner,
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );
}
