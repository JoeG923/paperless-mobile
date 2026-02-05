import 'package:paperless_api/paperless_api.dart';

class DocumentUploadResult {
  final bool success;
  final bool cancelled;
  final String? taskId;
  final PaperlessApiException? error;

  const DocumentUploadResult._({
    required this.success,
    required this.cancelled,
    this.taskId,
    this.error,
  });

  const DocumentUploadResult.success(String? taskId)
    : this._(success: true, cancelled: false, taskId: taskId);

  const DocumentUploadResult.failure(PaperlessApiException error)
    : this._(success: false, cancelled: false, error: error);

  const DocumentUploadResult.cancelled()
    : this._(
        success: false,
        cancelled: true,
        error: const PaperlessApiException(ErrorCode.requestCancelled),
      );
}
