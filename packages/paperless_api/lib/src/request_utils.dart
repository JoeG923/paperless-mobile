import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:paperless_api/src/extensions/dio_exception_extension.dart';
import 'package:paperless_api/src/models/paperless_api_exception.dart';

Future<T?> getSingleResult<T>(
  String url,
  T Function(Map<String, dynamic>) fromJson,
  ErrorCode errorCode, {
  required Dio client,
  int minRequiredApiVersion = 1,
}) async {
  try {
    final response = await client.get(
      url,
      options: Options(
        headers: {'accept': 'application/json; version=$minRequiredApiVersion'},
        validateStatus: (status) => status == 200,
      ),
    );
    return compute(fromJson, response.data as Map<String, dynamic>);
  } on DioException catch (exception) {
    throw exception.unravel(orElse: PaperlessApiException(errorCode));
  }
}

Future<List<T>> getCollection<T>(
  String url,
  T Function(Map<String, dynamic>) fromJson,
  ErrorCode errorCode, {
  required Dio client,
  int minRequiredApiVersion = 1,
}) async {
  try {
    final response = await client.get(
      url,
      options: Options(
        headers: {'accept': 'application/json; version=$minRequiredApiVersion'},
        validateStatus: (status) => status == 200,
      ),
    );
    final Map<String, dynamic> body = response.data;
    if (body['count'] == 0) {
      return <T>[];
    } else {
      return compute(
        _collectionFromJson,
        _CollectionFromJsonSerializationParams(
          fromJson,
          (body['results'] as List).cast<Map<String, dynamic>>(),
        ),
      );
    }
  } on DioException catch (exception) {
    throw exception.unravel(orElse: PaperlessApiException(errorCode));
  }
}

List<T> _collectionFromJson<T>(
  _CollectionFromJsonSerializationParams<T> params,
) {
  return params.list.map<T>((result) => params.fromJson(result)).toList();
}

class _CollectionFromJsonSerializationParams<T> {
  final T Function(Map<String, dynamic>) fromJson;
  final List<Map<String, dynamic>> list;

  _CollectionFromJsonSerializationParams(this.fromJson, this.list);
}

int getExtendedVersionNumber(String version) {
  List versionCells = version.split('.');
  versionCells = versionCells.map((i) => int.parse(i)).toList();
  return versionCells[0] * 100000 + versionCells[1] * 1000 + versionCells[2];
}

int? tryParseNullable(String? source, {int? radix}) {
  if (source == null) return null;
  return int.tryParse(source, radix: radix);
}
