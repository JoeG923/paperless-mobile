import 'package:flutter/material.dart';
import 'package:paperless_mobile/features/settings/view/upload_preset_settings_page.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class UploadPresetSettingsTile extends StatelessWidget {
  const UploadPresetSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.cloud_upload_outlined),
      title: Text(S.of(context)!.uploadPresets),
      subtitle: Text(S.of(context)!.uploadPresetsSubtitle),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const UploadPresetSettingsPage(),
          ),
        );
      },
    );
  }
}
