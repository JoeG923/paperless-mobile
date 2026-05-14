import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:paperless_api/src/converters/local_date_time_json_converter.dart';
import 'package:paperless_api/src/request_utils.dart';
import 'task_status.dart';

part 'task.g.dart';

@LocalDateTimeJsonConverter()
@JsonSerializable(fieldRename: FieldRename.snake)
class Task extends Equatable {
  final int id;
  final String? taskId;
  final String? taskFileName;
  final DateTime dateCreated;
  final DateTime? dateDone;
  final String? type;
  final TaskStatus? status;
  final String? result;
  final bool acknowledged;
  @JsonKey(fromJson: tryParseNullable)
  final int? relatedDocument;

  bool get isSuccess => status == TaskStatus.success;

  const Task({
    required this.id,
    this.taskId,
    this.taskFileName,
    required this.dateCreated,
    this.dateDone,
    this.type,
    this.status,
    this.acknowledged = false,
    this.relatedDocument,
    this.result,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return _$TaskFromJson(_normalizeTaskJson(json));
  }

  Map<String, dynamic> toJson() => _$TaskToJson(this);

  @override
  List<Object?> get props => [
    id,
    taskId,
    taskFileName,
    dateCreated,
    dateDone,
    type,
    status,
    result,
    acknowledged,
    relatedDocument,
  ];

  Task copyWith({
    int? id,
    String? taskId,
    String? taskFileName,
    DateTime? dateCreated,
    DateTime? dateDone,
    String? type,
    TaskStatus? status,
    String? result,
    bool? acknowledged,
    int? relatedDocument,
  }) {
    return Task(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      dateCreated: dateCreated ?? this.dateCreated,
      acknowledged: acknowledged ?? this.acknowledged,
      dateDone: dateDone ?? this.dateDone,
      relatedDocument: relatedDocument ?? this.relatedDocument,
      result: result ?? this.result,
      status: status ?? this.status,
      taskFileName: taskFileName ?? this.taskFileName,
      type: type ?? this.type,
    );
  }
}

Map<String, dynamic> _normalizeTaskJson(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);

  normalized['status'] = _normalizeTaskStatus(normalized['status']);
  normalized['type'] ??= normalized['task_type'];
  normalized['task_file_name'] ??= _inputFilename(normalized['input_data']);
  normalized['related_document'] ??= _relatedDocumentId(normalized);

  return normalized;
}

String? _normalizeTaskStatus(dynamic value) {
  if (value is String) {
    return value.toUpperCase();
  }
  return null;
}

String? _inputFilename(dynamic inputData) {
  if (inputData is Map) {
    final filename = inputData['filename'];
    if (filename is String) {
      return filename;
    }
  }
  return null;
}

String? _relatedDocumentId(Map<String, dynamic> json) {
  final resultData = json['result_data'];
  if (resultData is Map) {
    final documentId = resultData['document_id'];
    if (documentId != null) {
      return documentId.toString();
    }
  }

  final relatedDocumentIds = json['related_document_ids'];
  if (relatedDocumentIds is List && relatedDocumentIds.isNotEmpty) {
    return relatedDocumentIds.first.toString();
  }

  final relatedDocument = json['related_document'];
  return relatedDocument?.toString();
}
