import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';

class DocumentUploadService {
  static const Duration defaultUploadTimeout = Duration(minutes: 5);

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
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    if (bytes.isEmpty) {
      throw const PaperlessApiException(
        ErrorCode.documentUploadFailed,
        details: 'File is empty.',
      );
    }
    final token = cancelToken ?? CancelToken();
    final effectiveTimeout = timeout ?? defaultUploadTimeout;
    final uploadFuture = _documentApi.create(
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
      cancelToken: token,
      timeout: effectiveTimeout,
    );
    final taskId = await uploadFuture.timeout(
      effectiveTimeout,
      onTimeout: () {
        token.cancel('Upload timed out.');
        throw const PaperlessApiException(ErrorCode.requestTimedOut);
      },
    );
    if (taskId != null) {
      _tasksNotifier.listenToTaskChanges(taskId);
    }
    return taskId;
  }
}
