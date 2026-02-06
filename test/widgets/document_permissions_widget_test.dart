import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_api/src/models/permissions/users_and_groups_permissions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_mobile/core/repository/user_repository.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/document_permissions_widget.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class FakeUserApi implements PaperlessUserApi {
  @override
  Future<int> findCurrentUserId() {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> findCurrentUser() {
    throw UnimplementedError();
  }
}

class TestUserRepository extends UserRepository {
  TestUserRepository() : super(FakeUserApi());

  void seed(Map<int, UserModel> users) {
    emit(state.copyWith(users: users));
  }

  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets(
    'DocumentPermissionsWidget shows explicit permissions empty message',
    (WidgetTester tester) async {
      final repo = TestUserRepository();
      repo.seed({
        1: UserModelV3(
          id: 1,
          username: 'alice',
          email: 'alice@example.com',
          firstName: 'Alice',
          lastName: 'Example',
          dateJoined: DateTime(2024, 1, 1),
          isStaff: false,
          isActive: true,
          isSuperuser: false,
          groups: const [],
          userPermissions: const [],
          inheritedPermissions: const [],
        ),
      });

      final document = DocumentModel(
        id: 1,
        title: 'Test Document',
        content: null,
        tags: const [],
        documentType: null,
        correspondent: null,
        storagePath: null,
        created: DateTime(2024, 1, 1),
        modified: DateTime(2024, 1, 1),
        added: DateTime(2024, 1, 1),
        archiveSerialNumber: null,
        originalFileName: null,
        archivedFileName: null,
        owner: null,
        userCanChange: null,
        permissions: const Permissions(
          view: UsersAndGroupsPermissions(),
          change: UsersAndGroupsPermissions(),
        ),
        customFields: const [],
        notes: const [],
      );

      await tester.pumpWidget(
        BlocProvider<UserRepository>.value(
          value: repo,
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: CustomScrollView(
              slivers: [DocumentPermissionsWidget(document: document)],
            ),
          ),
        ),
      );

      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
      expect(
        find.text(
          'No explicit permissions set. Access is determined by global permissions or workflows.',
        ),
        findsOneWidget,
      );
    },
  );
}
