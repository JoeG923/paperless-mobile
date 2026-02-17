part of 'saved_view_cubit.dart';

@freezed
class SavedViewState with _$SavedViewState {
  const factory SavedViewState.initial() = _Initial;

  const factory SavedViewState.loading() = _Loading;

  const factory SavedViewState.loaded({
    required Map<int, SavedView> savedViews,
  }) = _Loaded;

  const factory SavedViewState.error() = _Error;
}
