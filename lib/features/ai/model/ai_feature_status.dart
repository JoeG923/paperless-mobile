import 'package:paperless_api/paperless_api.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class AiFeatureStatus {
  final bool enabled;
  final SystemStatusItemStatus llmIndexStatus;
  final DateTime? llmIndexLastModified;
  final String? llmIndexError;

  const AiFeatureStatus({
    required this.enabled,
    this.llmIndexStatus = SystemStatusItemStatus.unknown,
    this.llmIndexLastModified,
    this.llmIndexError,
  });

  const AiFeatureStatus.disabled() : this(enabled: false);

  bool get isIndexHealthy =>
      llmIndexStatus == SystemStatusItemStatus.ok ||
      llmIndexStatus == SystemStatusItemStatus.unknown;

  static Future<AiFeatureStatus> load({
    required PaperlessServerStatsApi serverStatsApi,
    required int apiVersion,
  }) async {
    if (apiVersion < 10) {
      return const AiFeatureStatus.disabled();
    }

    final uiSettings = await serverStatsApi.getUiSettings();
    if (!uiSettings.aiEnabled) {
      return const AiFeatureStatus.disabled();
    }

    try {
      final systemStatus = await serverStatsApi.getSystemStatus();
      return AiFeatureStatus(
        enabled: true,
        llmIndexStatus: systemStatus.llmIndexStatus,
        llmIndexLastModified: systemStatus.llmIndexLastModified,
        llmIndexError: systemStatus.llmIndexError,
      );
    } on Object {
      return const AiFeatureStatus(enabled: true);
    }
  }
}

extension AiFeatureStatusContext on BuildContext {
  AiFeatureStatus watchAiFeatureStatusOrDisabled() {
    try {
      return watch<AiFeatureStatus>();
    } on ProviderNotFoundException {
      return const AiFeatureStatus.disabled();
    }
  }

  AiFeatureStatus readAiFeatureStatusOrDisabled() {
    try {
      return read<AiFeatureStatus>();
    } on ProviderNotFoundException {
      return const AiFeatureStatus.disabled();
    }
  }
}
