import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/document_paging_bloc_mixin.dart';

class _FakeDocumentsApi extends Fake implements PaperlessDocumentsApi {}

class _SequencedDocumentsApi extends _FakeDocumentsApi {
  final List<Completer<PagedSearchResult<DocumentModel>>> _responses;
  int _nextResponseIndex = 0;
  int findAllCalls = 0;

  _SequencedDocumentsApi(this._responses);

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(
    DocumentFilter filter,
  ) async {
    findAllCalls += 1;
    final response = _responses[_nextResponseIndex];
    _nextResponseIndex += 1;
    return response.future;
  }
}

class _PagingTestCubit extends Cubit<DocumentsState>
    with DocumentPagingBlocMixin<DocumentsState> {
  @override
  final PaperlessDocumentsApi api;

  @override
  final ConnectivityStatusService connectivityStatusService;

  @override
  final DocumentChangedNotifier notifier;
  final List<DocumentFilter> updatedFilters = [];

  _PagingTestCubit({
    required this.api,
    required this.connectivityStatusService,
    required this.notifier,
    required DocumentsState initialState,
  }) : super(initialState);

  @override
  Future<void> onFilterUpdated(DocumentFilter filter) async {
    updatedFilters.add(filter);
  }
}

DocumentModel _document(int id) {
  final timestamp = DateTime(2026, 1, id);
  return DocumentModel(
    id: id,
    title: 'doc-$id',
    documentType: null,
    correspondent: null,
    created: timestamp,
    modified: timestamp,
    added: timestamp,
  );
}

void main() {
  test('remove does not mutate existing page result lists in place', () async {
    final doc1 = _document(1);
    final doc2 = _document(2);
    final originalResults = [doc1, doc2];
    final page = PagedSearchResult<DocumentModel>(
      count: 2,
      results: originalResults,
    );
    final notifier = DocumentChangedNotifier();
    final cubit = _PagingTestCubit(
      api: _FakeDocumentsApi(),
      connectivityStatusService: ConnectivityStatusServiceMock(true),
      notifier: notifier,
      initialState: DocumentsState(hasLoaded: true, value: [page]),
    );

    cubit.remove(doc1);

    expect(originalResults.map((doc) => doc.id).toList(), equals([1, 2]));
    expect(cubit.state.documents.map((doc) => doc.id).toList(), equals([2]));

    await cubit.close();
    notifier.close();
  });

  test(
    'updateFilter persists filter updates through onFilterUpdated',
    () async {
      final notifier = DocumentChangedNotifier();
      final api = _FakeDocumentsApi();
      final cubit = _PagingTestCubit(
        api: api,
        connectivityStatusService: ConnectivityStatusServiceMock(false),
        notifier: notifier,
        initialState: const DocumentsState(),
      );
      final filter = const DocumentFilter(
        query: TextQuery.title('invoice'),
        page: 1,
      );

      await cubit.updateFilter(filter: filter, emitLoading: false);

      expect(cubit.updatedFilters, [filter]);

      await cubit.close();
      notifier.close();
    },
  );

  test(
    'updateFilter ignores stale responses from earlier overlapping calls',
    () async {
      final firstResponse = Completer<PagedSearchResult<DocumentModel>>();
      final secondResponse = Completer<PagedSearchResult<DocumentModel>>();
      final api = _SequencedDocumentsApi([firstResponse, secondResponse]);
      final notifier = DocumentChangedNotifier();
      final cubit = _PagingTestCubit(
        api: api,
        connectivityStatusService: ConnectivityStatusServiceMock(true),
        notifier: notifier,
        initialState: const DocumentsState(),
      );

      final firstFilter = const DocumentFilter(
        query: TextQuery.title('first'),
        page: 1,
      );
      final secondFilter = const DocumentFilter(
        query: TextQuery.title('second'),
        page: 1,
      );
      final firstCall = cubit.updateFilter(
        filter: firstFilter,
        emitLoading: false,
      );
      final secondCall = cubit.updateFilter(
        filter: secondFilter,
        emitLoading: false,
      );

      secondResponse.complete(
        PagedSearchResult(count: 1, results: [_document(2)]),
      );
      firstResponse.complete(
        PagedSearchResult(count: 1, results: [_document(1)]),
      );

      await Future.wait([firstCall, secondCall]);

      expect(api.findAllCalls, 2);
      expect(cubit.updatedFilters, [secondFilter]);
      expect(cubit.state.filter, secondFilter);
      expect(cubit.state.documents.map((doc) => doc.id).toList(), [2]);

      await cubit.close();
      notifier.close();
    },
  );
}
