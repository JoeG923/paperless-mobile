import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paperless_mobile/features/document_scan/view/widgets/scanner_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late List<File> scans;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scanner_grid_test');
    scans = [];
    for (var i = 0; i < 6; i += 1) {
      final image = img.Image(width: 4, height: 4);
      image.setPixelRgba(0, 0, 255, 0, 0, 255);
      final bytes = img.encodePng(image);
      final file = File('${tempDir.path}/scan_$i.png');
      await file.writeAsBytes(bytes, flush: true);
      scans.add(file);
    }
  });

  tearDown(() async {
    for (final file in scans) {
      if (await file.exists()) {
        await file.delete();
      }
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpGrid(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final searchHandle = SliverOverlapAbsorberHandle();
    final actionsHandle = SliverOverlapAbsorberHandle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverOverlapAbsorber(
                handle: searchHandle,
                sliver: const SliverToBoxAdapter(child: SizedBox(height: 0)),
              ),
              SliverOverlapAbsorber(
                handle: actionsHandle,
                sliver: const SliverToBoxAdapter(child: SizedBox(height: 0)),
              ),
            ],
            body: ScannerGrid(
              scans: scans,
              searchBarHandle: searchHandle,
              actionsHandle: actionsHandle,
              onDelete: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int crossAxisCount(WidgetTester tester) {
    final renderGrid = tester.renderObject<RenderSliverGrid>(
      find.byType(SliverGrid),
    );
    final layout = renderGrid.gridDelegate.getLayout(renderGrid.constraints);
    final regularLayout = layout as SliverGridRegularTileLayout;
    return regularLayout.crossAxisCount;
  }

  testWidgets('uses more columns on wide widths', (WidgetTester tester) async {
    await pumpGrid(tester, const Size(360, 800));
    final narrowCount = crossAxisCount(tester);

    await pumpGrid(tester, const Size(800, 800));
    final wideCount = crossAxisCount(tester);

    expect(wideCount, greaterThan(narrowCount));
  });
}
