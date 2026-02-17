import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/tasks/model/pending_upload_task_store.dart';

class PendingTasksNotifier extends ValueNotifier<Map<String, Task>> {
  static const int _maxConsecutiveMissesBeforeEviction = 2;

  final PaperlessTasksApi _api;
  final String? _userId;
  final PendingUploadTaskStore _taskStore;
  final Duration minPollInterval;
  final Duration maxPollInterval;
  final Future<void> Function(Duration) _sleep;
  final Set<String> _trackedTaskIds = {};
  final Map<String, int> _numericTaskIds = {};
  final Map<String, int> _consecutiveMissesByTaskId = {};
  Duration _currentDelay;
  bool _isPolling = false;
  bool _isDisposed = false;

  PendingTasksNotifier(
    this._api, {
    String? userId,
    PendingUploadTaskStore? taskStore,
    this.minPollInterval = const Duration(seconds: 1),
    this.maxPollInterval = const Duration(seconds: 5),
    Future<void> Function(Duration)? sleep,
  }) : _userId = userId,
       _taskStore = taskStore ?? noopPendingUploadTaskStore,
       _sleep = sleep ?? Future.delayed,
       _currentDelay = minPollInterval,
       super({}) {
    _restoreTrackedTaskIds();
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopListeningToTaskChanges();
    super.dispose();
  }

  void listenToTaskChanges(String taskId) {
    final isNewTask = _trackedTaskIds.add(taskId);
    if (!isNewTask) {
      return;
    }
    _currentDelay = minPollInterval;
    _persistTrackedTaskIds();
    _ensurePolling();
  }

  void stopListeningToTaskChanges([String? taskId]) {
    if (taskId != null) {
      _removeTaskId(taskId);
      return;
    }

    _trackedTaskIds.clear();
    _numericTaskIds.clear();
    _consecutiveMissesByTaskId.clear();
    _persistTrackedTaskIds();
    if (value.isNotEmpty) {
      value = {};
    }
  }

  Future<void> acknowledgeTasks(Iterable<String> taskIds) async {
    final tasks = value.values.where((task) => taskIds.contains(task.taskId));
    await Future.wait([for (var task in tasks) _api.acknowledgeTask(task)]);
    final next = {...value}..removeWhere((key, _) => taskIds.contains(key));
    value = next;
    _trackedTaskIds.removeWhere(taskIds.contains);
    _numericTaskIds.removeWhere((key, _) => taskIds.contains(key));
    _consecutiveMissesByTaskId.removeWhere((key, _) => taskIds.contains(key));
    _persistTrackedTaskIds();
  }

  void _restoreTrackedTaskIds() {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    final restoredTaskIds = _taskStore.loadForUser(userId);
    if (restoredTaskIds.isEmpty) {
      return;
    }
    _trackedTaskIds.addAll(restoredTaskIds);
    _currentDelay = minPollInterval;
    _ensurePolling();
  }

  void _persistTrackedTaskIds() {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    _taskStore.saveForUser(userId, _trackedTaskIds);
  }

  void _removeTaskId(String taskId) {
    final shouldPersist = _trackedTaskIds.remove(taskId);
    if (!shouldPersist) {
      return;
    }
    _numericTaskIds.remove(taskId);
    _consecutiveMissesByTaskId.remove(taskId);
    if (value.containsKey(taskId)) {
      final next = {...value}..remove(taskId);
      value = next;
    }
    _persistTrackedTaskIds();
  }

  void _removeTaskIds(Iterable<String> taskIds) {
    var changed = false;
    for (final taskId in taskIds) {
      changed = _trackedTaskIds.remove(taskId) || changed;
      _numericTaskIds.remove(taskId);
      _consecutiveMissesByTaskId.remove(taskId);
      final next = {...value}..remove(taskId);
      if (next.length != value.length) {
        value = next;
      }
    }
    if (changed) {
      _persistTrackedTaskIds();
    }
  }

  void _ensurePolling() {
    if (_isPolling || _isDisposed) return;
    _isPolling = true;
    unawaited(_pollLoop());
  }

