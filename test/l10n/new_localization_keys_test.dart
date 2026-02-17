import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

void main() {
  test('new localization keys resolve in English', () async {
    final l10n = await S.delegate.load(const Locale('en'));

    expect(l10n.resetWithCount(3), 'Reset (3)');
    expect(l10n.couldNotLoadDocument, 'Could not load document.');
    expect(l10n.serverAddressHint, 'https://paperless.example.com');
    expect(l10n.apiTokenRemoteUserHint, 'x-remote-user:');
    expect(l10n.restoringScans, 'Restoring scans...');
    expect(
      l10n.grantFilesystemAccessPermission,
      'Please grant Paperless Mobile permissions to access your filesystem.',
    );
    expect(
      l10n.documentScanningAndroidOnly,
      'Document scanning is currently available on Android only.',
    );
    expect(l10n.disableAnimations, 'Disable animations');
    expect(
      l10n.disableAnimationsDescription,
      'Disables page transitions and most animations. Temporary workaround until system accessibility settings can be used.',
    );
    expect(
      l10n.pendingFilesUploadPrompt(1),
      '1 file is waiting to be uploaded. Do you want to upload it now?',
    );
    expect(
      l10n.pendingFilesUploadPrompt(2),
      '2 files are waiting to be uploaded. Do you want to upload them now?',
    );
    expect(l10n.paperlessMobileAppName, 'Paperless Mobile');
    expect(l10n.credits, 'Credits');
    expect(l10n.onboardingImagesBy, 'Onboarding images by');
    expect(l10n.onFreepik, 'on Freepik.');
    expect(l10n.donationSignature, '~ Anton');
  });
}
