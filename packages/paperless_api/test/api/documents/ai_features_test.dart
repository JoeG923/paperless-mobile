import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  test('findAiSuggestions calls v3 AI suggestions endpoint', () async {
    final adapter = _JsonResponseAdapter({
      'title': 'AI title',
      'correspondents': [1],
      'suggested_correspondents': <String>[],
      'tags': [2],
      'suggested_tags': ['new-tag'],
      'document_types': [3],
      'suggested_document_types': <String>[],
      'storage_paths': [4],
      'suggested_storage_paths': <String>[],
      'dates': ['2026-05-15'],
    });
    final api = PaperlessDocumentsApiImpl(
      Dio()..httpClientAdapter = adapter,
      apiVersion: 10,
    );

    final suggestions = await api.findAiSuggestions(99);

    expect(adapter.request!.method, 'GET');
    expect(adapter.request!.path, '/api/documents/99/ai_suggestions/');
    expect(suggestions.documentId, 99);
    expect(suggestions.title, 'AI title');
    expect(suggestions.storagePaths, [4]);
    expect(suggestions.suggestedTags, ['new-tag']);
  });

  test('streamChat posts prompt to chat endpoint', () async {
    final adapter = _JsonResponseAdapter(
      'Answer\n\n__PAPERLESS_CHAT_METADATA__{"references":[{"id":5,"title":"Doc"}]}',
      contentType: Headers.textPlainContentType,
    );
    final api = PaperlessDocumentsApiImpl(
      Dio()..httpClientAdapter = adapter,
      apiVersion: 10,
    );

    final responses = await api
        .streamChat(documentId: 5, prompt: 'Summarize')
        .toList();

    expect(adapter.request!.method, 'POST');
    expect(adapter.request!.path, '/api/documents/chat/');
    expect(jsonDecode(adapter.requestBody!), {
      'document_id': 5,
      'q': 'Summarize',
    });
    expect(responses.last.content, 'Answer');
    expect(responses.last.references.single.id, 5);
  });
}

class _JsonResponseAdapter implements HttpClientAdapter {
  final Object? body;
  final String contentType;
  RequestOptions? request;
  String? requestBody;

  _JsonResponseAdapter(this.body, {this.contentType = Headers.jsonContentType});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      requestBody = utf8.decode(bytes);
    }
    final responseBody = body is String ? body as String : jsonEncode(body);
    return ResponseBody.fromString(
      responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }
}
