import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('PaperlessLabelApiImpl headers', () {
    test('getTags does not force an old API version', () async {
      final adapter = _LabelRecordingAdapter();
      final api = PaperlessLabelApiImpl(Dio()..httpClientAdapter = adapter);

      await api.getTags();

      expect(adapter.requests.single.headers, isNot(contains('accept')));
      expect(adapter.requests.single.headers, isNot(contains('Accept')));
    });

    test('saveTag does not force an old API version', () async {
      final adapter = _LabelRecordingAdapter();
      final api = PaperlessLabelApiImpl(Dio()..httpClientAdapter = adapter);

      await api.saveTag(const Tag(name: 'Inbox'));

      expect(adapter.requests.single.headers, isNot(contains('accept')));
      expect(adapter.requests.single.headers, isNot(contains('Accept')));
    });

    test('updateTag does not force an old API version', () async {
      final adapter = _LabelRecordingAdapter();
      final api = PaperlessLabelApiImpl(Dio()..httpClientAdapter = adapter);

      await api.updateTag(const Tag(id: 1, name: 'Inbox'));

      expect(adapter.requests.single.headers, isNot(contains('accept')));
      expect(adapter.requests.single.headers, isNot(contains('Accept')));
    });
  });
}

class _LabelRecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = switch (options.method) {
      'GET' => jsonEncode({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_tagJson],
      }),
      _ => jsonEncode(_tagJson),
    };
    return ResponseBody.fromString(
      body,
      options.method == 'POST' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const _tagJson = {
  'id': 1,
  'name': 'Inbox',
  'slug': 'inbox',
  'match': '',
  'matching_algorithm': 0,
  'is_insensitive': false,
  'document_count': 0,
  'color': null,
  'text_color': null,
  'is_inbox_tag': false,
};
