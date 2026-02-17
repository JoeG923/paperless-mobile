import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';
import 'package:paperless_mobile/features/settings/model/view_type.dart';

class _FakeDocumentsApi extends Fake implements PaperlessDocumentsApi {
  int findAllCalls = 0;
  final PagedSearchResult<DocumentModel> response;

  _FakeDocumentsApi({required this.response});

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(
    DocumentFilter filter,
  ) async {
    findAllCalls += 1;
    return response;
  }
}

class _InMemoryLocalUserAppState extends LocalUserAppState {
  _InMemoryLocalUserAppState({
    required super.userId,
    super.currentDocumentFilter = const DocumentFilter(),
    super.documentsPageViewType = ViewType.list,
  });

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
  test('DocumentsCubit starts from persisted user preferences', () async {
    final api = _FakeDocumentsApi(
      response: const PagedSearchResult<DocumentModel>(count: 0, results: []),
    );
    final notifier = DocumentChangedNotifier();
    final userState = _InMemoryLocalUserAppState(
      userId: 'user-1',
      currentDocumentFilter: const DocumentFilter(
        query: TextQuery.title("invoice"),
        page: 3,
      ),
      documentsPageViewType: ViewType.grid,
    );
    final cubit = DocumentsCubit(
      api,
      notifier,
      userState,
      ConnectivityStatusServiceMock(true),
    );

    expect(
      cubit.state.filter,
      userState.currentDocumentFilter,
      reason: 'state is initialized from user state',
    );
    expect(
      cubit.state.viewType,
      ViewType.grid,
      reason: 'view type is initialized from user state',
    );

    await cubit.close();
    notifier.close();
  });

  test('toggleDocumentSelection toggles membership by id', () async {
    final api = _FakeDocumentsApi(
      response: const PagedSearchResult<DocumentModel>(count: 0, results: []),
    );
    final notifier = DocumentChangedNotifier();
    final userState = _InMemoryLocalUserAppState(userId: 'user-2');
    final cubit = DocumentsCubit(
      api,
      notifier,
      userState,
      ConnectivityStatusServiceMock(true),
    );
    final doc1 = _document(1);
    final doc2 = _document(2);

    expect(cubit.state.selectedIds, isEmpty);

    cubit.toggleDocumentSelection(doc1);
    cubit.toggleDocumentSelection(doc2);
    expect(cubit.state.selectedIds, [1, 2]);

    cubit.toggleDocumentSelection(doc1);
    expect(cubit.state.selectedIds, [2]);

    await cubit.close();
    notifier.close();
  });

  test('setViewType persists selection in local user state', () async {
    final api = _FakeDocumentsApi(
      response: const PagedSearchResult<DocumentModel>(count: 0, results: []),
    );
    final notifier = DocumentChangedNotifier();
    final userState = _InMemoryLocalUserAppState(
      userId: 'user-3',
      documentsPageViewType: ViewType.list,
    );
    final cubit = DocumentsCubit(
      api,
      notifier,
      userState,
      ConnectivityStatusServiceMock(true),
    );

    cubit.setViewType(ViewType.detailed);

    expect(cubit.state.viewType, ViewType.detailed);
    expect(userState.documentsPageViewType, ViewType.detailed);

    await cubit.close();
    notifier.close();
  });

  test('reset clears view state and selections', () async {
    final api = _FakeDocumentsApi(
      response: const PagedSearchResult<DocumentModel>(count: 0, results: []),
    );
    final notifier = DocumentChangedNotifier();
    final userState = _InMemoryLocalUserAppState(userId: 'user-4');
    final cubit = DocumentsCubit(
      api,
      notifier,
      userState,
      ConnectivityStatusServiceMock(true),
    );

    cubit.toggleDocumentSelection(_document(10));
    cubit.setViewType(ViewType.grid);
    await cubit.updateFilter(
      filter: const DocumentFilter(query: TextQuery.title("q")),
    );

    expect(cubit.state.selectedIds, [10]);
    expect(cubit.state.viewType, ViewType.grid);

    cubit.reset();

    expect(cubit.state.viewType, ViewType.list);
    expect(cubit.state.selection, isEmpty);
    expect(cubit.state.filter, const DocumentFilter());

    await cubit.close();
    notifier.close();
  });
}
