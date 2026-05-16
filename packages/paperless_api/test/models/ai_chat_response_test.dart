import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  test('parses chat content without metadata trailer', () {
    final response = AiChatResponse.parse('The invoice total is \$42.');

    expect(response.content, 'The invoice total is \$42.');
    expect(response.references, isEmpty);
  });

  test('parses references from paperless chat metadata trailer', () {
    final response = AiChatResponse.parse(
      'The total is \$42.\n\n'
      '__PAPERLESS_CHAT_METADATA__'
      '{"references":[{"id":12,"title":"Invoice A"}]}',
    );

    expect(response.content, 'The total is \$42.');
    expect(response.references.single.id, 12);
    expect(response.references.single.title, 'Invoice A');
  });

  test('ignores malformed metadata without exposing delimiter text', () {
    final response = AiChatResponse.parse(
      'The total is \$42.\n\n__PAPERLESS_CHAT_METADATA__{bad json',
    );

    expect(response.content, 'The total is \$42.');
    expect(response.references, isEmpty);
  });
}
