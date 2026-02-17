import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/paged_documents_state.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/document_paging_bloc_mixin.dart';
import 'package:paperless_mobile/features/settings/model/view_type.dart';

part 'saved_view_details_state.dart';

class SavedViewDetailsCubit extends Cubit<SavedViewDetailsState>
    with DocumentPagingBlocMixin {
  @override
  final PaperlessDocumentsApi api;

  @override
  final ConnectivityStatusService connectivityStatusService;
  @override
  final DocumentChangedNotifier notifier;

  final SavedView savedView;

  final LocalUserAppState _userState;
  final DocumentListCacheStore _documentListCacheStore;

  SavedViewDetailsCubit(
    this.api,
    this.notifier,
    this._userState,
    this.connectivityStatusService, {
    required this.savedView,
    int initialCount = 25,
    DocumentListCacheStore? documentListCacheStore,
  }) : _documentListCacheStore =
           documentListCacheStore ?? HiveDocumentListCacheStore(),
       super(SavedViewDetailsState(viewType: _userState.savedViewsViewType)) {
    notifier.addListener(this, onDeleted: remove, onUpdated: replace);
    _initialize(initialCount);
  }

  void setViewType(ViewType viewType) {
    emit(state.copyWith(viewType: viewType));
    _userState
      ..savedViewsViewType = viewType
      ..save();
  }

  @override
  Future<void> onFilterUpdated(DocumentFilter filter) async {}

  @override
  Future<void> updateFilter({
    DocumentFilter filter = const DocumentFilter(),
    bool emitLoading = true,
  }) async {
    await super.updateFilter(filter: filter, emitLoading: emitLoading);
    await _persistFirstPage();
  }

  @override
  Future<void> reload() async {
    await super.reload();
    await _persistFirstPage();
  }

  Future<void> _initialize(int initialCount) async {
    final filter = savedView.toDocumentFilter().copyWith(
      page: 1,
      pageSize: initialCount,
    );
    await _restoreCachedPage(filter);
    await updateFilter(filter: filter, emitLoading: state.value.isEmpty);
  }

  Future<void> _restoreCachedPage(DocumentFilter filter) async {
    final cachedPage = await _documentListCacheStore.read(
      userId: _userState.userId,
      filter: filter,
    );
    if (cachedPage == null || isClosed) {
      return;
    }
    emit(state.copyWith(filter: filter, hasLoaded: true, value: [cachedPage]));
  }

  Future<void> _persistFirstPage() async {
    if (state.value.isEmpty) {
      return;
    }
    await _documentListCacheStore.write(
      userId: _userState.userId,
      filter: state.filter,
      page: state.value.first,
    );
  }
}