  Future<void> _pollLoop() async {
    try {
      while (!_isDisposed && _trackedTaskIds.isNotEmpty) {
        final didChange = await _pollTrackedTasks();
        if (_trackedTaskIds.isEmpty || _isDisposed) {
          break;
        }

        _currentDelay = didChange ? minPollInterval : _nextDelay(_currentDelay);
        await _sleep(_currentDelay);
      }
    } finally {
      _isPolling = false;
      if (!_isDisposed && _trackedTaskIds.isNotEmpty) {
        _ensurePolling();
      }
    }
  }

  Duration _nextDelay(Duration current) {
    final nextMillis = math.min(
      current.inMilliseconds * 2,
      maxPollInterval.inMilliseconds,
    );
    return Duration(milliseconds: nextMillis);
  }

  Future<bool> _pollTrackedTasks() async {
    var changed = false;
    final trackedSnapshot = _trackedTaskIds.toList(growable: false);
    final unresolvedTaskIds = trackedSnapshot
        .where((taskId) => !_numericTaskIds.containsKey(taskId))
        .toList(growable: false);

    if (unresolvedTaskIds.isNotEmpty) {
      final discoveredTasks = await Future.wait(
        unresolvedTaskIds.map(_safeFindByTaskId),
      );
      for (final task in discoveredTasks.whereType<Task>()) {
        final taskId = task.taskId;
        if (taskId == null || !_trackedTaskIds.contains(taskId)) {
          continue;
        }
        _numericTaskIds[taskId] = task.id;
        changed = _upsertTask(taskId, task) || changed;
      }
    }

    final numericIds = _numericTaskIds.entries
        .where((entry) => _trackedTaskIds.contains(entry.key))
        .map((entry) => entry.value)
        .toList(growable: false);

    if (numericIds.isNotEmpty) {
      final refreshedTasks = await _safeFindAll(numericIds);
      if (refreshedTasks == null) {
        return changed;
      }

      final seenTaskIds = <String>{};
      for (final task in refreshedTasks) {
        final taskId = task.taskId;
        if (taskId == null || !_trackedTaskIds.contains(taskId)) {
          continue;
        }
        seenTaskIds.add(taskId);
        _consecutiveMissesByTaskId.remove(taskId);
        changed = _upsertTask(taskId, task) || changed;
      }

      final missingTaskIds = _trackedTaskIds
          .where(
            (taskId) =>
                _numericTaskIds.containsKey(taskId) &&
                !seenTaskIds.contains(taskId),
          )
          .toList(growable: false);
      final evictedTaskIds = <String>[];
      for (final taskId in missingTaskIds) {
        final misses = (_consecutiveMissesByTaskId[taskId] ?? 0) + 1;
        if (misses < _maxConsecutiveMissesBeforeEviction) {
          _consecutiveMissesByTaskId[taskId] = misses;
          continue;
        }

        _consecutiveMissesByTaskId.remove(taskId);
        evictedTaskIds.add(taskId);
      }

      if (evictedTaskIds.isNotEmpty) {
        _removeTaskIds(evictedTaskIds);
        changed = true;
      }
    }

    final completedTaskIds = <String>[];
    for (final taskId in trackedSnapshot) {
      final status = value[taskId]?.status;
      if (status == TaskStatus.success || status == TaskStatus.failure) {
        completedTaskIds.add(taskId);
      }
    }

    if (completedTaskIds.isNotEmpty) {
      _removeTaskIds(completedTaskIds);
      changed = true;
    }

    return changed;
  }

  Future<Task?> _safeFindByTaskId(String taskId) async {
    try {
      return await _api.find(taskId: taskId);
    } catch (_) {
      return null;
    }
  }

  Future<List<Task>?> _safeFindAll(List<int> ids) async {
    try {
      return (await _api.findAll(ids)).toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  bool _upsertTask(String taskId, Task task) {
    final current = value[taskId];
    if (current == task) {
      return false;
    }

    value = {...value, taskId: task};
    return true;
  }
}
