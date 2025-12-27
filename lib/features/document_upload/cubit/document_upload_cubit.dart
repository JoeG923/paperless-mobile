import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/bloc/transient_error.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/service/document_upload_service.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';

part 'document_upload_state.dart';

class DocumentUploadCubit extends Cubit<DocumentUploadState> {
  final LabelRepository _labelRepository;
  final ConnectivityStatusService _connectivityStatusService;
  final DocumentUploadService _uploadService;

  DocumentUploadCubit(
    this._labelRepository,
    PaperlessDocumentsApi documentApi,
    this._connectivityStatusService,
    PendingTasksNotifier tasksNotifier,
  )   : _uploadService = DocumentUploadService(documentApi, tasksNotifier),
        super(const DocumentUploadState());

  Future<String?> upload(
    Uint8List bytes, {
    required String filename,
    required String title,
    required String userId,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    DateTime? createdAt,
    int? asn,
  }) async {
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
        onProgressChanged: (progress) {
          if (!isClosed) {
            emit(state.copyWith(uploadProgress: progress));
          }
        },
      );
      return taskId;
    } on PaperlessApiException catch (error) {
      addError(TransientPaperlessApiError(
        code: error.code,
        details: error.details,
      ));
      return null;
    }
  }
}
