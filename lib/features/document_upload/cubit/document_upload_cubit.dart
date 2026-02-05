import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/bloc/transient_error.dart';
import 'package:paperless_mobile/core/service/document_upload_service.dart';
import 'package:paperless_mobile/features/document_upload/model/document_upload_result.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';

part 'document_upload_state.dart';

class DocumentUploadCubit extends Cubit<DocumentUploadState> {
  final DocumentUploadService _uploadService;
  CancelToken? _cancelToken;

  DocumentUploadCubit(
    PaperlessDocumentsApi documentApi,
    PendingTasksNotifier tasksNotifier,
  ) : _uploadService = DocumentUploadService(documentApi, tasksNotifier),
      super(const DocumentUploadState());

  void cancelUpload() {
    final token = _cancelToken;
    if (token == null || token.isCancelled) {
      return;
    }
    token.cancel('Upload cancelled by user.');
  }

  @override
  Future<void> close() {
    cancelUpload();
    return super.close();
  }

  Future<DocumentUploadResult> upload(
    Uint8List bytes, {
    required String filename,
    required String title,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    DateTime? createdAt,
    int? asn,
    Duration? timeout,
  }) async {
    _cancelToken = CancelToken();
    if (!isClosed) {
      emit(state.copyWith(uploadProgress: 0.0));
    }
    try {
      final taskId = await _uploadService.upload(
        bytes,
        filename: filename,
        title: title,
        correspondent: correspondent,
        documentType: documentType,
        storagePath: storagePath,
        tags: tags,
        createdAt: createdAt,
        asn: asn,
        timeout: timeout,
        cancelToken: _cancelToken,
        onProgressChanged: (progress) {
          if (!isClosed) {
            emit(state.copyWith(uploadProgress: progress));
          }
        },
      );
      return DocumentUploadResult.success(taskId);
    } on PaperlessApiException catch (error) {
      addError(
        TransientPaperlessApiError(code: error.code, details: error.details),
      );
      if (error.code == ErrorCode.requestCancelled) {
        return const DocumentUploadResult.cancelled();
      }
      return DocumentUploadResult.failure(error);
    } on Exception catch (error, stackTrace) {
      final wrapped = PaperlessApiException.unknown(
        details: error.toString(),
        stackTrace: stackTrace,
      );
      addError(
        TransientPaperlessApiError(
          code: wrapped.code,
          details: wrapped.details,
        ),
      );
      return DocumentUploadResult.failure(wrapped);
    } finally {
      _cancelToken = null;
      if (!isClosed) {
        emit(state.copyWith(uploadProgress: null));
      }
    }
  }
}
