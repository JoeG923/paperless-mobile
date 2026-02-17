import 'package:paperless_mobile/features/document_upload/model/document_upload_result.dart';

void trackUploadTaskFromResult({
  required void Function(String) trackTaskId,
  required DocumentUploadResult? result,
}) {
  if (result == null || !result.success) {
    return;
  }

  final taskId = result.taskId?.trim();
  if (taskId == null || taskId.isEmpty) {
    return;
  }

  trackTaskId(taskId);
}
