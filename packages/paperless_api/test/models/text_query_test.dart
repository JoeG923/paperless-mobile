import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('TextQuery.matches', () {
    test('title query is case-insensitive', () {
      const query = TextQuery.title('invoice');
      expect(
        query.matches(title: 'Invoice 2026', content: null, asn: null),
        isTrue,
      );
    });

    test('title and content query matches content when title misses', () {
      const query = TextQuery.titleAndContent('receipt');
      expect(
        query.matches(
          title: 'Travel Expense',
          content: 'Taxi receipt attached',
          asn: null,
        ),
        isTrue,
      );
    });

    test('extended query requires all positive terms', () {
      const query = TextQuery.extended('invoice paid');
      expect(
        query.matches(
          title: 'Invoice payment confirmation',
          content: 'Paid in full',
          asn: null,
        ),
        isTrue,
      );
      expect(
        query.matches(
          title: 'Invoice payment confirmation',
          content: 'Awaiting transfer',
          asn: null,
        ),
        isFalse,
      );
    });

    test('extended query supports negated terms', () {
      const query = TextQuery.extended('invoice -draft');
      expect(
        query.matches(
          title: 'Invoice 2026',
          content: 'Final version',
          asn: null,
        ),
        isTrue,
      );
      expect(
        query.matches(title: 'Invoice 2026 draft', content: 'Draft', asn: null),
        isFalse,
      );
    });

    test('extended query supports scoped fields and quoted values', () {
      const query = TextQuery.extended(
        'title:"final invoice" content:approved',
      );
      expect(
        query.matches(
          title: 'Final Invoice - February',
          content: 'Approved by accounting',
          asn: null,
        ),
        isTrue,
      );
      expect(
        query.matches(
          title: 'Final Invoice - February',
          content: 'Pending approval',
          asn: null,
        ),
        isFalse,
      );
    });

    test('extended query supports ASN matching', () {
      const query = TextQuery.extended('asn:42');
      expect(query.matches(title: 'Doc', content: null, asn: 42), isTrue);
      expect(query.matches(title: 'Doc', content: null, asn: 41), isFalse);
    });
  });
}
