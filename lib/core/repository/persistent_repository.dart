import 'dart:async';

import 'package:hydrated_bloc/hydrated_bloc.dart';

abstract class PersistentRepository<T> extends Cubit<T> {
  final Map<Object, StreamSubscription> _subscribers = {};

  PersistentRepository(super.initialState);

  void addListener(Object subscriber, {required void Function(T) onChanged}) {
    onChanged(state);
    _subscribers.putIfAbsent(subscriber, () {
      return stream.listen((event) => onChanged(event));
    });
  }

  void removeListener(Object source) async {
    _subscribers
      ..[source]?.cancel()
      ..remove(source);
  }

  @override
  Future<void> close() {
    for (final subscriber in _subscribers.values) {
      subscriber.cancel();
    }
    return super.close();
  }
}
