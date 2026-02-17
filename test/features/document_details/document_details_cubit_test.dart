import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_api/src/models/permissions/users_and_groups_permissions.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/features/document_details/cubit/document_details_cubit.dart';
import 'package:paperless_mobile/features/notifications/services/local_notification_service.dart';

class _FakeDocumentsApi extends Fake implements PaperlessDocumentsApi {
  late DocumentModel initialDocument;
  late DocumentModel updatedDocument;
  BulkAction? lastBulkAction;
  bool _permissionsUpdated = false;

  @override
  Future<Iterable<int>> bulkAction(BulkAction action) async {
    lastBulkAction = action;
    _permissionsUpdated = true;
    return action.documentIds.toList(growable: false);
  }

  @override
  Future<DocumentModel> find(int id, {bool fullPermissions = false}) async {
    return _permissionsUpdated ? updatedDocument : initialDocument;
  }

  @override
  Future<DocumentMetaData> getMetaData(int id) async {
    return DocumentMetaData(
      originalChecksum: 'abc',
      originalSize: 1,
      originalMimeType: 'application/pdf',
      mediaFilename: 'test.pdf',
      hasArchiveVersion: true,
      archiveChecksum: 'def',
      archiveSize: 1,
    );
  }
}

DocumentModel _buildDocument({
  required int id,
  int? owner,
  Permissions? permissions,
}) {
  final now = DateTime(2026, 1, 1);
  return DocumentModel(
    id: id,
    title: 'doc-$id',
    documentType: null,
    correspondent: null,
    storagePath: null,
    created: now,
    modified: now,
    added: now,
    owner: owner,
    permissions: permissions,
  );
}

void main() {
  test(
    'updatePermissions applies set_permissions and refreshes document',
    () async {
      final api = _FakeDocumentsApi()
        ..initialDocument = _buildDocument(
          id: 1,
          owner: 1,
          permissions: const Permissions(
            view: UsersAndGroupsPermissions(users: [1]),
            change: UsersAndGroupsPermissions(),
          ),
        )
        ..updatedDocument = _buildDocument(
          id: 1,
          owner: 4,
          permissions: const Permissions(
            view: UsersAndGroupsPermissions(users: [1, 2]),
            change: UsersAndGroupsPermissions(groups: [3]),
          ),
        );
      final notifier = DocumentChangedNotifier();
      final cubit = DocumentDetailsCubit(
        api,
        notifier,
        LocalNotificationService(),
        id: 1,
      );

      await cubit.initialize();
      await cubit.updatePermissions(
        permissions: const {
          'view': {
            'users': [1, 2],
            'groups': <int>[],
          },
          'change': {
            'users': <int>[],
            'groups': [3],
          },
        },
        merge: true,
        owner: 4,
      );
      await Future<void>.delayed(Duration.zero);

      expect(api.lastBulkAction, isA<BulkSetPermissionsAction>());
      expect(api.lastBulkAction?.toJson(), {
        'documents': [1],
        'method': 'set_permissions',
        'parameters': {
          'set_permissions': {
            'view': {
              'users': [1, 2],
              'groups': <int>[],
            },
            'change': {
              'users': <int>[],
              'groups': [3],
            },
          },
          'merge': true,
          'owner': 4,
        },
      });
      expect(cubit.state.document, api.updatedDocument);

      await cubit.close();
      notifier.close();
    },
  );
}
