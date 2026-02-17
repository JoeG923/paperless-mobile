import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/sharing/view/dialog/pending_files_info_dialog.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester, List<File> files) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: PendingFilesInfoDialog(pendingFiles: files)),
      ),
    );
  }

  testWidgets('shows singular pending file prompt', (tester) async {
    await pumpDialog(tester, [File('first.pdf')]);

    expect(find.text('Pending files'), findsOneWidget);
    expect(
      find.text(
        '1 file is waiting to be uploaded. Do you want to upload it now?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows plural pending files prompt', (tester) async {
    await pumpDialog(tester, [File('first.pdf'), File('second.pdf')]);

    expect(find.text('Pending files'), findsOneWidget);
    expect(
      find.text(
        '2 files are waiting to be uploaded. Do you want to upload them now?',
      ),
      findsOneWidget,
    );
  });
}
