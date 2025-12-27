import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('PaperlessUserApiV3Impl', () {
    test('falls back to ui_settings when /api/users/{id} is forbidden',
        () async {
      final dio = Dio();
      final adapter = DioAdapter(dio: dio);
      final api = PaperlessUserApiV3Impl(dio);

      const uiSettingsResponse = {
        'user': {
          'id': 42,
          'username': 'tester',
          'is_staff': false,
          'is_superuser': false,
          'groups': [1, 2],
          'first_name': 'Test',
          'last_name': 'User'
        },
        'settings': {},
        'permissions': ['view_document', 'view_tag']
      };

      adapter.onGet(
        '/api/ui_settings/',
        (server) => server.reply(200, uiSettingsResponse),
      );

      adapter.onGet(
        '/api/users/42/',
        (server) => server.reply(403, {'detail': 'Forbidden'}),
      );

      final result = await api.findCurrentUser();

      expect(result, isA<UserModelV3>());
      final user = result as UserModelV3;
      expect(user.id, 42);
      expect(user.username, 'tester');
      expect(user.isStaff, false);
      expect(user.isSuperuser, false);
      expect(user.groups, [1, 2]);
      expect(user.userPermissions, ['view_document', 'view_tag']);
      expect(user.fullName, 'Test User');
    });
  });
}
