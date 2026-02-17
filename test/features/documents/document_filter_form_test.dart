import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/features/documents/view/widgets/search/document_filter_form.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeLabelsApi extends Fake implements PaperlessLabelsApi {}

class _FakeCustomFieldsApi extends Fake implements CustomFieldsApi {
  @override
  Future<List<CustomFieldModel>> getCustomFields() async => [];
}

void main() {
  Future<GlobalKey<FormBuilderState>> pumpFilterForm(
    WidgetTester tester, {
    DocumentFilter initialFilter = DocumentFilter.initial,
    Map<int, CustomFieldModel> customFields = const {},
  }) async {
    final labels = LabelRepository(_FakeLabelsApi());
    final customFieldRepository = CustomFieldRepository(_FakeCustomFieldsApi());
    customFieldRepository.customFields = customFields;
    final account = LocalUserAccount(
      id: '1',
      serverUrl: 'https://example.com',
      settings: LocalUserSettings(),
      paperlessUser: const UserModelV2(id: 1, username: 'tester'),
      apiVersion: 2,
    );
    final formKey = GlobalKey<FormBuilderState>();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalUserAccount>.value(value: account),
          ChangeNotifierProvider<LabelRepository>.value(value: labels),
          ChangeNotifierProvider<CustomFieldRepository>.value(
            value: customFieldRepository,
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
            body: DocumentFilterForm(
              formKey: formKey,
              initialFilter: initialFilter,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return formKey;
  }

  testWidgets('custom field query rejects invalid json', (tester) async {
    final formKey = await pumpFilterForm(tester);
    final field =
        formKey.currentState!.fields[DocumentFilterForm.fkCustomFieldQuery]!;
    field.didChange('{"operator":"and"');

    expect(formKey.currentState!.saveAndValidate(), isFalse);

    final context = tester.element(find.byType(DocumentFilterForm));
    expect(field.errorText, S.of(context)!.enterCustomFieldValue);
  });

  testWidgets('custom field query accepts valid json and preserves value', (
    tester,
  ) async {
    final formKey = await pumpFilterForm(tester);
    const query = '{"rules":[],"operator":"and"}';
    formKey.currentState!.fields[DocumentFilterForm.fkCustomFieldQuery]!
        .didChange(query);

    expect(formKey.currentState!.saveAndValidate(), isTrue);

    final filter = DocumentFilterForm.assembleFilter(
      formKey,
      DocumentFilter.initial,
    );
    expect(filter.customFieldQuery, '{"operator":"and","rules":[]}');
  });

  testWidgets('custom field query allows whitespace-only and maps to null', (
    tester,
  ) async {
    final formKey = await pumpFilterForm(tester);
    formKey.currentState!.fields[DocumentFilterForm.fkCustomFieldQuery]!
        .didChange('   ');

    expect(formKey.currentState!.saveAndValidate(), isTrue);

    final filter = DocumentFilterForm.assembleFilter(
      formKey,
      DocumentFilter.initial,
    );
    expect(filter.customFieldQuery, isNull);
  });

  testWidgets('custom field date queries serialize as date strings', (
    tester,
  ) async {
    final dateField = CustomFieldModel(
      id: 3,
      name: 'document date',
      dataType: CustomFieldDataType.date,
    );
    final formKey = await pumpFilterForm(
      tester,
      customFields: {dateField.id!: dateField},
    );
    final queryField =
        formKey.currentState!.fields[DocumentFilterForm.fkCustomFieldQuery]!;

    await tester.tap(find.byIcon(Icons.edit_note_outlined));
    await tester.pumpAndSettle();

    final valueField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(valueField, findsOneWidget);
    await tester.enterText(valueField, '2026-02-16T00:00:00+00:00');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final value = queryField.value as String?;
    expect(value, isNotNull);
    final parsed = jsonDecode(value!);
    expect(
      parsed,
      equals([
        'and',
        [
          [3, 'exact', '2026-02-16'],
        ],
      ]),
    );
  });

  testWidgets('custom field list operators support document link contains', (
    tester,
  ) async {
    final documentLinkField = CustomFieldModel(
      id: 4,
      name: 'document links',
      dataType: CustomFieldDataType.documentLink,
    );
    final formKey = await pumpFilterForm(
      tester,
      initialFilter: const DocumentFilter(
        customFieldQuery: '["and", [[4, "contains", []]]]',
      ),
      customFields: {documentLinkField.id!: documentLinkField},
    );
    final queryField =
        formKey.currentState!.fields[DocumentFilterForm.fkCustomFieldQuery]!;

    await tester.tap(find.byIcon(Icons.edit_note_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final value = queryField.value as String?;
    expect(value, isNotNull);
    final parsed = jsonDecode(value!);
    expect(
      parsed,
      equals([
        'and',
        [
          [4, 'contains', []],
        ],
      ]),
    );
  });

  testWidgets('custom field date modifiers parse and preserve', (tester) async {
    final dateField = CustomFieldModel(
      id: 5,
      name: 'document date',
      dataType: CustomFieldDataType.date,
    );
    final formKey = await pumpFilterForm(
      tester,
      initialFilter: const DocumentFilter(
        customFieldQuery: '["and", [[5, "year__gte", 2026]]]',
      ),
      customFields: {dateField.id!: dateField},
    );
    final queryField =
        formKey.currentState!.fields[DocumentFilterForm.fkCustomFieldQuery]!;

    await tester.tap(find.byIcon(Icons.edit_note_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final value = queryField.value as String?;
    expect(value, isNotNull);
    final parsed = jsonDecode(value!);
    expect(
      parsed,
      equals([
        'and',
        [
          [5, 'year__gte', 2026],
        ],
      ]),
    );
  });

  testWidgets('custom field query parses field names from JSON object form', (
    tester,
  ) async {
    final customerField = CustomFieldModel(
      id: 7,
      name: 'Customer',
      dataType: CustomFieldDataType.string,
    );
    final formKey = await pumpFilterForm(
      tester,
      initialFilter: const DocumentFilter(
        customFieldQuery:
            '{"operator":"and","rules":[["Customer", "exact", "Acme"]]}',
      ),
      customFields: {customerField.id!: customerField},
    );
    final queryField =
        formKey.currentState!.fields[DocumentFilterForm.fkCustomFieldQuery]!;

    await tester.tap(find.byIcon(Icons.edit_note_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final value = queryField.value as String?;
    expect(value, isNotNull);
    final parsed = jsonDecode(value!);
    expect(
      parsed,
      equals([
        'and',
        [
          [7, 'exact', 'Acme'],
        ],
      ]),
    );
  });

  testWidgets('custom field query parses and preserves NOT expressions', (
    tester,
  ) async {
    final field = CustomFieldModel(
      id: 8,
      name: 'Status',
      dataType: CustomFieldDataType.string,
    );
    final formKey = await pumpFilterForm(
      tester,
      initialFilter: const DocumentFilter(
        customFieldQuery: '["not", [8, "exact", "Archived"]]',
      ),
      customFields: {field.id!: field},
    );
    final queryField =
        formKey.currentState!.fields[DocumentFilterForm.fkCustomFieldQuery]!;

    await tester.tap(find.byIcon(Icons.edit_note_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final value = queryField.value as String?;
    expect(value, isNotNull);
    final parsed = jsonDecode(value!);
    expect(
      parsed,
      equals([
        'not',
        [8, 'exact', 'Archived'],
      ]),
    );
  });

  testWidgets('custom field query parses map syntax with logic keys', (
    tester,
  ) async {
    final field = CustomFieldModel(
      id: 9,
      name: 'Status',
      dataType: CustomFieldDataType.string,
    );
    final formKey = await pumpFilterForm(
      tester,
      initialFilter: const DocumentFilter(
        customFieldQuery: '{"and":[[9,"exact","Archived"]]}',
      ),
      customFields: {field.id!: field},
    );
    final queryField =
        formKey.currentState!.fields[DocumentFilterForm.fkCustomFieldQuery]!;

    await tester.tap(find.byIcon(Icons.edit_note_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final value = queryField.value as String?;
    expect(value, isNotNull);
    final parsed = jsonDecode(value!);
    expect(
      parsed,
      equals([
        'and',
        [
          [9, 'exact', 'Archived'],
        ],
      ]),
    );
  });
}
