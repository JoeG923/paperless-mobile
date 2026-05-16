import 'package:equatable/equatable.dart';

enum SystemStatusItemStatus {
  ok,
  error,
  warning,
  disabled,
  unknown;

  static SystemStatusItemStatus fromJson(Object? value) {
    return switch (value) {
      'OK' => SystemStatusItemStatus.ok,
      'ERROR' => SystemStatusItemStatus.error,
      'WARNING' => SystemStatusItemStatus.warning,
      'DISABLED' => SystemStatusItemStatus.disabled,
      _ => SystemStatusItemStatus.unknown,
    };
  }
}

class PaperlessSystemStatusModel extends Equatable {
  final SystemStatusItemStatus llmIndexStatus;
  final DateTime? llmIndexLastModified;
  final String? llmIndexError;

  const PaperlessSystemStatusModel({
    this.llmIndexStatus = SystemStatusItemStatus.unknown,
    this.llmIndexLastModified,
    this.llmIndexError,
  });

  factory PaperlessSystemStatusModel.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'];
    final taskData = tasks is Map<String, dynamic> ? tasks : const {};
    return PaperlessSystemStatusModel(
      llmIndexStatus: SystemStatusItemStatus.fromJson(
        taskData['llmindex_status'],
      ),
      llmIndexLastModified: _parseDate(taskData['llmindex_last_modified']),
      llmIndexError: taskData['llmindex_error'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    llmIndexStatus,
    llmIndexLastModified,
    llmIndexError,
  ];
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
