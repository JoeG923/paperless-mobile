import 'package:paperless_api/src/models/paperless_server_information_model.dart';
import 'package:paperless_api/src/models/paperless_server_statistics_model.dart';
import 'package:paperless_api/src/models/paperless_system_status_model.dart';
import 'package:paperless_api/src/models/paperless_ui_settings_model.dart';

abstract class PaperlessServerStatsApi {
  Future<PaperlessServerInformationModel> getServerInformation();
  Future<PaperlessServerStatisticsModel> getServerStatistics();
  Future<PaperlessUiSettingsModel> getUiSettings();
  Future<PaperlessSystemStatusModel> getSystemStatus();
}
