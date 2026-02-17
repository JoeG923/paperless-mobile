import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_api/src/extensions/dio_exception_extension.dart';

class PaperlessGroupsApiImpl implements PaperlessGroupsApi {
  final Dio dio;

  PaperlessGroupsApiImpl(this.dio);

  @override
  Future<Iterable<GroupModel>> findAll() async {
    try {
      final response = await dio.get(
        "/api/groups/",
        options: Options(validateStatus: (status) => status == 200),
      );
      return PagedSearchResult<GroupModel>.fromJson(
        response.data,
        (json) => GroupModel.fromJson(json as Map<String, dynamic>),
      ).results;
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.unknown),
      );
    }
  }

  @override
  Future<GroupModel> find(int id) async {
    try {
      final response = await dio.get(
        "/api/groups/$id/",
        options: Options(validateStatus: (status) => status == 200),
      );
      return GroupModel.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.unknown),
      );
    }
  }
}
