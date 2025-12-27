import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/security/trusted_certificate_pin.dart';
import 'package:paperless_mobile/features/settings/model/color_scheme_option.dart';
import 'package:paperless_mobile/features/settings/model/file_download_type.dart';

part 'global_settings.g.dart';

@HiveType(typeId: HiveTypeIds.globalSettings)
class GlobalSettings with HiveObjectMixin {
  @HiveField(0)
  String preferredLocaleSubtag;

  @HiveField(1)
  ThemeMode preferredThemeMode;

  @HiveField(2)
  ColorSchemeOption preferredColorSchemeOption;

  @HiveField(3)
  bool showOnboarding;

  @HiveField(4)
  String? loggedInUserId;

  @HiveField(5)
  FileDownloadType defaultDownloadType;

  @HiveField(6)
  FileDownloadType defaultShareType;

  @HiveField(7, defaultValue: false)
  bool enforceSinglePagePdfUpload;

  @HiveField(8, defaultValue: false)
  bool skipDocumentPreprarationOnUpload;

  @HiveField(9, defaultValue: false)
  bool disableAnimations;

  @HiveField(10, defaultValue: true)
  bool scanFlashEnabled;

  @HiveField(11, defaultValue: <String>[])
  List<String> trustedCertificateHosts;

  @HiveField(12, defaultValue: false)
  bool uploadPresetEnabled;

  @HiveField(13, defaultValue: 'Scan {date}')
  String uploadPresetTitleTemplate;

  @HiveField(14, defaultValue: true)
  bool uploadPresetUseCurrentDate;

  @HiveField(15)
  int? uploadPresetCorrespondentId;

  @HiveField(16)
  int? uploadPresetDocumentTypeId;

  @HiveField(17)
  int? uploadPresetStoragePathId;

  @HiveField(18, defaultValue: <int>[])
  List<int> uploadPresetTagIds;

  @HiveField(19, defaultValue: <TrustedCertificatePin>[])
  List<TrustedCertificatePin> trustedCertificatePins;

  GlobalSettings({
    required this.preferredLocaleSubtag,
    this.preferredThemeMode = ThemeMode.system,
    this.preferredColorSchemeOption = ColorSchemeOption.classic,
    this.showOnboarding = true,
    this.loggedInUserId,
    this.defaultDownloadType = FileDownloadType.alwaysAsk,
    this.defaultShareType = FileDownloadType.alwaysAsk,
    this.enforceSinglePagePdfUpload = false,
    this.skipDocumentPreprarationOnUpload = false,
    this.disableAnimations = false,
    this.scanFlashEnabled = true,
    this.trustedCertificateHosts = const [],
    this.uploadPresetEnabled = false,
    this.uploadPresetTitleTemplate = 'Scan {date}',
    this.uploadPresetUseCurrentDate = true,
    this.uploadPresetCorrespondentId,
    this.uploadPresetDocumentTypeId,
    this.uploadPresetStoragePathId,
    this.uploadPresetTagIds = const [],
    this.trustedCertificatePins = const [],
  });
}
