import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/tasks/model/pending_upload_task_store.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';

class _FakeTasksApi implements PaperlessTasksApi {
  final Map<String, Queue<Task>> _discoverByTaskId;
  final Map<int, Queue<Task>> _tasksByNumericId;
  final Map<int, Queue<bool>> _includeByNumericId;
  final List<List<int>> findAllRequestedIds = [];
  final List<String> acknowledgedTaskIds = [];
  int findCalls = 0;

  _FakeTasksApi({
    required Map<String, List<Task>> discoverByTaskId,
    required Map<int, List<Task>> tasksByNumericId,
    Map<int, List<bool>> includeByNumericId = const {},
  }) : _discoverByTaskId = {
         for (final entry in discoverByTaskId.entries)
           entry.key: Queue<Task>.from(entry.value),
       },
       _tasksByNumericId = {
         for (final entry in tasksByNumericId.entries)
           entry.key: Queue<Task>.from(entry.value),
       },
       _includeByNumericId = {
         for (final entry in includeByNumericId.entries)
           entry.key: Queue<bool>.from(entry.value),
       };

  @override
  Future<Task?> find({int? id, String? taskId}) async {
    if (taskId == null) return null;
    findCalls++;
    final queue = _discoverByTaskId[taskId];
    if (queue == null || queue.isEmpty) {
      return null;
    }
    if (queue.length > 1) {
      return queue.removeFirst();
    }
    return queue.first;
  }

  @override
  Future<Iterable<Task>> findAll([Iterable<int>? ids]) async {
    final requestedIds = ids?.toList(growable: false) ?? const <int>[];
    findAllRequestedIds.add(requestedIds);

    final result = <Task>[];
    for (final id in requestedIds) {
      final includeQueue = _includeByNumericId[id];
      if (includeQueue != null && includeQueue.isNotEmpty) {
        final includeCurrent = includeQueue.length > 1
            ? includeQueue.removeFirst()
            : includeQueue.first;
        if (!includeCurrent) {
          continue;
        }
      }

      final queue = _tasksByNumericId[id];
      if (queue == null || queue.isEmpty) {
        continue;
      }
      if (queue.length > 1) {
        result.add(queue.removeFirst());
      } else {
        result.add(queue.first);
      }
    }
    return result;
  }

  @override
  Stream<Task> listenForTaskChanges(String taskId) => const Stream.empty();

  @override
  Future<Task> acknowledgeTask(Task task) async {
    final taskId = task.taskId;
    if (taskId != null) {
      acknowledgedTaskIds.add(taskId);
    }
    return task.copyWith(acknowledged: true);
  }

  @override
  Future<Iterable<Task>> acknowledgeTasks(Iterable<Task> tasks) async {
    final acknowledged = <Task>[];
    for (final task in tasks) {
      acknowledged.add(await acknowledgeTask(task));
    }
    return acknowledged;
  }
}

class _FlakyFindAllTasksApi extends _FakeTasksApi {
  int _remainingFindAllFailures;

  _FlakyFindAllTasksApi({
    required super.discoverByTaskId,
    required super.tasksByNumericId,
    required int transientFindAllFailures,
  }) : _remainingFindAllFailures = transientFindAllFailures;

  @override
  Future<Iterable<Task>> findAll([Iterable<int>? ids]) async {
    final requestedIds = ids?.toList(growable: false) ?? const <int>[];
    findAllRequestedIds.add(requestedIds);

    if (_remainingFindAllFailures > 0) {
      _remainingFindAllFailures -= 1;
      throw Exception('transient task list failure');
    }
    return super.findAll(ids);
  }
}

class _InMemoryPendingUploadTaskStore implements PendingUploadTaskStore {
  final Map<String, Set<String>> valuesByUser = {};

  @override
  Set<String> loadForUser(String userId) {
    return Set.from(valuesByUser[userId] ?? {});
  }

  @override
  void saveForUser(String userId, Set<String> taskIds) {
    if (taskIds.isEmpty) {
      valuesByUser.remove(userId);
    } else {
      valuesByUser[userId] = Set.from(taskIds);
    }
  }
}

