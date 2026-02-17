import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';

class DocumentUploadService {
  static const Duration defaultUploadTimeout = Duration(minutes: 5);
  static const int defaultMaxRetryAttempts = 2;
  static const Duration defaultInitialRetryDelay = Duration(seconds: 1);

  final PaperlessDocumentsApi _documentApi;
  final PendingTasksNotifier _tasksNotifier;
  final int _maxRetryAttempts;
  final Duration _initialRetryDelay;
  final Future<void> Function(Duration) _sleep;

  DocumentUploadService(
    this._documentApi,
    this._tasksNotifier, {
    int maxRetryAttempts = defaultMaxRetryAttempts,
    Duration initialRetryDelay = defaultInitialRetryDelay,
    Future<void> Function(Duration)? sleep,
  }) : _maxRetryAttempts = maxRetryAttempts,
       _initialRetryDelay = initialRetryDelay,
       _sleep = sleep ?? Future.delayed;

  Future<String?> upload(
    Uint8List bytes, {
    required String filename,
    required String title,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
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
    return _uploadWithTimeout(
      (token, effectiveTimeout) => _documentApi.create(
        bytes,
        filename: filename,
        title: title,
        correspondent: correspondent,
        documentType: documentType,
        storagePath: storagePath,
        tags: tags,
        customFields: customFields,
        createdAt: createdAt,
        asn: asn,
        onProgressChanged: onProgressChanged,
        cancelToken: token,
        timeout: effectiveTimeout,
      ),
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }

  Future<String?> uploadFile(
    String filePath, {
    required String filename,
    required String title,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    DateTime? createdAt,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) {
    return _uploadWithTimeout(
      (token, effectiveTimeout) => _documentApi.createFromFile(
        filePath,
        filename: filename,
        title: title,
        correspondent: correspondent,
        documentType: documentType,
        storagePath: storagePath,
        tags: tags,
        customFields: customFields,
        createdAt: createdAt,
        asn: asn,
        onProgressChanged: onProgressChanged,
        cancelToken: token,
        timeout: effectiveTimeout,
      ),
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }

  Future<String?> _uploadWithTimeout(
    Future<String?> Function(CancelToken token, Duration effectiveTimeout)
    uploadRequest, {
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    final effectiveTimeout = timeout ?? defaultUploadTimeout;
    for (var attempt = 0; ; attempt++) {
      try {
        final uploadFuture = uploadRequest(token, effectiveTimeout);
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
      } on PaperlessApiException catch (error) {
        final canRetry =
            !token.isCancelled &&
            attempt < _maxRetryAttempts &&
            _isTransientUploadError(error.code);
        if (!canRetry) {
          rethrow;
        }
        await _sleep(_retryDelay(attempt));
      }
    }
  }

  bool _isTransientUploadError(ErrorCode errorCode) {
    return switch (errorCode) {
      ErrorCode.requestTimedOut ||
      ErrorCode.serverUnreachable ||
      ErrorCode.deviceOffline => true,
      _ => false,
    };
  }

  Duration _retryDelay(int attempt) {
    final multiplier = 1 << attempt;
    return _initialRetryDelay * multiplier;
  }
}
