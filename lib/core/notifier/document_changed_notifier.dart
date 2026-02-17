import 'dart:async';

import 'package:paperless_api/paperless_api.dart';
import 'package:rxdart/subjects.dart';

typedef DocumentChangedCallback = void Function(DocumentModel document);

class DocumentChangedNotifier {
  final Subject<DocumentModel> _updated = PublishSubject();
  final Subject<DocumentModel> _deleted = PublishSubject();

  final Map<dynamic, List<StreamSubscription>> _subscribers = {};

  Stream<DocumentModel> get $updated => _updated.asBroadcastStream();

  Stream<DocumentModel> get $deleted => _deleted.asBroadcastStream();

  void notifyUpdated(DocumentModel updated) {
    _updated.add(updated);
  }

  void notifyDeleted(DocumentModel deleted) {
    _deleted.add(deleted);
  }

  void addListener(
    Object subscriber, {
    DocumentChangedCallback? onUpdated,
    DocumentChangedCallback? onDeleted,
    Iterable<int>? ids,
  }) {
    _subscribers.putIfAbsent(
      subscriber,
      () => [
        _updated.where((doc) => ids?.contains(doc.id) ?? true).listen((value) {
          onUpdated?.call(value);
        }),
        _deleted.where((doc) => ids?.contains(doc.id) ?? true).listen((value) {
          onDeleted?.call(value);
        }),
      ],
    );
  }

  void removeListener(Object subscriber) {
    _subscribers.remove(subscriber)?.forEach((element) {
      element.cancel();
    });
  }

  void close() {
    _updated.close();
    _deleted.close();
  }
}
