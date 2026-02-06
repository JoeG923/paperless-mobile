import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/constants.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/hive/hive_extensions.dart';

class ApiVersionInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final headers = options.headers;
    if (!headers.containsKey(Headers.acceptHeader)) {
      final apiVersion = _resolveApiVersion();
      if (apiVersion != null) {
        headers[Headers.acceptHeader] = 'application/json; version=$apiVersion';
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final headerValue = response.headers.value(
      PaperlessServerInformationModel.apiVersionHeader,
    );
    final apiVersion = int.tryParse(headerValue ?? '');
    if (apiVersion != null) {
      _updateApiVersion(apiVersion);
    }
    handler.next(response);
  }

  int? _resolveApiVersion() {
    final settings = Hive.globalSettingsBox.getValue();
    final userId = settings?.loggedInUserId;
    if (userId == null) {
      return null;
    }
    final account = Hive.localUserAccountBox.get(userId);
    if (account == null) {
      return null;
    }
    return apiVersionClamp(account.apiVersion);
  }

  void _updateApiVersion(int apiVersion) {
    final settings = Hive.globalSettingsBox.getValue();
    final userId = settings?.loggedInUserId;
    if (userId == null) {
      return;
    }
    final account = Hive.localUserAccountBox.get(userId);
    if (account == null) {
      return;
    }
    final normalized = apiVersionClamp(apiVersion);
    if (account.apiVersion == normalized) {
      return;
    }
    account.apiVersion = normalized;
    unawaited(account.save());
  }
}

int apiVersionClamp(int apiVersion) {
  if (apiVersion > latestSupportedApiVersion) {
    return latestSupportedApiVersion;
  }
  return apiVersion;
}
