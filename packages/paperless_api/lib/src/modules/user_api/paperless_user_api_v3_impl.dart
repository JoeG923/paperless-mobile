import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_api/src/extensions/dio_exception_extension.dart';

class PaperlessUserApiV3Impl implements PaperlessUserApi, PaperlessUserApiV3 {
  final Dio dio;

  PaperlessUserApiV3Impl(this.dio);

  @override
  Future<UserModelV3> find(int id) async {
    try {
      final response = await dio.get(
        "/api/users/$id/",
        options: Options(validateStatus: (status) => status == 200),
      );
      return UserModelV3.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.userNotFound),
      );
    }
  }

  @override
  Future<Iterable<UserModelV3>> findWhere({
    String startsWith = '',
    String endsWith = '',
    String contains = '',
    String username = '',
  }) async {
    try {
      final response = await dio.get(
        "/api/users/",
        queryParameters: {
          "username__istartswith": startsWith,
          "username__iendswith": endsWith,
          "username__icontains": contains,
          "username__iexact": username,
        },
        options: Options(validateStatus: (status) => status == 200),
      );
      return PagedSearchResult<UserModelV3>.fromJson(
        response.data,
        UserModelV3.fromJson as UserModelV3 Function(Object?),
      ).results;
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.userNotFound),
      );
    }
  }

  @override
  Future<int> findCurrentUserId() async {
    try {
      final response = await dio.get(
        "/api/ui_settings/",
        options: Options(validateStatus: (status) => status == 200),
      );
      return response.data['user']['id'];
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.userNotFound),
      );
    }
  }

  @override
  Future<Iterable<UserModelV3>> findAll() async {
    try {
      final response = await dio.get(
        "/api/users/",
        options: Options(validateStatus: (status) => status == 200),
      );
      return PagedSearchResult<UserModelV3>.fromJson(
        response.data,
        (json) => UserModelV3.fromJson(json as dynamic),
      ).results;
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.userNotFound),
      );
    }
  }

  @override
  Future<UserModel> findCurrentUser() async {
    final id = await findCurrentUserId();
    try {
      final response = await dio.get(
        "/api/users/$id/",
        options: Options(validateStatus: (status) => status == 200),
      );
      return UserModelV3.fromJson(response.data);
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 403) {
        return _findCurrentUserFromUiSettings();
      }
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.userNotFound),
      );
    }
  }

  Future<UserModelV3> _findCurrentUserFromUiSettings() async {
    final response = await dio.get(
      "/api/ui_settings/",
      options: Options(validateStatus: (status) => status == 200),
    );
    final data = response.data as Map<String, dynamic>;
    final user = Map<String, dynamic>.from(
      data['user'] as Map<dynamic, dynamic>,
    );
    final permissions =
        (data['permissions'] as List<dynamic>?)
            ?.map((permission) => permission.toString())
            .toList() ??
        const <String>[];
    final groups =
        (user['groups'] as List<dynamic>?)
            ?.map((group) => group as int)
            .toList() ??
        const <int>[];

    return UserModelV3(
      id: user['id'] as int,
      username: user['username'] as String,
      email: user['email'] as String?,
      firstName: user['first_name'] as String?,
      lastName: user['last_name'] as String?,
      dateJoined: user['date_joined'] == null
          ? null
          : DateTime.tryParse(user['date_joined'] as String),
      isStaff: user['is_staff'] as bool? ?? false,
      isActive: user['is_active'] as bool? ?? true,
      isSuperuser: user['is_superuser'] as bool? ?? false,
      groups: groups,
      userPermissions: permissions,
      inheritedPermissions: const <String>[],
    );
  }
}
