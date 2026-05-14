import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('PaperlessDocumentsApiImpl API-version-aware search', () {
    test('uses title_content without an API override on API v9', () async {
      final adapter = _SearchRecordingAdapter();
      final api = PaperlessDocumentsApiImpl(
        Dio()..httpClientAdapter = adapter,
        apiVersion: 9,
      );

      await api.findAll(
        DocumentFilter(query: const TextQuery.titleAndContent('invoice')),
      );

      expect(adapter.request!.queryParameters['title_content'], 'invoice');
      expect(adapter.request!.queryParameters, isNot(contains('text')));
      expect(
        adapter.request!.extra,
        isNot(contains(paperlessApiVersionOverrideExtraKey)),
      );
    });

    test('uses text with an API v10 override on API v10', () async {
      final adapter = _SearchRecordingAdapter();
      final api = PaperlessDocumentsApiImpl(
        Dio()..httpClientAdapter = adapter,
        apiVersion: 10,
      );

      await api.findAll(
        DocumentFilter(query: const TextQuery.titleAndContent('invoice')),
      );

      expect(adapter.request!.queryParameters['text'], 'invoice');
      expect(
        adapter.request!.queryParameters,
        isNot(contains('title_content')),
      );
      expect(adapter.request!.extra[paperlessApiVersionOverrideExtraKey], 10);
    });

    test('uses title_search for title-only search on API v10', () async {
      final adapter = _SearchRecordingAdapter();
      final api = PaperlessDocumentsApiImpl(
        Dio()..httpClientAdapter = adapter,
        apiVersion: 10,
      );

      await api.findAll(
        DocumentFilter(query: const TextQuery.title('receipt')),
      );

      expect(adapter.request!.queryParameters['title_search'], 'receipt');
      expect(
        adapter.request!.queryParameters,
        isNot(contains('title__icontains')),
      );
    });

    test('keeps advanced query unchanged on API v10', () async {
      final adapter = _SearchRecordingAdapter();
      final api = PaperlessDocumentsApiImpl(
        Dio()..httpClientAdapter = adapter,
        apiVersion: 10,
      );

      await api.findAll(
        DocumentFilter(query: const TextQuery.extended('tag:tax')),
      );

      expect(adapter.request!.queryParameters['query'], 'tag:tax');
    });

    test('ignores additional v3 document fields in API v10 results', () async {
      final adapter = _SearchRecordingAdapter(
        results: [
          {
            'id': 1,
            'title': 'Invoice',
            'content': 'body',
            'tags': <int>[],
            'document_type': null,
            'correspondent': null,
            'storage_path': null,
            'created': '2026-01-01T00:00:00Z',
            'modified': '2026-01-01T00:00:00Z',
            'added': '2026-01-01T00:00:00Z',
            'archive_serial_number': null,
            'original_file_name': 'invoice.pdf',
            'archived_file_name': null,
            'notes': <Object>[],
            'custom_fields': <Object>[],
            'root_document': null,
            'versions': <Object>[],
          },
        ],
      );
      final api = PaperlessDocumentsApiImpl(
        Dio()..httpClientAdapter = adapter,
        apiVersion: 10,
      );

      final result = await api.findAll(DocumentFilter.initial);

      expect(result.results.single.title, 'Invoice');
    });
  });
}

class _SearchRecordingAdapter implements HttpClientAdapter {
  final List<Map<String, Object?>> results;
  RequestOptions? request;

  _SearchRecordingAdapter({this.results = const []});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final body = jsonEncode({
      'count': results.length,
      'next': null,
      'previous': null,
      'all': <int>[],
      'results': results,
    });
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
