import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';
import 'package:paperless_mobile/core/interceptor/api_version_interceptor.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('api-version-interceptor-');
    Hive.init(tempDir.path);
    registerHiveAdapters();
  });

  setUp(() async {
    await Hive.openBox<GlobalSettings>(HiveBoxes.globalSettings);
    await Hive.openBox<LocalUserAccount>(HiveBoxes.localUserAccount);
    await Hive.box<GlobalSettings>(HiveBoxes.globalSettings).clear();
    await Hive.box<LocalUserAccount>(HiveBoxes.localUserAccount).clear();
  });

  tearDown(() async {
    await Hive.close();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('uses the default account API version without override', () async {
    await _storeAccount(apiVersion: 9, serverApiVersion: 10);
    final request = await _recordRequest();

    expect(
      request.headers[Headers.acceptHeader],
      'application/json; version=9',
    );
  });

  test('uses explicit API v10 override when the server supports it', () async {
    await _storeAccount(apiVersion: 9, serverApiVersion: 10);
    final request = await _recordRequest(extra: paperlessApiVersionExtra(10));

    expect(
      request.headers[Headers.acceptHeader],
      'application/json; version=10',
    );
  });

  test('clamps explicit API v10 override to server API v9', () async {
    await _storeAccount(apiVersion: 9, serverApiVersion: 9);
    final request = await _recordRequest(extra: paperlessApiVersionExtra(10));

    expect(
      request.headers[Headers.acceptHeader],
      'application/json; version=9',
    );
  });

  test('clamps requests above the client support ceiling', () async {
    await _storeAccount(apiVersion: 9, serverApiVersion: 12);
    final request = await _recordRequest(extra: paperlessApiVersionExtra(12));

    expect(
      request.headers[Headers.acceptHeader],
      'application/json; version=10',
    );
  });

  test('does not overwrite an explicit Accept header', () async {
    await _storeAccount(apiVersion: 9, serverApiVersion: 10);
    final request = await _recordRequest(
      headers: {Headers.acceptHeader: 'application/problem+json'},
      extra: paperlessApiVersionExtra(10),
    );

    expect(request.headers[Headers.acceptHeader], 'application/problem+json');
  });

  test(
    'stores the raw server API version and default request version',
    () async {
      await _storeAccount(apiVersion: 9, serverApiVersion: 9);
      await _recordRequest(responseApiVersion: 10);

      final account = Hive.box<LocalUserAccount>(
        HiveBoxes.localUserAccount,
      ).get(_accountId)!;

      expect(account.serverApiVersion, 10);
      expect(account.apiVersion, 9);
    },
  );
}

const _accountId = 'account-1';

Future<void> _storeAccount({
  required int apiVersion,
  required int serverApiVersion,
}) async {
  await Hive.box<GlobalSettings>(HiveBoxes.globalSettings).setValue(
    GlobalSettings(preferredLocaleSubtag: 'en', loggedInUserId: _accountId),
  );
  await Hive.box<LocalUserAccount>(HiveBoxes.localUserAccount).put(
    _accountId,
    LocalUserAccount(
      id: _accountId,
      serverUrl: 'https://paperless.example',
      settings: LocalUserSettings(),
      paperlessUser: const UserModelV3(
        id: 1,
        username: 'tester',
        isStaff: false,
        isActive: true,
        isSuperuser: false,
        groups: [],
        userPermissions: [],
        inheritedPermissions: [],
      ),
      apiVersion: apiVersion,
      serverApiVersion: serverApiVersion,
    ),
  );
}

Future<RequestOptions> _recordRequest({
  Map<String, Object?>? extra,
  Map<String, Object?>? headers,
  int? responseApiVersion,
}) async {
  final adapter = _RecordingAdapter(responseApiVersion: responseApiVersion);
  final dio = Dio()
    ..interceptors.add(ApiVersionInterceptor())
    ..httpClientAdapter = adapter;

  await dio.get<void>(
    '/api/documents/',
    options: Options(extra: extra, headers: headers),
  );
  return adapter.request!;
}

class _RecordingAdapter implements HttpClientAdapter {
  final int? responseApiVersion;
  RequestOptions? request;

  _RecordingAdapter({required this.responseApiVersion});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '',
      200,
      headers: {
        if (responseApiVersion != null)
          PaperlessServerInformationModel.apiVersionHeader: [
            responseApiVersion.toString(),
          ],
      },
    );
  }
}
