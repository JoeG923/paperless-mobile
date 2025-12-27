import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/user_repository.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/details_item.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class DocumentPermissionsWidget extends StatefulWidget {
  final DocumentModel document;
  const DocumentPermissionsWidget({super.key, required this.document});

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
      builder: (context, state) {
        final permissions = widget.document.permissions;
        final owner = widget.document.owner == null
            ? S.of(context)!.documentOwnerUnassigned
            : _resolveUserLabel(widget.document.owner!, state.users);

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
            .map((id) => _resolveUserLabel(id, state.users))
            .toList();
        final viewGroups = permissions.view.groups.map(_groupLabel).toList();
        final changeUsers = permissions.change.users
            .map((id) => _resolveUserLabel(id, state.users))
            .toList();
        final changeGroups = permissions.change.groups.map(_groupLabel).toList();
        final hasAnyPermissions = viewUsers.isNotEmpty ||
            viewGroups.isNotEmpty ||
            changeUsers.isNotEmpty ||
            changeGroups.isNotEmpty;

        return SliverList.list(
          children: [
            DetailsItem.text(
              owner,
              label: S.of(context)!.documentOwner,
              context: context,
            ),
            if (!hasAnyPermissions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  S.of(context)!.permissionsNoneMessage,
                ),
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

  String _groupLabel(int groupId) => '#$groupId';

  Widget _buildChips(List<String> labels) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels) Chip(label: Text(label)),
      ],
    );
  }
}
