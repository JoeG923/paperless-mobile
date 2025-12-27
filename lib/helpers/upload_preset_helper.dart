import 'package:intl/intl.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';

class UploadPreset {
  final bool enabled;
  final String titleTemplate;
  final bool useCurrentDate;
  final int? correspondentId;
  final int? documentTypeId;
  final int? storagePathId;
  final List<int> tagIds;

  const UploadPreset({
    required this.enabled,
    required this.titleTemplate,
    required this.useCurrentDate,
    required this.correspondentId,
    required this.documentTypeId,
    required this.storagePathId,
    required this.tagIds,
  });

  factory UploadPreset.fromSettings(GlobalSettings settings) {
    return UploadPreset(
      enabled: settings.uploadPresetEnabled,
      titleTemplate: settings.uploadPresetTitleTemplate,
      useCurrentDate: settings.uploadPresetUseCurrentDate,
      correspondentId: settings.uploadPresetCorrespondentId,
      documentTypeId: settings.uploadPresetDocumentTypeId,
      storagePathId: settings.uploadPresetStoragePathId,
      tagIds: List<int>.from(settings.uploadPresetTagIds),
    );
  }

  String buildTitle(DateTime now) {
    return buildTitleFromTemplate(titleTemplate, now);
  }
}

String buildTitleFromTemplate(String template, DateTime now) {
  final normalizedTemplate = template.trim();
  if (normalizedTemplate.isEmpty) {
    return defaultScanTitle(now);
  }
  return normalizedTemplate
      .replaceAll('{date}', DateFormat('yyyy-MM-dd').format(now))
      .replaceAll('{datetime}', DateFormat('yyyy-MM-dd_HH-mm').format(now))
      .replaceAll('{time}', DateFormat('HH-mm').format(now));
}

String defaultScanTitle(DateTime now) {
  return 'scan_${DateFormat('yyyy_MM_ddTHH_mm_ss').format(now)}';
}

String formatFilename(String source) {
  return source.replaceAll(RegExp(r'[\\W_]'), '_').toLowerCase();
}
