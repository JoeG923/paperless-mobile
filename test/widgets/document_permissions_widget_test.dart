import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_api/src/models/permissions/users_and_groups_permissions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:paperless_mobile/core/repository/group_repository.dart';
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

class FakeGroupsApi implements PaperlessGroupsApi {
  @override
  Future<Iterable<GroupModel>> findAll() async => const [];

  @override
  Future<GroupModel> find(int id) {
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

class TestGroupRepository extends GroupRepository {
  TestGroupRepository() : super(FakeGroupsApi());

  void seed(Map<int, GroupModel> groups) {
    emit(state.copyWith(groups: groups));
  }

  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets(
    'DocumentPermissionsWidget shows explicit permissions empty message',
    (WidgetTester tester) async {
      final userRepo = TestUserRepository();
      final groupRepo = TestGroupRepository();
      userRepo.seed({
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
        MultiProvider(
          providers: [
            BlocProvider<UserRepository>.value(value: userRepo),
            BlocProvider<GroupRepository>.value(value: groupRepo),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: CustomScrollView(
                slivers: [DocumentPermissionsWidget(document: document)],
              ),
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

  testWidgets(
    'DocumentPermissionsWidget shows manage permissions button for editable documents',
    (WidgetTester tester) async {
      final userRepo = TestUserRepository();
      final groupRepo = TestGroupRepository();
      userRepo.seed({
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
      final l10n = await S.delegate.load(const Locale('en'));

      final document = DocumentModel(
        id: 2,
        title: 'Editable Document',
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
        owner: 1,
        userCanChange: true,
        permissions: const Permissions(
          view: UsersAndGroupsPermissions(users: [1]),
          change: UsersAndGroupsPermissions(groups: [2]),
        ),
        customFields: const [],
        notes: const [],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            BlocProvider<UserRepository>.value(value: userRepo),
            BlocProvider<GroupRepository>.value(value: groupRepo),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  DocumentPermissionsWidget(
                    document: document,
                    onUpdatePermissions: (update) async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify owner is displayed correctly (resolved via user repo)
      expect(find.textContaining('alice'), findsWidgets);
      // Verify manage permissions button is present
      expect(find.text(l10n.managePermissions), findsOneWidget);
      // Verify view users section is shown
      expect(find.text(l10n.permissionViewUsers), findsOneWidget);
    },
  );
}
