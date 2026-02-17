import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/document_scan/view/widgets/scanned_image_item.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

void main() {
  late File imageFile;

  setUp(() async {
    imageFile = File(
      '${Directory.systemTemp.path}/paperless_scanned_item_test.png',
    );
    await imageFile.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8Xw8AAoMBgNqT9XwAAAAASUVORK5CYII=',
      ),
      flush: true,
    );
  });

  tearDown(() async {
    if (await imageFile.exists()) {
      await imageFile.delete();
    }
  });

  testWidgets('uses localized remove label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: ScannedImageItem(
            file: imageFile,
            onDelete: () {},
            index: 0,
            totalNumberOfFiles: 1,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Entfernen'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
  });
}
