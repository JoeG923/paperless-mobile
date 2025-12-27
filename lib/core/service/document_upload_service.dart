import 'dart:typed_data';

import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';

class DocumentUploadService {
  final PaperlessDocumentsApi _documentApi;
  final PendingTasksNotifier _tasksNotifier;

  DocumentUploadService(this._documentApi, this._tasksNotifier);

  Future<String?> upload(
    Uint8List bytes, {
    required String filename,
    required String title,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    DateTime? createdAt,
    int? asn,
    void Function(double progress)? onProgressChanged,
  }) async {
    final taskId = await _documentApi.create(
      bytes,
      filename: filename,
      title: title,
      correspondent: correspondent,
      documentType: documentType,
      storagePath: storagePath,
      tags: tags,
      createdAt: createdAt,
      asn: asn,
      onProgressChanged: onProgressChanged,
    );
    if (taskId != null) {
      _tasksNotifier.listenToTaskChanges(taskId);
    }
    return taskId;
  }
}
