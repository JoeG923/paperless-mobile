part of 'document_upload_cubit.dart';

@immutable
class DocumentUploadState {
  static const _uploadProgressSentinel = Object();

  final double? uploadProgress;
  const DocumentUploadState({this.uploadProgress});

  DocumentUploadState copyWith({
    Object? uploadProgress = _uploadProgressSentinel,
  }) {
    return DocumentUploadState(
      uploadProgress: uploadProgress == _uploadProgressSentinel
          ? this.uploadProgress
          : uploadProgress as double?,
    );
  }
}
