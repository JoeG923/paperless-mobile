class PaperlessServerStatisticsModel {
  final int documentsTotal;
  final int documentsInInbox;
  final int? totalChars;
  final List<DocumentFileTypeCount> fileTypeCounts;
  PaperlessServerStatisticsModel({
    required this.documentsTotal,
    required this.documentsInInbox,
    this.totalChars,
    this.fileTypeCounts = const [],
  });

  PaperlessServerStatisticsModel.fromJson(Map<String, dynamic> json)
    : documentsTotal = json['documents_total'] ?? 0,
      documentsInInbox = json['documents_inbox'] ?? 0,
      totalChars = json["character_count"],
      fileTypeCounts = _parseFileTypeCounts(json['document_file_type_counts']);

  static List<DocumentFileTypeCount> _parseFileTypeCounts(dynamic value) {
    if (value is List) {
      return value.map((e) => DocumentFileTypeCount.fromJson(e)).toList();
    }
    return [];
  }
}

class DocumentFileTypeCount {
  final String mimeType;
  final int count;

  DocumentFileTypeCount({required this.mimeType, required this.count});

  DocumentFileTypeCount.fromJson(Map<String, dynamic> json)
    : mimeType = json['mime_type'],
      count = json['mime_type_count'];
}
