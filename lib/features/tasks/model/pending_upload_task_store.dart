import 'dart:convert';

import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';

abstract class PendingUploadTaskStore {
  Set<String> loadForUser(String userId);
  void saveForUser(String userId, Set<String> taskIds);
}

class HivePendingUploadTaskStore implements PendingUploadTaskStore {
  final Box<String> _box;

  HivePendingUploadTaskStore([Box<String>? box])
    : _box = box ?? Hive.box<String>(HiveBoxes.pendingUploadTaskIds);

  @override
  Set<String> loadForUser(String userId) {
    final raw = _box.get(userId);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return {};
    }
    return {
      for (final value in decoded)
        if (value is String && value.isNotEmpty) value,
    };
  }

  @override
  void saveForUser(String userId, Set<String> taskIds) {
    final sanitizedTaskIds = {
      for (final taskId in taskIds)
        if (taskId.trim().isNotEmpty) taskId.trim(),
    };
    if (sanitizedTaskIds.isEmpty) {
      _box.delete(userId);
      return;
    }
    final payload = jsonEncode(sanitizedTaskIds.toList()..sort());
    _box.put(userId, payload);
  }
}

class NoopPendingUploadTaskStore implements PendingUploadTaskStore {
  const NoopPendingUploadTaskStore();

  @override
  Set<String> loadForUser(String userId) {
    return {};
  }

  @override
  void saveForUser(String userId, Set<String> taskIds) {}
}

const noopPendingUploadTaskStore = NoopPendingUploadTaskStore();
