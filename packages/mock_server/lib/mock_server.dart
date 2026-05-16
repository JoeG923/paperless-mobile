export 'response_delay_factory.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mock_server/english_words.dart';
import 'package:mock_server/response_delay_factory.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:flutter/services.dart' show rootBundle;

Logger log = Logger('LocalMockApiServer');

class LocalMockApiServer {
  static const host = 'localhost';

  static const port = 3131;

  static String get baseUrl => 'http://$host:$port/';

  final ResponseDelayFactory _delayGenerator;
  final int apiVersion;
  final bool aiEnabled;
  final bool useBuiltInFixturesOnly;
  final String _host;
  final int _port;
  HttpServer? _server;

  String get serverUrl => 'http://$_host:${_server?.port ?? _port}/';

  late shelf_router.Router app;
  Future<Map<String, dynamic>> loadFixture(String name) async {
    if (useBuiltInFixturesOnly) {
      return _builtInFixture(name);
    }
    try {
      var fixture = await rootBundle.loadString(
        'packages/mock_server/fixtures/$name.json',
      );
      return json.decode(fixture);
    } catch (_) {
      return _builtInFixture(name);
    }
  }

  LocalMockApiServer({
    ResponseDelayFactory delayGenerator = const ZeroResponseDelayFactory(),
    this.apiVersion = 9,
    this.aiEnabled = false,
    this.useBuiltInFixturesOnly = false,
    String host = LocalMockApiServer.host,
    int port = LocalMockApiServer.port,
  })  : _delayGenerator = delayGenerator,
        _host = host,
        _port = port {
    app = shelf_router.Router();

    Map<String, dynamic> createdTags = {};

    app.get('/api/', (Request req) async {
      log.info('Responding to /api');
      return JsonMockResponse.ok({}, _delayGenerator.nextDelay());
    });

    app.post('/api/token/', (Request req) async {
      log.info('Responding to /api/token/');
      var body = await req.bodyJsonMap();
      if (body?['username'] == 'admin' && body?['password'] == 'test') {
        return JsonMockResponse.ok(
            {'token': 'testToken'}, _delayGenerator.nextDelay());
      } else {
        return Response.unauthorized('Unauthorized');
      }
    });

    app.get('/api/profile/', (Request req) async {
      log.info('Responding to /api/profile/');
      return Response.ok(
        '{}',
        headers: {
          'Content-Type': 'application/json',
          'x-api-version': apiVersion.toString(),
          'x-version': apiVersion >= 10 ? '3.0.0-beta' : '2.9.0',
        },
      );
    });

    app.get('/api/ui_settings/', (Request req) async {
      log.info('Responding to /api/ui_settings/');
      var data = await loadFixture('ui_settings');
      data['settings'] = {
        ...((data['settings'] as Map?) ?? const {}),
        'ai_enabled': aiEnabled,
      };
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/users/<userId>/', (Request req, String userId) async {
      log.info('Responding to /api/users/<userId>/');
      var data = await loadFixture('user-1');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/users/', (Request req, String userId) async {
      log.info('Responding to /api/users/');
      var data = await loadFixture('users');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/groups/', (Request req, String userId) async {
      log.info('Responding to /api/groups/');
      var data = await loadFixture('groups');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/correspondents/', (Request req) async {
      log.info('Responding to /api/correspondents/');
      var data = await loadFixture('correspondents');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/document_types/', (Request req) async {
      log.info('Responding to /api/document_types/');
      var data = await loadFixture('doc_types');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/tags/', (Request req) async {
      log.info('Responding to /api/tags/');
      if (createdTags.isEmpty) {
        var data = await loadFixture("tags");
        createdTags = data;
      }
      return JsonMockResponse.ok(createdTags, _delayGenerator.nextDelay());
    });

    app.post('/api/tags/', (Request req) async {
      log.info('Responding to POST /api/tags/');
      var body = await req.bodyJsonMap();
      var data = {
        "id": Random().nextInt(200),
        "slug": body?['name'],
        "name": body?['name'],
        "color": body?['color'],
        "text_color": "#000000",
        "match": body?['match'],
        "matching_algorithm": body?['matching_algorithm'],
        "is_insensitive": body?['is_insensitive'],
        "is_inbox_tag": false,
        "owner": 1,
        "user_can_change": true,
        "document_count": Random().nextInt(200)
      };
      (createdTags['results'] as List<dynamic>).add(data);
      return Response(201,
          body: jsonEncode(data),
          headers: {'Content-Type': 'application/json'},
          encoding: null,
          context: null);
    });

    app.put('/api/tags/<tagId>/', (Request req, String tagId) async {
      log.info('Responding to PUT /api/tags/<tagId>/');
      var body = await req.bodyJsonMap();
      var data = {
        "id": body?['id'],
        "slug": body?['name'],
        "name": body?['name'],
        "color": body?['color'],
        "text_color": "#000000",
        "match": body?['match'],
        "matching_algorithm": body?['matching_algorithm'],
        "is_insensitive": body?['is_insensitive'],
        "is_inbox_tag": false,
        "owner": 1,
        "user_can_change": true,
        "document_count": Random().nextInt(200)
      };
      var index = (createdTags['results'] as List<dynamic>)
          .indexWhere((element) => element['id'] == body?['id']);
      (createdTags['results'] as List<dynamic>)[index] = data;
      return Response(200,
          body: jsonEncode(data),
          headers: {'Content-Type': 'application/json'},
          encoding: null,
          context: null);
    });

    app.delete('/api/tags/<tagId>/', (Request req, String tagId) async {
      log.info('Responding to PUT /api/tags/<tagId>/');
      (createdTags['results'] as List<dynamic>)
          .removeWhere((element) => element['id'] == tagId);
      return Response(204,
          body: null,
          headers: {'Content-Type': 'application/json'},
          encoding: null,
          context: null);
    });

    app.get('/api/storage_paths/', (Request req) async {
      log.info('Responding to /api/storage_paths/');
      var data = await loadFixture('storage_paths');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/storage_paths/', (Request req) async {
      log.info('Responding to /api/storage_paths/');
      var data = await loadFixture('storage_paths');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/saved_views/', (Request req) async {
      log.info('Responding to /api/saved_views/');
      var data = await loadFixture('saved_views');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/documents/', (Request req) async {
      log.info('Responding to /api/documents/');
      var data = await loadFixture('documents');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/documents/<docId>/', (Request req, String docId) async {
      log.info('Responding to /api/documents/<docId>/');
      var data = await loadFixture('documents');
      final documents = data['results'] as List<dynamic>;
      final document = documents.cast<Map<String, dynamic>>().firstWhere(
            (item) => item['id'].toString() == docId,
            orElse: () => throw StateError('Document $docId not found'),
          );
      return JsonMockResponse.ok(document, _delayGenerator.nextDelay());
    });

    app.get('/api/documents/<docId>/thumb/', (Request req, String docId) async {
      log.info('Responding to /api/documents/<docId>/thumb/');
      List<int> bytes;
      try {
        var thumb = await rootBundle.load(
          'packages/mock_server/fixtures/lorem-ipsum.png',
        );
        bytes = thumb.buffer.asUint8List();
      } catch (e) {
        bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
        );
      }
      return Response.ok(
        http.ByteStream.fromBytes(bytes),
        headers: {'Content-Type': 'image/png'},
      );
    });

