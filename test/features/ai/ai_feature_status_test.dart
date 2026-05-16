import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/ai/model/ai_feature_status.dart';

void main() {
  test('disables AI for API v9 without probing v3 endpoints', () async {
    final adapter = _StatusAdapter();
    final status = await AiFeatureStatus.load(
      serverStatsApi: PaperlessServerStatsApiImpl(
        Dio()..httpClientAdapter = adapter,
      ),
      apiVersion: 9,
    );

    expect(status.enabled, isFalse);
    expect(adapter.paths, isEmpty);
  });

  test('disables AI when v3 ui settings report ai_enabled false', () async {
    final adapter = _StatusAdapter(aiEnabled: false);
    final status = await AiFeatureStatus.load(
      serverStatsApi: PaperlessServerStatsApiImpl(
        Dio()..httpClientAdapter = adapter,
      ),
      apiVersion: 10,
    );

    expect(status.enabled, isFalse);
    expect(adapter.paths, ['/api/ui_settings/']);
  });

  test(
    'enables AI and carries LLM index status when server AI is enabled',
    () async {
      final adapter = _StatusAdapter(aiEnabled: true);
      final status = await AiFeatureStatus.load(
        serverStatsApi: PaperlessServerStatsApiImpl(
          Dio()..httpClientAdapter = adapter,
        ),
        apiVersion: 10,
      );

      expect(status.enabled, isTrue);
      expect(status.llmIndexStatus, SystemStatusItemStatus.warning);
      expect(status.llmIndexError, 'Index stale');
    },
  );
}

class _StatusAdapter implements HttpClientAdapter {
  final bool aiEnabled;
  final List<String> paths = [];

  _StatusAdapter({this.aiEnabled = true});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final body = switch (options.path) {
      '/api/ui_settings/' => {
        'display_name': 'paperless',
        'settings': {'ai_enabled': aiEnabled},
      },
      '/api/status/' => {
        'tasks': {
          'llmindex_status': 'WARNING',
          'llmindex_last_modified': '2026-05-15T00:00:00Z',
          'llmindex_error': 'Index stale',
        },
      },
      _ => throw StateError('Unexpected request ${options.path}'),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
