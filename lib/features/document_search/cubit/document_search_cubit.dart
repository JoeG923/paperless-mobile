import 'package:collection/collection.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/document_paging_bloc_mixin.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/paged_documents_state.dart';
import 'package:paperless_mobile/features/settings/model/view_type.dart';

part 'document_search_cubit.g.dart';
part 'document_search_state.dart';

class DocumentSearchCubit extends Cubit<DocumentSearchState>
    with DocumentPagingBlocMixin {
  @override
  final PaperlessDocumentsApi api;
  @override
  final ConnectivityStatusService connectivityStatusService;

  @override
  final DocumentChangedNotifier notifier;

  final LocalUserAppState _userAppState;
  int _suggestionRequestId = 0;
  static const int _minSuggestionLength = 2;
  DocumentSearchCubit(
    this.api,
    this.notifier,
    this._userAppState,
    this.connectivityStatusService,
  ) : super(
          DocumentSearchState(
              searchHistory: _userAppState.documentSearchHistory),
        ) {
    notifier.addListener(
      this,
      onDeleted: remove,
      onUpdated: replace,
    );
  }

  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    emit(
      state.copyWith(
        isLoading: true,
        suggestions: [],
        view: SearchView.results,
      ),
    );
    final searchFilter = DocumentFilter(
      query: TextQuery.extended(normalizedQuery),
    );

    await updateFilter(filter: searchFilter);
    emit(
      state.copyWith(
        searchHistory: [
          normalizedQuery,
          ...state.searchHistory
              .whereNot((previousQuery) => previousQuery == normalizedQuery)
        ],
      ),
    );
    _userAppState
      ..documentSearchHistory = state.searchHistory
      ..save();
  }

  void updateViewType(ViewType viewType) {
    emit(state.copyWith(viewType: viewType));
  }

  void removeHistoryEntry(String entry) {
    emit(
      state.copyWith(
        searchHistory: state.searchHistory
            .whereNot((element) => element == entry)
            .toList(),
      ),
    );
    _userAppState
      ..documentSearchHistory = state.searchHistory
      ..save();
  }

  Future<void> suggest(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      emit(
        state.copyWith(
          suggestions: [],
          isLoading: false,
          view: SearchView.suggestions,
          hasLoaded: false,
        ),
      );
      return;
    }
    if (normalizedQuery.length < _minSuggestionLength) {
      emit(
        state.copyWith(
          suggestions: [],
          isLoading: false,
          view: SearchView.suggestions,
          hasLoaded: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        isLoading: true,
        view: SearchView.suggestions,
      ),
    );
    final requestId = ++_suggestionRequestId;
    try {
      final hasConnection =
          await connectivityStatusService.isConnectedToInternet();
      if (!hasConnection || requestId != _suggestionRequestId) {
        if (requestId == _suggestionRequestId) {
          emit(
            state.copyWith(
              suggestions: [],
              isLoading: false,
              hasLoaded: true,
            ),
          );
        }
        return;
      }
      final suggestions = await api.autocomplete(normalizedQuery);
      if (requestId != _suggestionRequestId) return;
      emit(
        state.copyWith(
          suggestions: suggestions,
          isLoading: false,
          hasLoaded: true,
        ),
      );
    } catch (_) {
      if (requestId != _suggestionRequestId) return;
      emit(
        state.copyWith(
          suggestions: [],
          isLoading: false,
          hasLoaded: true,
        ),
      );
    }
  }

  void reset() {
    emit(
      state.copyWith(
        view: SearchView.suggestions,
        suggestions: [],
        isLoading: false,
      ),
    );
  }

  @override
  Future<void> close() {
    notifier.removeListener(this);
    return super.close();
  }

  @override
  Future<void> onFilterUpdated(DocumentFilter filter) async {}
}