Task _task(int id, String taskId, {required TaskStatus status}) {
  return Task(
    id: id,
    taskId: taskId,
    dateCreated: DateTime(2026, 1, id),
    status: status,
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  int maxAttempts = 200,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition not met within $maxAttempts attempts');
}

void main() {
  group('PendingTasksNotifier', () {
    test('refreshes tracked tasks in a single batched findAll call', () async {
      final api = _FakeTasksApi(
        discoverByTaskId: {
          'task-1': [_task(1, 'task-1', status: TaskStatus.pending)],
          'task-2': [_task(2, 'task-2', status: TaskStatus.pending)],
        },
        tasksByNumericId: {
          1: [
            _task(1, 'task-1', status: TaskStatus.pending),
            _task(1, 'task-1', status: TaskStatus.started),
            _task(1, 'task-1', status: TaskStatus.success),
          ],
          2: [
            _task(2, 'task-2', status: TaskStatus.pending),
            _task(2, 'task-2', status: TaskStatus.success),
          ],
        },
      );
      final notifier = PendingTasksNotifier(
        api,
        minPollInterval: Duration.zero,
        maxPollInterval: Duration.zero,
        sleep: (_) async => Future<void>.delayed(Duration.zero),
      );

      notifier.listenToTaskChanges('task-1');
      notifier.listenToTaskChanges('task-2');

      await _waitUntil(
        () => api.findAllRequestedIds.any(
          (ids) => ids.toSet().containsAll({1, 2}),
        ),
      );

      await _waitUntil(() => notifier.value.isEmpty);
      notifier.dispose();
    });

    test('keeps tracked task after a single missing poll response', () async {
      final api = _FakeTasksApi(
        discoverByTaskId: {
          'task-1': [_task(1, 'task-1', status: TaskStatus.pending)],
        },
        tasksByNumericId: {
          1: [_task(1, 'task-1', status: TaskStatus.pending)],
        },
        includeByNumericId: {
          1: [true, false, true],
        },
      );
      final notifier = PendingTasksNotifier(
        api,
        minPollInterval: Duration.zero,
        maxPollInterval: Duration.zero,
        sleep: (_) async => Future<void>.delayed(Duration.zero),
      );

      notifier.listenToTaskChanges('task-1');

      await _waitUntil(() => api.findAllRequestedIds.length >= 2);
      expect(notifier.value.containsKey('task-1'), isTrue);

      await _waitUntil(() => api.findAllRequestedIds.length >= 3);
      expect(notifier.value.containsKey('task-1'), isTrue);

      notifier.stopListeningToTaskChanges('task-1');
      await _waitUntil(() => notifier.value.isEmpty);
      notifier.dispose();
    });

    test(
      'evicts tracked task after consecutive missing poll responses',
      () async {
        final api = _FakeTasksApi(
          discoverByTaskId: {
            'task-1': [_task(1, 'task-1', status: TaskStatus.pending)],
          },
          tasksByNumericId: {
            1: [_task(1, 'task-1', status: TaskStatus.pending)],
          },
          includeByNumericId: {
            1: [true, false, false],
          },
        );
        final notifier = PendingTasksNotifier(
          api,
          minPollInterval: Duration.zero,
          maxPollInterval: Duration.zero,
          sleep: (_) async => Future<void>.delayed(Duration.zero),
        );

        notifier.listenToTaskChanges('task-1');

        await _waitUntil(() => api.findAllRequestedIds.length >= 2);
        expect(notifier.value.containsKey('task-1'), isTrue);

        await _waitUntil(() => notifier.value.isEmpty);
        expect(notifier.value.containsKey('task-1'), isFalse);

        notifier.dispose();
      },
    );

    test(
      'keeps tracked task during transient batch-refresh failures',
      () async {
        final api = _FlakyFindAllTasksApi(
          discoverByTaskId: {
            'task-1': [_task(1, 'task-1', status: TaskStatus.pending)],
          },
          tasksByNumericId: {
            1: [_task(1, 'task-1', status: TaskStatus.success)],
          },
          transientFindAllFailures: 2,
        );
        final notifier = PendingTasksNotifier(
          api,
          minPollInterval: Duration.zero,
          maxPollInterval: Duration.zero,
          sleep: (_) async => Future<void>.delayed(Duration.zero),
        );

        notifier.listenToTaskChanges('task-1');

        await _waitUntil(() => api.findAllRequestedIds.length >= 2);
        expect(notifier.value.containsKey('task-1'), isTrue);

        await _waitUntil(() => notifier.value.isEmpty);
        expect(notifier.value, isEmpty);
        notifier.dispose();
      },
    );

    test(
      'does not duplicate tracking when listening twice to same task id',
      () async {
        final api = _FakeTasksApi(
          discoverByTaskId: {
            'task-1': [_task(1, 'task-1', status: TaskStatus.pending)],
          },
          tasksByNumericId: {
            1: [
              _task(1, 'task-1', status: TaskStatus.pending),
              _task(1, 'task-1', status: TaskStatus.success),
            ],
          },
        );
        final notifier = PendingTasksNotifier(
          api,
          minPollInterval: Duration.zero,
          maxPollInterval: Duration.zero,
          sleep: (_) async => Future<void>.delayed(Duration.zero),
        );

        notifier.listenToTaskChanges('task-1');
        notifier.listenToTaskChanges('task-1');

        await _waitUntil(() => notifier.value.isEmpty);
        expect(api.findCalls, equals(1));
        notifier.dispose();
      },
    );

    test(
      'acknowledgeTasks removes tasks without mutating prior value map',
      () async {
        final api = _FakeTasksApi(
          discoverByTaskId: const {},
          tasksByNumericId: const {},
        );
        final notifier = PendingTasksNotifier(api);
        notifier.value = {
          'task-1': _task(1, 'task-1', status: TaskStatus.pending),
        };

        final snapshot = notifier.value;
        await notifier.acknowledgeTasks(['task-1']);

        expect(api.acknowledgedTaskIds, contains('task-1'));
        expect(notifier.value, isEmpty);
        expect(snapshot.containsKey('task-1'), isTrue);
        notifier.dispose();
      },
    );

    test(
      'restores tracked tasks from the store and persists removals',
      () async {
        final store = _InMemoryPendingUploadTaskStore();
        store.saveForUser('user-1', {'task-restored'});
        final api = _FakeTasksApi(
          discoverByTaskId: {
            'task-restored': [
              _task(99, 'task-restored', status: TaskStatus.pending),
            ],
          },
          tasksByNumericId: {
            99: [_task(99, 'task-restored', status: TaskStatus.pending)],
          },
        );
        final notifier = PendingTasksNotifier(
          api,
          userId: 'user-1',
          taskStore: store,
          minPollInterval: Duration.zero,
          maxPollInterval: Duration.zero,
          sleep: (_) async => Future<void>.delayed(Duration.zero),
        );

        await _waitUntil(() => notifier.value.isNotEmpty);
        expect(notifier.value['task-restored'], isNotNull);
        expect(store.loadForUser('user-1'), equals({'task-restored'}));

        notifier.stopListeningToTaskChanges('task-restored');
        await _waitUntil(() => notifier.value.isEmpty);
        expect(store.loadForUser('user-1'), isEmpty);
        notifier.dispose();
      },
    );

    test('backs off polling delay when no task state changes occur', () async {
      final api = _FakeTasksApi(
        discoverByTaskId: {
          'task-1': [_task(1, 'task-1', status: TaskStatus.pending)],
        },
        tasksByNumericId: {
          1: [_task(1, 'task-1', status: TaskStatus.pending)],
        },
      );
      final sleeps = <Duration>[];
      late PendingTasksNotifier notifier;
      notifier = PendingTasksNotifier(
        api,
        minPollInterval: const Duration(milliseconds: 1),
        maxPollInterval: const Duration(milliseconds: 8),
        sleep: (delay) async {
          sleeps.add(delay);
          if (sleeps.length >= 3) {
            notifier.stopListeningToTaskChanges('task-1');
          }
          await Future<void>.delayed(Duration.zero);
        },
      );

      notifier.listenToTaskChanges('task-1');

      await _waitUntil(() => sleeps.length >= 3);
      expect(
        sleeps.take(3).toList(growable: false),
        equals(const [
          Duration(milliseconds: 1),
          Duration(milliseconds: 2),
          Duration(milliseconds: 4),
        ]),
      );
      notifier.dispose();
    });

    test('resets polling delay back to minimum after a task update', () async {
      final api = _FakeTasksApi(
        discoverByTaskId: {
          'task-1': [_task(1, 'task-1', status: TaskStatus.pending)],
        },
        tasksByNumericId: {
          1: [
            _task(1, 'task-1', status: TaskStatus.pending),
            _task(1, 'task-1', status: TaskStatus.pending),
            _task(1, 'task-1', status: TaskStatus.started),
            _task(1, 'task-1', status: TaskStatus.started),
          ],
        },
      );
      final sleeps = <Duration>[];
      late PendingTasksNotifier notifier;
      notifier = PendingTasksNotifier(
        api,
        minPollInterval: const Duration(milliseconds: 1),
        maxPollInterval: const Duration(milliseconds: 8),
        sleep: (delay) async {
          sleeps.add(delay);
          if (sleeps.length >= 3) {
            notifier.stopListeningToTaskChanges('task-1');
          }
          await Future<void>.delayed(Duration.zero);
        },
      );

      notifier.listenToTaskChanges('task-1');

      await _waitUntil(() => sleeps.length >= 3);
      expect(
        sleeps.take(3).toList(growable: false),
        equals(const [
          Duration(milliseconds: 1),
          Duration(milliseconds: 2),
          Duration(milliseconds: 1),
        ]),
      );
      notifier.dispose();
    });
  });
}
