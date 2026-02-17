import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';
import 'package:paperless_mobile/features/documents/view/widgets/selection/document_selection_sliver_app_bar.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeDocumentsApi extends Fake implements PaperlessDocumentsApi {
  @override
  Future<Iterable<int>> bulkAction(BulkAction action) async => [];

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(
    DocumentFilter filter,
  ) async {
    return const PagedSearchResult(results: [], count: 0);
  }
}

class _FakeCustomFieldsApi extends Fake implements CustomFieldsApi {
  @override
  Future<List<CustomFieldModel>> getCustomFields() async => [];
}

class _InMemoryLocalUserAppState extends LocalUserAppState {
  _InMemoryLocalUserAppState({required super.userId});

  @override
  Future<void> save() async {}
}

DocumentModel _document(int id) {
  final now = DateTime(2026, 1, id);
  return DocumentModel(
    id: id,
    title: 'doc-$id',
    documentType: null,
    correspondent: null,
    created: now,
    modified: now,
    added: now,
  );
}

void main() {
  testWidgets('bulk menu shows parity actions', (tester) async {
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentsCubit(
      _FakeDocumentsApi(),
      notifier,
      _InMemoryLocalUserAppState(userId: 'user-1'),
      ConnectivityStatusServiceMock(true),
    );
    final customFieldRepo = CustomFieldRepository(_FakeCustomFieldsApi());
    final state = DocumentsState(selection: [_document(1)]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          BlocProvider<DocumentsCubit>.value(value: cubit),
          ChangeNotifierProvider<CustomFieldRepository>.value(
            value: customFieldRepo,
          ),
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
              slivers: [DocumentSelectionSliverAppBar(state: state)],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Edit PDF'), findsOneWidget);
    expect(find.text('Modify custom fields'), findsOneWidget);
    expect(find.text('Set permissions'), findsOneWidget);
    expect(find.text('Remove password'), findsOneWidget);

    await cubit.close();
    notifier.close();
  });

  testWidgets('modify custom fields action shows empty-state feedback', (
    tester,
  ) async {
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentsCubit(
      _FakeDocumentsApi(),
      notifier,
      _InMemoryLocalUserAppState(userId: 'user-1'),
      ConnectivityStatusServiceMock(true),
    );
    final customFieldRepo = CustomFieldRepository(_FakeCustomFieldsApi());
    final state = DocumentsState(selection: [_document(1)]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          BlocProvider<DocumentsCubit>.value(value: cubit),
          ChangeNotifierProvider<CustomFieldRepository>.value(
            value: customFieldRepo,
          ),
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
              slivers: [DocumentSelectionSliverAppBar(state: state)],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modify custom fields'));
    await tester.pumpAndSettle();

    expect(find.text('No custom fields available.'), findsOneWidget);

    await cubit.close();
    notifier.close();
  });

  testWidgets('edit pdf action validates json operations input', (
    tester,
  ) async {
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentsCubit(
      _FakeDocumentsApi(),
      notifier,
      _InMemoryLocalUserAppState(userId: 'user-1'),
      ConnectivityStatusServiceMock(true),
    );
    final customFieldRepo = CustomFieldRepository(_FakeCustomFieldsApi());
    final state = DocumentsState(selection: [_document(1)]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          BlocProvider<DocumentsCubit>.value(value: cubit),
          ChangeNotifierProvider<CustomFieldRepository>.value(
            value: customFieldRepo,
          ),
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
              slivers: [DocumentSelectionSliverAppBar(state: state)],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Enter valid edit PDF operations JSON.'), findsOneWidget);

    await cubit.close();
    notifier.close();
  });
}
