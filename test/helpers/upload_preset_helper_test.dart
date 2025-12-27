import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/helpers/upload_preset_helper.dart';

void main() {
  test('buildTitleFromTemplate replaces tokens', () {
    final now = DateTime(2025, 12, 25, 8, 30, 15);
    final title = buildTitleFromTemplate(
      'Scan {date} {datetime} {time}',
      now,
    );
    expect(title, 'Scan 2025-12-25 2025-12-25_08-30 08-30');
  });

  test('buildTitleFromTemplate falls back to default title', () {
    final now = DateTime(2025, 12, 25, 8, 30, 15);
    final title = buildTitleFromTemplate('', now);
    expect(title, defaultScanTitle(now));
  });
}
