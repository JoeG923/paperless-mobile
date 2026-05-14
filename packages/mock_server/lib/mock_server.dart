export 'response_delay_factory.dart';

import 'dart:convert';
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

  late shelf_router.Router app;
  Future<Map<String, dynamic>> loadFixture(String name) async {
    var fixture =
        await rootBundle.loadString('packages/mock_server/fixtures/$name.json');
    return json.decode(fixture);
  }

  LocalMockApiServer(
      [this._delayGenerator = const ZeroResponseDelayFactory()]) {
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

    app.get('/api/ui_settings/', (Request req) async {
      log.info('Responding to /api/ui_settings/');
      var data = await loadFixture('ui_settings');
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

    app.get('/api/documents/<docId>/thumb/', (Request req, String docId) async {
      log.info('Responding to /api/documents/<docId>/thumb/');
      var thumb = await rootBundle
          .load('packages/mock_server/fixtures/lorem-ipsum.png');
      try {
        var resp = Response.ok(
          http.ByteStream.fromBytes(thumb.buffer.asInt8List()),
          headers: {'Content-Type': 'image/png'},
        );
        return resp;
      } catch (e) {
        return null;
      }
    });

    app.get('/api/documents/<docId>/metadata/',
        (Request req, String docId) async {
      log.info('Responding to /api/documents/<docId>/metadata/');
      var data = await loadFixture('metadata');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
    });

    //This is not yet used in the app
    app.get('/api/documents/<docId>/suggestions/',
        (Request req, String docId) async {
      log.info('Responding to /api/documents/<docId>/suggestions/');
      var data = await loadFixture('suggestions');
      return JsonMockResponse.ok(data, _delayGenerator.nextDelay());
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
        'version': 'v1.14.5',
        'update_available': false,
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

    var server = await shelf_io.serve(handler, host, port);

    server.autoCompress = true;

    log.info('serving on: $baseUrl');
  }
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
