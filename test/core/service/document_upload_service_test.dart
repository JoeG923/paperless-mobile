import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/service/document_upload_service.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';

class _SequencedDocumentsApi implements PaperlessDocumentsApi {
  final List<Object?> createOutcomes;
  int createCallCount = 0;
  int createFromFileCallCount = 0;

  _SequencedDocumentsApi(this.createOutcomes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String?> create(
    Uint8List documentBytes, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    createCallCount += 1;
    return _nextOutcome();
  }

  @override
  Future<String?> createFromFile(
    String filePath, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    createFromFileCallCount += 1;
    return _nextOutcome();
  }

  Future<String?> _nextOutcome() async {
    if (createOutcomes.isEmpty) {
      return null;
    }
    final next = createOutcomes.removeAt(0);
    if (next is Exception) {
      throw next;
    }
    if (next is Future<String?>) {
      return next;
    }
    return next as String?;
  }

  @override
  Future<DocumentModel> addNote({
    required DocumentModel document,
    required String text,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> autocomplete(String query, [int limit = 10]) {
    throw UnimplementedError();
  }

  @override
  Future<Iterable<int>> bulkAction(BulkAction action) {
    throw UnimplementedError();
  }

  @override
  Future<int> delete(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> deleteNote(DocumentModel document, int noteId) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadToFile(
    int id,
    String localFilePath, {
    bool original = false,
    void Function(double p1)? onProgressChanged,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> downloadDocument(int id, {bool original = false}) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> find(int id, {bool fullPermissions = false}) {
    throw UnimplementedError();
  }

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(DocumentFilter filter) {
    throw UnimplementedError();
  }

  @override
  Future<int> findNextAsn() {
    throw UnimplementedError();
  }

  @override
  Future<FieldSuggestions> findSuggestions(DocumentModel document) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentMetaData> getMetaData(int id) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> getPreview(int docId) {
    throw UnimplementedError();
  }

  @override
  String getThumbnailUrl(int docId) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> update(DocumentModel doc) {
    throw UnimplementedError();
  }
}

class _NoopTasksApi implements PaperlessTasksApi {
  @override
  Future<Task> acknowledgeTask(Task task) async => task;

  @override
  Future<Iterable<Task>> acknowledgeTasks(Iterable<Task> tasks) async => tasks;

  @override
  Future<Task?> find({int? id, String? taskId}) async => null;

  @override
  Future<Iterable<Task>> findAll([Iterable<int>? ids]) async => const [];

  @override
  Stream<Task> listenForTaskChanges(String taskId) => const Stream.empty();
}

class _RecordingPendingTasksNotifier extends PendingTasksNotifier {
  final List<String> listenedTaskIds = [];

  _RecordingPendingTasksNotifier() : super(_NoopTasksApi());

  @override
  void listenToTaskChanges(String taskId) {
    listenedTaskIds.add(taskId);
  }
}

class _CapturingDocumentsApi extends _SequencedDocumentsApi {
  Uint8List? lastBytes;
  String? lastFilename;
  String? lastTitle;
  int? lastDocumentType;
  int? lastCorrespondent;
  int? lastStoragePath;
  List<int>? lastTags;
  UploadCustomFields? lastCustomFields;
  DateTime? lastCreatedAt;
  int? lastAsn;
  Duration? lastTimeout;
  CancelToken? lastCancelToken;

  _CapturingDocumentsApi(super.createOutcomes);

  @override
  Future<String?> create(
    Uint8List documentBytes, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    lastBytes = documentBytes;
    lastFilename = filename;
    lastTitle = title;
    lastDocumentType = documentType;
    lastCorrespondent = correspondent;
    lastStoragePath = storagePath;
    lastTags = tags.toList();
    lastCustomFields = customFields;
    lastCreatedAt = createdAt;
    lastAsn = asn;
    lastTimeout = timeout;
    lastCancelToken = cancelToken;
    return super.create(
      documentBytes,
      filename: filename,
      title: title,
      createdAt: createdAt,
      documentType: documentType,
      correspondent: correspondent,
      storagePath: storagePath,
      tags: tags,
      customFields: customFields,
      asn: asn,
      onProgressChanged: onProgressChanged,
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }
}

class _CancelingUploadApi extends _SequencedDocumentsApi {
  _CancelingUploadApi() : super(const []);

  @override
  Future<String?> create(
    Uint8List documentBytes, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    createCallCount += 1;
    if (cancelToken != null) {
      await cancelToken.whenCancel;
      throw const PaperlessApiException(ErrorCode.requestCancelled);
    }
    throw const PaperlessApiException(ErrorCode.requestCancelled);
  }

  @override
  Future<String?> createFromFile(
    String filePath, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }
}

class _SequencingWithCapturedRecords extends _CapturingDocumentsApi {
  String? lastFilePath;

  _SequencingWithCapturedRecords(super.createOutcomes);

  @override
  Future<String?> createFromFile(
    String filePath, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    lastFilePath = filePath;
    lastFilename = filename;
    lastTitle = title;
    lastDocumentType = documentType;
    lastCorrespondent = correspondent;
    lastStoragePath = storagePath;
    lastTags = tags.toList();
    lastCustomFields = customFields;
    lastCreatedAt = createdAt;
    lastAsn = asn;
    lastTimeout = timeout;
    lastCancelToken = cancelToken;
    return super.createFromFile(
      filePath,
      filename: filename,
      title: title,
      createdAt: createdAt,
      documentType: documentType,
      correspondent: correspondent,
      storagePath: storagePath,
      tags: tags,
      customFields: customFields,
      asn: asn,
      onProgressChanged: onProgressChanged,
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }
}

void main() {
  group('DocumentUploadService', () {
    test('retries transient upload failures and succeeds', () async {
      final api = _SequencedDocumentsApi([
        const PaperlessApiException(ErrorCode.requestTimedOut),
        'task-42',
      ]);
      final notifier = _RecordingPendingTasksNotifier();
      final delays = <Duration>[];
      final service = DocumentUploadService(
        api,
        notifier,
        sleep: (duration) async => delays.add(duration),
      );

      final taskId = await service.upload(
        Uint8List.fromList([1, 2, 3]),
        filename: 'doc.pdf',
        title: 'Doc',
      );

      expect(taskId, 'task-42');
      expect(api.createCallCount, 2);
      expect(delays, [const Duration(seconds: 1)]);
      expect(notifier.listenedTaskIds, ['task-42']);
      notifier.dispose();
    });

    test('does not retry non-transient upload errors', () async {
      final api = _SequencedDocumentsApi([
        const PaperlessApiException(ErrorCode.documentUploadFailed),
      ]);
      final notifier = _RecordingPendingTasksNotifier();
      final delays = <Duration>[];
      final service = DocumentUploadService(
        api,
        notifier,
        sleep: (duration) async => delays.add(duration),
      );

      await expectLater(
        () => service.upload(
          Uint8List.fromList([1, 2, 3]),
          filename: 'doc.pdf',
          title: 'Doc',
        ),
        throwsA(isA<PaperlessApiException>()),
      );
      expect(api.createCallCount, 1);
      expect(delays, isEmpty);
      expect(notifier.listenedTaskIds, isEmpty);
      notifier.dispose();
    });

    test('stops retrying after max attempts', () async {
      final api = _SequencedDocumentsApi([
        const PaperlessApiException(ErrorCode.requestTimedOut),
        const PaperlessApiException(ErrorCode.serverUnreachable),
        const PaperlessApiException(ErrorCode.deviceOffline),
      ]);
      final notifier = _RecordingPendingTasksNotifier();
      final delays = <Duration>[];
      final service = DocumentUploadService(
        api,
        notifier,
        sleep: (duration) async => delays.add(duration),
      );

      await expectLater(
        () => service.upload(
          Uint8List.fromList([1, 2, 3]),
          filename: 'doc.pdf',
          title: 'Doc',
        ),
        throwsA(isA<PaperlessApiException>()),
      );
      expect(api.createCallCount, 3);
      expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
      expect(notifier.listenedTaskIds, isEmpty);
      notifier.dispose();
    });

    test('rejects empty file bytes before calling api', () async {
      final api = _SequencedDocumentsApi(['task-ignored']);
      final notifier = _RecordingPendingTasksNotifier();
      final service = DocumentUploadService(api, notifier);

      await expectLater(
        () => service.upload(Uint8List(0), filename: 'doc.pdf', title: 'Doc'),
        throwsA(
          isA<PaperlessApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.documentUploadFailed,
          ),
        ),
      );
      expect(api.createCallCount, 0);
      expect(notifier.listenedTaskIds, isEmpty);
      notifier.dispose();
    });

    test(
      'uploadFile retries transient failures and tracks created task',
      () async {
        final api = _SequencedDocumentsApi([
          const PaperlessApiException(ErrorCode.serverUnreachable),
          'task-file-1',
        ]);
        final notifier = _RecordingPendingTasksNotifier();
        final delays = <Duration>[];
        final service = DocumentUploadService(
          api,
          notifier,
          sleep: (duration) async => delays.add(duration),
        );

        final taskId = await service.uploadFile(
          '/tmp/upload.pdf',
          filename: 'upload.pdf',
          title: 'Upload',
        );

        expect(taskId, 'task-file-1');
        expect(api.createFromFileCallCount, 2);
        expect(delays, [const Duration(seconds: 1)]);
        expect(notifier.listenedTaskIds, ['task-file-1']);
        notifier.dispose();
      },
    );

    test('upload timeout cancels token and throws requestTimedOut', () async {
      final api = _SequencedDocumentsApi([
        Future<String?>.delayed(
          const Duration(milliseconds: 10),
          () => 'task-too-late',
        ),
      ]);
      final notifier = _RecordingPendingTasksNotifier();
      final service = DocumentUploadService(api, notifier, maxRetryAttempts: 0);
      final cancelToken = CancelToken();

      await expectLater(
        () => service.upload(
          Uint8List.fromList([9, 8, 7]),
          filename: 'slow.pdf',
          title: 'Slow',
          timeout: Duration.zero,
          cancelToken: cancelToken,
        ),
        throwsA(
          isA<PaperlessApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.requestTimedOut,
          ),
        ),
      );
      expect(cancelToken.isCancelled, isTrue);
      expect(notifier.listenedTaskIds, isEmpty);
      notifier.dispose();
    });

    test('forwards upload request arguments and preserves bytes', () async {
      final createdAt = DateTime(2026, 1, 1, 9, 0);
      final customFields = UploadCustomFields.values({11: 'value', 12: 7});
      final api = _CapturingDocumentsApi(['task-88']);
      final notifier = _RecordingPendingTasksNotifier();
      final cancelToken = CancelToken();
      final service = DocumentUploadService(api, notifier);

      final sourceBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final taskId = await service.upload(
        sourceBytes,
        filename: 'source_file.pdf',
        title: 'Source title',
        documentType: 3,
        correspondent: 4,
        storagePath: 5,
        tags: [7, 8],
        customFields: customFields,
        createdAt: createdAt,
        asn: 12,
        timeout: const Duration(seconds: 4),
        cancelToken: cancelToken,
      );

      expect(taskId, 'task-88');
      expect(api.lastBytes, isNotNull);
      expect(identical(api.lastBytes, sourceBytes), isTrue);
      expect(api.lastFilename, 'source_file.pdf');
      expect(api.lastTitle, 'Source title');
      expect(api.lastDocumentType, 3);
      expect(api.lastCorrespondent, 4);
      expect(api.lastStoragePath, 5);
      expect(api.lastTags, [7, 8]);
      expect(api.lastCustomFields, same(customFields));
      expect(api.lastCreatedAt, same(createdAt));
      expect(api.lastAsn, 12);
      expect(api.createCallCount, 1);
      expect(api.lastTimeout, const Duration(seconds: 4));
      expect(api.lastCancelToken, same(cancelToken));
      expect(notifier.listenedTaskIds, ['task-88']);
      notifier.dispose();
    });

    test('does not retry after upload cancellation', () async {
      final api = _CancelingUploadApi();
      final notifier = _RecordingPendingTasksNotifier();
      final cancelToken = CancelToken();
      final service = DocumentUploadService(
        api,
        notifier,
        maxRetryAttempts: 5,
        sleep: (_) async {},
      );

      final uploadFuture = service.upload(
        Uint8List.fromList([1, 2, 3]),
        filename: 'cancel.pdf',
        title: 'Cancelled',
        cancelToken: cancelToken,
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      cancelToken.cancel('user');
      await expectLater(
        uploadFuture,
        throwsA(
          isA<PaperlessApiException>().having(
            (error) => error.code,
            'code',
            ErrorCode.requestCancelled,
          ),
        ),
      );

      expect(api.createCallCount, 1);
      expect(notifier.listenedTaskIds, isEmpty);
      notifier.dispose();
    });

    test('uploadFile forwards file path and metadata', () async {
      final api = _SequencingWithCapturedRecords(['task-path']);
      final notifier = _RecordingPendingTasksNotifier();
      final service = DocumentUploadService(api, notifier);

      final taskId = await service.uploadFile(
        '/tmp/my-file.pdf',
        filename: 'renamed.pdf',
        title: 'Uploaded file',
        documentType: 1,
        correspondent: 2,
        storagePath: 3,
        tags: [1, 2],
        asn: 9,
        createdAt: DateTime(2026, 2, 2),
      );

      expect(taskId, 'task-path');
      expect(api.lastFilePath, '/tmp/my-file.pdf');
      expect(api.lastFilename, 'renamed.pdf');
      expect(api.lastTitle, 'Uploaded file');
      expect(api.lastDocumentType, 1);
      expect(api.lastCorrespondent, 2);
      expect(api.lastStoragePath, 3);
      expect(api.lastTags, [1, 2]);
      expect(api.lastAsn, 9);
      expect(api.createFromFileCallCount, 1);
      expect(notifier.listenedTaskIds, ['task-path']);
      notifier.dispose();
    });
  });
}
