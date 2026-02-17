import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:paperless_api/paperless_api.dart';

class SavedViewRepository extends ChangeNotifier {
  final PaperlessSavedViewsApi _api;
  Map<int, SavedView> savedViews = {};

  SavedViewRepository(this._api);

  Future<void> initialize() async {
    await findAll();
  }

  Future<SavedView> create(SavedView object) async {
    final created = await _api.save(object);
    savedViews = {...savedViews, created.id!: created};
    notifyListeners();
    return created;
  }

  Future<SavedView> update(SavedView object) async {
    final updated = await _api.update(object);
    savedViews = {...savedViews, updated.id!: updated};
    notifyListeners();
    return updated;
  }

  Future<int> delete(SavedView view) async {
    await _api.delete(view);
    savedViews.remove(view.id!);
    notifyListeners();
    return view.id!;
  }

  Future<SavedView?> find(int id) async {
    final found = await _api.find(id);
    if (found != null) {
      savedViews = {...savedViews, id: found};
      notifyListeners();
    }
    return found;
  }

  Future<Iterable<SavedView>> findAll([Iterable<int>? ids]) async {
    final found = await _api.findAll(ids);
    savedViews = {for (final view in found) view.id!: view};
    notifyListeners();
    return found;
  }
}
