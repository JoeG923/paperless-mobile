import 'package:json_annotation/json_annotation.dart';

part 'paperless_ui_settings_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class PaperlessUiSettingsModel {
  final String displayName;
  final Map<String, dynamic> settings;

  PaperlessUiSettingsModel({
    required this.displayName,
    this.settings = const {},
  });

  bool get aiEnabled => settings['ai_enabled'] == true;

  factory PaperlessUiSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$PaperlessUiSettingsModelFromJson(json);

  Map<String, dynamic> toJson() => _$PaperlessUiSettingsModelToJson(this);
}
