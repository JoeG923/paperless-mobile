import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';

void main() {
  DocumentModel document(int id) {
    final now = DateTime(2026, 1, id);
    return DocumentModel(
      id: id,
      title: 'doc-$id',
      documentType: null,
      correspondent: null,
      created: now,
      modified: now,
      added: now,
    );
  }

  test('removeListener unsubscribes subscriber and stops callbacks', () async {
    final notifier = DocumentChangedNotifier();
    final events = <int>[];

    notifier.addListener('subscriber', onUpdated: (doc) => events.add(doc.id));

    notifier.notifyUpdated(document(1));
    await Future<void>.delayed(Duration.zero);
    expect(events, [1]);

    notifier.removeListener('subscriber');
    notifier.notifyUpdated(document(2));
    await Future<void>.delayed(Duration.zero);
    expect(events, [1]);

    notifier.close();
  });
}
