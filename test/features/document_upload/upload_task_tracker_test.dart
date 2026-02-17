import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/document_upload/model/document_upload_result.dart';
import 'package:paperless_mobile/features/document_upload/util/upload_task_tracker.dart';

void main() {
  group('trackUploadTaskFromResult', () {
    test('tracks task ID for successful upload result with valid task id', () {
      final trackedTaskIds = <String>[];

      trackUploadTaskFromResult(
        trackTaskId: trackedTaskIds.add,
        result: const DocumentUploadResult.success('task-1'),
      );

      expect(trackedTaskIds, equals(['task-1']));
    });

    test('does not track when upload result is null', () {
      final trackedTaskIds = <String>[];

      trackUploadTaskFromResult(trackTaskId: trackedTaskIds.add, result: null);

      expect(trackedTaskIds, isEmpty);
    });

    test('does not track when upload failed', () {
      final trackedTaskIds = <String>[];

      trackUploadTaskFromResult(
        trackTaskId: trackedTaskIds.add,
        result: DocumentUploadResult.failure(
          const PaperlessApiException(ErrorCode.documentUploadFailed),
        ),
      );

      expect(trackedTaskIds, isEmpty);
    });

    test('ignores missing task id', () {
      final trackedTaskIds = <String>[];

      trackUploadTaskFromResult(
        trackTaskId: trackedTaskIds.add,
        result: const DocumentUploadResult.success(null),
      );

      expect(trackedTaskIds, isEmpty);
    });

    test('trims whitespace around task id', () {
      final trackedTaskIds = <String>[];

      trackUploadTaskFromResult(
        trackTaskId: trackedTaskIds.add,
        result: const DocumentUploadResult.success('  task-2  '),
      );

      expect(trackedTaskIds, equals(['task-2']));
    });
  });
}
