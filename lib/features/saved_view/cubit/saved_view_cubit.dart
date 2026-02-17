import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/saved_view_repository.dart';

part 'saved_view_cubit.freezed.dart';
part 'saved_view_state.dart';

class SavedViewCubit extends Cubit<SavedViewState> {
  final SavedViewRepository _savedViewRepository;

  SavedViewCubit(this._savedViewRepository)
    : super(const SavedViewState.initial()) {
    _savedViewRepository.addListener(_onSavedViewsChanged);
  }

  void _onSavedViewsChanged() {
    emit(SavedViewState.loaded(savedViews: _savedViewRepository.savedViews));
  }

  Future<SavedView> add(SavedView view) async {
    return _savedViewRepository.create(view);
  }

  Future<int> remove(SavedView view) {
    return _savedViewRepository.delete(view);
  }

  Future<SavedView> update(SavedView view) async {
    return await _savedViewRepository.update(view);
  }

  Future<void> reload() async {
    final views = await _savedViewRepository.findAll();
    final values = {for (var element in views) element.id!: element};
    if (!isClosed) {
      emit(SavedViewState.loaded(savedViews: values));
    }
  }

  @override
  Future<void> close() {
    _savedViewRepository.removeListener(_onSavedViewsChanged);
    return super.close();
  }
}
