import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/document_upload/cubit/document_upload_cubit.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';

class FakeTasksApi implements PaperlessTasksApi {
  @override
  Future<Task?> find({int? id, String? taskId}) async => null;

  @override
  Future<Iterable<Task>> findAll([Iterable<int>? ids]) async => const [];

  @override
  Stream<Task> listenForTaskChanges(String taskId) => const Stream.empty();

  @override
  Future<Task> acknowledgeTask(Task task) async => task;

  @override
  Future<Iterable<Task>> acknowledgeTasks(Iterable<Task> tasks) async => tasks;
}

class FailingDocumentsApi implements PaperlessDocumentsApi {
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
    throw const PaperlessApiException(ErrorCode.documentUploadFailed);
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
    throw const PaperlessApiException(ErrorCode.documentUploadFailed);
  }

  @override
  Future<DocumentModel> update(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<int> findNextAsn() {
    throw UnimplementedError();
  }

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(DocumentFilter filter) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> find(int id, {bool fullPermissions = false}) {
    throw UnimplementedError();
  }

  @override
  Future<int> delete(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentMetaData> getMetaData(int id) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> deleteNote(DocumentModel document, int noteId) {
    throw UnimplementedError();
  }

  @override
  Future<Iterable<int>> bulkAction(BulkAction action) {
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
  Future<Uint8List> downloadDocument(int id, {bool original = false}) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadToFile(
    int id,
    String localFilePath, {
    bool original = false,
    void Function(double progress)? onProgressChanged,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FieldSuggestions> findSuggestions(DocumentModel document) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> autocomplete(String query, [int limit = 10]) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> addNote({
    required DocumentModel document,
    required String text,
  }) {
    throw UnimplementedError();
  }
}

class SlowDocumentsApi implements PaperlessDocumentsApi {
  final Duration delay;

  SlowDocumentsApi(this.delay);

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
    await Future<void>.delayed(delay);
    return 'task-1';
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
    await Future<void>.delayed(delay);
    return 'task-1';
  }

  @override
  Future<DocumentModel> update(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<int> findNextAsn() {
    throw UnimplementedError();
  }

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(DocumentFilter filter) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> find(int id, {bool fullPermissions = false}) {
    throw UnimplementedError();
  }

  @override
  Future<int> delete(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentMetaData> getMetaData(int id) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> deleteNote(DocumentModel document, int noteId) {
    throw UnimplementedError();
  }

  @override
  Future<Iterable<int>> bulkAction(BulkAction action) {
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
  Future<Uint8List> downloadDocument(int id, {bool original = false}) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadToFile(
    int id,
    String localFilePath, {
    bool original = false,
    void Function(double progress)? onProgressChanged,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FieldSuggestions> findSuggestions(DocumentModel document) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> autocomplete(String query, [int limit = 10]) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> addNote({
    required DocumentModel document,
    required String text,
  }) {
    throw UnimplementedError();
  }
}

class CancellableDocumentsApi implements PaperlessDocumentsApi {
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
    if (cancelToken == null) {
      throw const PaperlessApiException(ErrorCode.requestCancelled);
    }
    await cancelToken.whenCancel;
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
    if (cancelToken == null) {
      throw const PaperlessApiException(ErrorCode.requestCancelled);
    }
    await cancelToken.whenCancel;
    throw const PaperlessApiException(ErrorCode.requestCancelled);
  }

  @override
  Future<DocumentModel> update(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<int> findNextAsn() {
    throw UnimplementedError();
  }

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(DocumentFilter filter) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> find(int id, {bool fullPermissions = false}) {
    throw UnimplementedError();
  }

  @override
  Future<int> delete(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentMetaData> getMetaData(int id) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> deleteNote(DocumentModel document, int noteId) {
    throw UnimplementedError();
  }

  @override
  Future<Iterable<int>> bulkAction(BulkAction action) {
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
  Future<Uint8List> downloadDocument(int id, {bool original = false}) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadToFile(
    int id,
    String localFilePath, {
    bool original = false,
    void Function(double progress)? onProgressChanged,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FieldSuggestions> findSuggestions(DocumentModel document) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> autocomplete(String query, [int limit = 10]) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> addNote({
    required DocumentModel document,
    required String text,
  }) {
    throw UnimplementedError();
  }
}

class RecordingDocumentsApi extends FailingDocumentsApi {
  UploadCustomFields? lastCustomFields;

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
    lastCustomFields = customFields;
    return 'task-1';
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
    lastCustomFields = customFields;
    return 'task-1';
  }
}

void main() {
  test('DocumentUploadState copyWith clears uploadProgress', () {
    const state = DocumentUploadState(uploadProgress: 0.5);

    final cleared = state.copyWith(uploadProgress: null);

    expect(cleared.uploadProgress, isNull);
  });

  test('DocumentUploadCubit clears progress after failed upload', () async {
    final cubit = DocumentUploadCubit(
      FailingDocumentsApi(),
      PendingTasksNotifier(FakeTasksApi()),
    );
    final states = <DocumentUploadState>[];
    final subscription = cubit.stream.listen(states.add);

    final outcome = await cubit.upload(
      Uint8List(1),
      filename: 'scan.pdf',
      title: 'Scan',
    );
    await Future<void>.delayed(Duration.zero);

    expect(outcome.success, isFalse);
    expect(outcome.error?.code, ErrorCode.documentUploadFailed);
    expect(states, isNotEmpty);
    expect(states.first.uploadProgress, 0);
    expect(states.any((state) => state.uploadProgress == null), isTrue);
    expect(cubit.state.uploadProgress, isNull);

    await subscription.cancel();
    await cubit.close();
  });

  test(
    'DocumentUploadCubit returns request timed out on slow upload',
    () async {
      final cubit = DocumentUploadCubit(
        SlowDocumentsApi(const Duration(milliseconds: 200)),
        PendingTasksNotifier(FakeTasksApi()),
      );

      final outcome = await cubit.upload(
        Uint8List(4),
        filename: 'scan.pdf',
        title: 'Scan',
        timeout: const Duration(milliseconds: 50),
      );

      expect(outcome.success, isFalse);
      expect(outcome.error?.code, ErrorCode.requestTimedOut);
      await cubit.close();
    },
  );

  test('DocumentUploadCubit fails on empty upload bytes', () async {
    final cubit = DocumentUploadCubit(
      SlowDocumentsApi(Duration.zero),
      PendingTasksNotifier(FakeTasksApi()),
    );

    final outcome = await cubit.upload(
      Uint8List(0),
      filename: 'scan.pdf',
      title: 'Scan',
    );

    expect(outcome.success, isFalse);
    expect(outcome.error?.code, ErrorCode.documentUploadFailed);
    expect(outcome.error?.details, 'File is empty.');
    await cubit.close();
  });

  test(
    'DocumentUploadCubit returns cancelled when upload is cancelled',
    () async {
      final cubit = DocumentUploadCubit(
        CancellableDocumentsApi(),
        PendingTasksNotifier(FakeTasksApi()),
      );

      final future = cubit.upload(
        Uint8List(4),
        filename: 'scan.pdf',
        title: 'Scan',
        timeout: const Duration(seconds: 2),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      cubit.cancelUpload();

      final outcome = await future;

      expect(outcome.cancelled, isTrue);
      expect(outcome.error?.code, ErrorCode.requestCancelled);
      await cubit.close();
    },
  );

  test('DocumentUploadCubit forwards customFields to upload API', () async {
    final api = RecordingDocumentsApi();
    final cubit = DocumentUploadCubit(
      api,
      PendingTasksNotifier(FakeTasksApi()),
    );
    final customFields = UploadCustomFields.values({99: 'value'});

    final outcome = await cubit.upload(
      Uint8List(4),
      filename: 'scan.pdf',
      title: 'Scan',
      customFields: customFields,
    );

    expect(outcome.success, isTrue);
    expect(api.lastCustomFields, same(customFields));
    await cubit.close();
  });
}
