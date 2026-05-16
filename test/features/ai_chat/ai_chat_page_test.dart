import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/ai/model/ai_feature_status.dart';
import 'package:paperless_mobile/features/ai_chat/view/ai_chat_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('sends a document-scoped prompt and renders references', (
    tester,
  ) async {
    final adapter = _ChatAdapter(
      'Answer text\n\n'
      '__PAPERLESS_CHAT_METADATA__'
      '{"references":[{"id":12,"title":"Invoice"}]}',
    );
    final api = PaperlessDocumentsApiImpl(
      Dio()..httpClientAdapter = adapter,
      apiVersion: 10,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PaperlessDocumentsApi>.value(value: api),
          Provider<AiFeatureStatus>.value(
            value: const AiFeatureStatus(enabled: true),
          ),
        ],
        child: const MaterialApp(
          home: AiChatPage(
            documentId: 12,
            title: 'Ask this document',
            scopeLabel: 'Invoice',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Summarize');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(adapter.requestBody, contains('"document_id":12'));
    expect(adapter.requestBody, contains('"q":"Summarize"'));
    expect(find.text('Answer text'), findsOneWidget);
    expect(find.text('References'), findsOneWidget);
    expect(find.text('Invoice'), findsWidgets);
  });
}

class _ChatAdapter implements HttpClientAdapter {
  final String response;
  String? requestBody;

  _ChatAdapter(this.response);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    requestBody = utf8.decode(bytes);
    return ResponseBody.fromString(
      response,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }
}
