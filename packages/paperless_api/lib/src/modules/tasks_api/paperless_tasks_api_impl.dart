import 'dart:developer';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_api/src/extensions/dio_exception_extension.dart';

class PaperlessTasksApiImpl implements PaperlessTasksApi {
  static const int _maxIdsPerQuery = 100;

  final Dio _client;
  final int apiVersion;
  final Duration minPollInterval;
  final Duration maxPollInterval;
  final Future<void> Function(Duration) _sleep;

  PaperlessTasksApiImpl(
    this._client, {
    this.apiVersion = 2,
    this.minPollInterval = const Duration(seconds: 1),
    this.maxPollInterval = const Duration(seconds: 5),
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? Future.delayed;

  String get _acknowledgeEndpoint =>
      apiVersion >= 6 ? "/api/tasks/acknowledge/" : "/api/acknowledge_tasks/";

  @override
  Future<Task?> find({int? id, String? taskId}) async {
    assert((id != null) != (taskId != null));
    if (id != null) {
      return _findById(id);
    } else if (taskId != null) {
      return _findByTaskId(taskId);
    }
    return null;
  }

  /// API response returns List with single item
  Future<Task?> _findById(int id) async {
    final response = await _client.get("/api/tasks/$id/");
    if (response.statusCode == 200) {
      return Task.fromJson(response.data);
    }
    return null;
  }

  /// API response returns List with single item
  Future<Task?> _findByTaskId(String taskId) async {
    final response = await _client.get(
      "/api/tasks/",
      queryParameters: {'task_id': taskId},
      options: Options(validateStatus: (status) => status == 200),
    );
    if (response.statusCode == 200) {
      final tasks = _tasksFromResponse(response.data);
      if (tasks.isNotEmpty) {
        return tasks.first;
      }
    }
    return null;
  }

  @override
  Future<Iterable<Task>> findAll([Iterable<int>? ids]) async {
    try {
      final requestedIds = ids?.toList(growable: false);
      if (requestedIds == null || requestedIds.isEmpty) {
        final response = await _client.get(
          "/api/tasks/",
          options: Options(validateStatus: (status) => status == 200),
        );
        return _tasksFromResponse(response.data);
      }

      final tasks = <Task>[];
      for (var i = 0; i < requestedIds.length; i += _maxIdsPerQuery) {
        final chunk = requestedIds.skip(i).take(_maxIdsPerQuery).toList();
        final response = await _client.get(
          "/api/tasks/",
          queryParameters: {'id__in': chunk.join(',')},
          options: Options(validateStatus: (status) => status == 200),
        );
        tasks.addAll(_tasksFromResponse(response.data));
      }
      return tasks;
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.loadTasksError),
      );
    }
  }

  @override
  Stream<Task> listenForTaskChanges(String taskId) async* {
    Duration currentDelay = minPollInterval;
    TaskStatus? previousStatus;
    bool isCompleted = false;
    while (!isCompleted) {
      final task = await find(taskId: taskId);
      if (task == null) {
        throw Exception("Task with taskId $taskId does not exist.");
      }
      log("Found new task: ${task.taskId}, ${task.id}, ${task.status}");
      yield task;
      if (task.status == TaskStatus.success ||
          task.status == TaskStatus.failure) {
        isCompleted = true;
        continue;
      }

      if (task.status == previousStatus) {
        final nextMillis = math.min(
          currentDelay.inMilliseconds * 2,
          maxPollInterval.inMilliseconds,
        );
        currentDelay = Duration(milliseconds: nextMillis);
      } else {
        currentDelay = minPollInterval;
        previousStatus = task.status;
      }
      await _sleep(currentDelay);
    }
  }

  @override
  Future<Task> acknowledgeTask(Task task) async {
    final acknowledgedTasks = await acknowledgeTasks([task]);
    return acknowledgedTasks.first.copyWith(acknowledged: true);
  }

  @override
  Future<Iterable<Task>> acknowledgeTasks(Iterable<Task> tasks) async {
    try {
      final response = await _client.post(
        _acknowledgeEndpoint,
        data: {'tasks': tasks.map((e) => e.id).toList()},
        options: Options(validateStatus: (status) => status == 200),
      );
      if (response.data['result'] != tasks.length) {
        throw const PaperlessApiException(ErrorCode.acknowledgeTasksError);
      }
      return tasks.map((e) => e.copyWith(acknowledged: true)).toList();
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.acknowledgeTasksError),
      );
    }
  }

  List<Task> _tasksFromResponse(dynamic data) {
    final dynamic taskItems = switch (data) {
      {'results': final results} => results,
      _ => data,
    };
    return (taskItems as List)
        .cast<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList(growable: false);
  }
}