    app.get('/api/documents/<docId>/metadata/',
        (Request req, String docId) async {
      log.info('Responding to /api/documents/<docId>/metadata/');
      var data = await loadFixture('metadata');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/documents/<docId>/suggestions/',
        (Request req, String docId) async {
      log.info('Responding to /api/documents/<docId>/suggestions/');
      var data = await loadFixture('suggestions');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/documents/<docId>/ai_suggestions/',
        (Request req, String docId) async {
      log.info('Responding to /api/documents/<docId>/ai_suggestions/');
      return JsonMockResponse.ok({
        'title': 'AI suggested title',
        'correspondents': [9],
        'document_types': [1],
        'storage_paths': [2],
        'tags': [4],
        'suggested_correspondents': ['New correspondent'],
        'suggested_document_types': ['New document type'],
        'suggested_storage_paths': ['New storage path'],
        'suggested_tags': ['New tag'],
      }, _delayGenerator.nextDelay());
    });

    app.post('/api/documents/chat/', (Request req) async {
      log.info('Responding to /api/documents/chat/');
      await req.readAsString();
      await Future.delayed(_delayGenerator.nextDelay());
      return Response.ok(
        'Mock answer about your documents.\n\n'
        '__PAPERLESS_CHAT_METADATA__'
        '{"references":[{"id":1,"title":"No latin title"}]}',
        headers: {'Content-Type': 'text/plain'},
      );
    });

    //This is not yet used in the app
    app.get('/api/documents/<docId>/notes/', (Request req, String docId) async {
      log.info('Responding to /api/documents/<docId>/notes/');
      var data = await loadFixture('notes');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/tasks/', (Request req) async {
      log.info('Responding to /api/tasks/');
      var data = await loadFixture('tasks');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/statistics/', (Request req) async {
      log.info('Responding to /api/statistics/');
      var data = await loadFixture('statistics');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/statistics/', (Request req) async {
      log.info('Responding to /api/statistics/');
      var data = await loadFixture('statistics');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    app.get('/api/search/autocomplete/', (Request req) async {
      log.info("Responding to /api/search/autocomplete");
      final term = req.url.queryParameters["term"] ?? '';
      final limit = int.parse(req.url.queryParameters["limit"] ?? '5');
      return JsonMockResponse.ok(
        mostFrequentWords
            .where((element) => element.startsWith(term))
            .take(limit)
            .toList(),
        _delayGenerator.nextDelay(),
      );
    });

    app.get('/api/remote_version/', (Request req) async {
      return JsonMockResponse.ok({
        'version': apiVersion >= 10 ? 'v3.0.0-beta' : 'v2.9.0',
        'update_available': false,
      }, _delayGenerator.nextDelay());
    });

    app.get('/api/status/', (Request req) async {
      log.info('Responding to /api/status/');
      return JsonMockResponse.ok({
        'tasks': {
          'llmindex_status': 'OK',
          'llmindex_last_modified': '2026-05-15T00:00:00Z',
          'llmindex_error': null,
        },
      }, _delayGenerator.nextDelay());
    });
  }

  Future<void> start() async {
    log.info('starting...');

    var handler = const Pipeline().addMiddleware(
      logRequests(logger: (message, isError) {
        if (isError) {
          log.severe(message);
        } else {
          log.info(message);
        }
      }),
    ).addHandler(app.call);

    var server = await shelf_io.serve(handler, _host, _port);

    server.autoCompress = true;
    _server = server;

    log.info('serving on: $serverUrl');
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }
}

Map<String, dynamic> _builtInFixture(String name) {
  final document = _documentFixture();
  return switch (name) {
    'ui_settings' => _uiSettingsFixture(),
    'user-1' => _userFixture(),
    'users' => _paged([_userFixture()]),
    'groups' => _paged([]),
    'correspondents' => _paged([
        _labelFixture(id: 9, name: 'Acme Corp'),
      ]),
    'doc_types' => _paged([
        _labelFixture(id: 1, name: 'Invoice'),
      ]),
    'tags' => _paged([
        {
          ..._labelFixture(id: 4, name: 'Inbox'),
          'color': '#009688',
          'text_color': '#ffffff',
          'is_inbox_tag': true,
        },
      ]),
    'storage_paths' => _paged([
        {
          ..._labelFixture(id: 2, name: 'Archive'),
          'path': 'archive',
        },
      ]),
    'documents' => _paged([document]),
    'metadata' => {
        'original_checksum': 'checksum',
        'original_size': 128,
        'original_mime_type': 'application/pdf',
        'media_filename': 'documents/originals/no-latin-title.pdf',
        'has_archive_version': true,
        'archive_checksum': 'archive-checksum',
        'archive_size': 128,
      },
    'suggestions' => {
        'correspondents': [9],
        'document_types': [1],
        'storage_paths': [2],
        'tags': [4],
      },
    'notes' => _paged([]),
    'saved_views' => _paged([]),
    'tasks' => _paged([]),
    'statistics' => {
        'documents_total': 1,
        'documents_inbox': 1,
        'character_count': 42,
        'document_file_type_counts': [
          {'mime_type': 'application/pdf', 'mime_type_count': 1},
        ],
      },
    _ => throw StateError('No built-in fixture for $name'),
  };
}

Map<String, dynamic> _paged(List<Map<String, dynamic>> results) {
  return {
    'count': results.length,
    'next': null,
    'previous': null,
    'results': results,
  };
}

Map<String, dynamic> _labelFixture({required int id, required String name}) {
  return {
    'id': id,
    'slug': name.toLowerCase().replaceAll(' ', '-'),
    'name': name,
    'match': '',
    'matching_algorithm': 6,
    'is_insensitive': true,
    'document_count': 1,
    'owner': 1,
    'user_can_change': true,
  };
}

Map<String, dynamic> _uiSettingsFixture() {
  return {
    'user': {
      'id': 1,
      'username': 'admin',
      'is_superuser': true,
      'groups': [],
    },
    'settings': {
      'language': '',
      'bulk_edit': {
        'confirmation_dialogs': true,
        'apply_on_close': false,
      },
      'documentListSize': 50,
      'dark_mode': {
        'use_system': true,
        'enabled': 'false',
        'thumb_inverted': 'true',
      },
      'theme': {'color': '#b198e5'},
      'document_details': {'native_pdf_viewer': false},
      'date_display': {'date_locale': '', 'date_format': 'mediumDate'},
      'notifications': {
        'consumer_new_documents': true,
        'consumer_success': true,
        'consumer_failed': true,
        'consumer_suppress_on_dashboard': true,
      },
    },
    'permissions': _permissions(),
  };
}

Map<String, dynamic> _userFixture() {
  return {
    'id': 1,
    'username': 'admin',
    'email': 'admin@example.com',
    'first_name': 'Admin',
    'last_name': 'User',
    'date_joined': '2026-01-01T00:00:00Z',
    'is_staff': true,
    'is_active': true,
    'is_superuser': true,
    'groups': [],
    'user_permissions': [],
    'inherited_permissions': _permissions(),
  };
}

List<String> _permissions() {
  return const [
    'documents.view_document',
    'documents.change_document',
    'documents.add_document',
    'documents.delete_document',
    'documents.view_correspondent',
    'documents.change_correspondent',
    'documents.view_documenttype',
    'documents.change_documenttype',
    'documents.view_tag',
    'documents.change_tag',
    'documents.view_storagepath',
    'documents.change_storagepath',
    'documents.view_savedview',
    'documents.change_savedview',
    'documents.view_customfield',
    'documents.change_customfield',
  ];
}

Map<String, dynamic> _documentFixture() {
  return {
    'id': 1,
    'correspondent': 9,
    'document_type': 1,
    'storage_path': 2,
    'title': 'No latin title',
    'content': 'Test document PDF',
    'tags': [4],
    'created': '2022-03-22T07:24:18Z',
    'created_date': '2022-03-22',
    'modified': '2022-03-22T07:24:23Z',
    'added': '2022-03-22T07:24:22Z',
    'archive_serial_number': null,
    'original_file_name': '2022-03-22 no latin title.pdf',
    'archived_file_name': '2022-03-22 no latin title.pdf',
    'owner': 1,
    'user_can_change': true,
    'permissions': {
      'view': {
        'users': [],
        'groups': [],
      },
      'change': {
        'users': [],
        'groups': [],
      },
    },
    'notes': [],
    'custom_fields': [],
  };
}

extension on Request {
  Future<Map?> bodyJsonMap() async {
    return jsonDecode(await readAsString());
  }
}

extension JsonMockResponse on Response {
  static Future<Response> ok<T>(T json, Duration delay) async {
    await Future.delayed(delay); // Emulate lag

    return Response.ok(
      jsonEncode(json),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
