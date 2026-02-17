import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';

class _FakeDocumentsApi extends Fake implements PaperlessDocumentsApi {
  BulkAction? lastBulkAction;
  int findAllCalls = 0;

  @override
  Future<Iterable<int>> bulkAction(BulkAction action) async {
    lastBulkAction = action;
    return action.documentIds.toList(growable: false);
  }

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(
    DocumentFilter filter,
  ) async {
    findAllCalls += 1;
    return const PagedSearchResult<DocumentModel>(
      results: [],
      count: 0,
      next: null,
      previous: null,
    );
  }
}

class _InMemoryLocalUserAppState extends LocalUserAppState {
  _InMemoryLocalUserAppState({required super.userId});

  @override
  Future<void> save() async {}
}

DocumentModel _document(int id) {
  final now = DateTime(2026, 1, id);
  return DocumentModel(
    id: id,
    title: 'doc-$id',
    documentType: null,
    correspondent: null,
    created: now,
    modified: now,
    added: now,
  );
}

void main() {
  test('bulkRemovePassword sends remove_password action and reloads', () async {
    final api = _FakeDocumentsApi();
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentsCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'test-user'),
      ConnectivityStatusServiceMock(true),
    );

    await cubit.bulkRemovePassword([
      _document(1),
      _document(2),
    ], password: 'secret');

    expect(api.lastBulkAction, isA<BulkRemovePasswordAction>());
    expect(api.lastBulkAction?.toJson(), {
      'documents': [1, 2],
      'method': 'remove_password',
      'parameters': {'password': 'secret'},
    });
    expect(api.findAllCalls, 1);

    await cubit.close();
    notifier.close();
  });

  test('bulkEditPdf sends edit_pdf action and reloads', () async {
    final api = _FakeDocumentsApi();
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentsCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'test-user'),
      ConnectivityStatusServiceMock(true),
    );

    await cubit.bulkEditPdf(
      [_document(7)],
      operations: const [
        {'page': 1, 'rotate': 90, 'doc': 0},
      ],
      updateDocument: true,
      includeMetadata: false,
    );

    expect(api.lastBulkAction, isA<BulkEditPdfAction>());
    expect(api.lastBulkAction?.toJson(), {
      'documents': [7],
      'method': 'edit_pdf',
      'parameters': {
        'operations': [
          {'page': 1, 'rotate': 90, 'doc': 0},
        ],
        'update_document': true,
        'include_metadata': false,
      },
    });
    expect(api.findAllCalls, 1);

    await cubit.close();
    notifier.close();
  });

  test('bulkSetPermissions sends set_permissions action and reloads', () async {
    final api = _FakeDocumentsApi();
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentsCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'test-user'),
      ConnectivityStatusServiceMock(true),
    );

    await cubit.bulkSetPermissions(
      [_document(3)],
      permissions: const {
        'view': {
          'users': [1],
          'groups': [2],
        },
        'change': {
          'users': [3],
          'groups': [],
        },
      },
      merge: true,
      owner: 4,
    );

    expect(api.lastBulkAction, isA<BulkSetPermissionsAction>());
    expect(api.lastBulkAction?.toJson(), {
      'documents': [3],
      'method': 'set_permissions',
      'parameters': {
        'set_permissions': {
          'view': {
            'users': [1],
            'groups': [2],
          },
          'change': {
            'users': [3],
            'groups': [],
          },
        },
        'merge': true,
        'owner': 4,
      },
    });
    expect(api.findAllCalls, 1);

    await cubit.close();
    notifier.close();
  });

  test(
    'bulkModifyCustomFields sends modify_custom_fields action and reloads',
    () async {
      final api = _FakeDocumentsApi();
      final notifier = DocumentChangedNotifier();
      final cubit = DocumentsCubit(
        api,
        notifier,
        _InMemoryLocalUserAppState(userId: 'test-user'),
        ConnectivityStatusServiceMock(true),
      );

      await cubit.bulkModifyCustomFields(
        [_document(9)],
        addCustomFields: BulkCustomFieldPayload.values({11: 'paid'}),
        removeCustomFields: const [12],
      );

      expect(api.lastBulkAction, isA<BulkModifyCustomFieldsAction>());
      expect(api.lastBulkAction?.toJson(), {
        'documents': [9],
        'method': 'modify_custom_fields',
        'parameters': {
          'add_custom_fields': {'11': 'paid'},
          'remove_custom_fields': [12],
        },
      });
      expect(api.findAllCalls, 1);

      await cubit.close();
      notifier.close();
    },
  );
}
