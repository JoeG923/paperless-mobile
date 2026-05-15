import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/pop_with_unsaved_changes.dart';
import 'package:paperless_mobile/core/widgets/form_builder_fields/form_builder_localized_date_picker.dart';
import 'package:paperless_mobile/features/document_edit/cubit/document_edit_cubit.dart';
import 'package:paperless_mobile/features/document_edit/view/widgets/_form_section_card.dart';
import 'package:paperless_mobile/features/document_edit/view/widgets/_suggestion_chips_row.dart';
import 'package:paperless_mobile/features/documents/view/widgets/document_preview.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_form_field.dart';
import 'package:paperless_mobile/features/labels/view/widgets/label_form_field.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:paperless_mobile/routing/routes/labels_route.dart';
import 'package:provider/provider.dart';

class DocumentEditPage extends StatefulWidget {
  const DocumentEditPage({super.key});

  @override
  State<DocumentEditPage> createState() => _DocumentEditPageState();
}

class _DocumentEditPageState extends State<DocumentEditPage> {
  static const fkTitle = 'title';
  static const fkCorrespondent = 'correspondent';
  static const fkTags = 'tags';
  static const fkDocumentType = 'documentType';
  static const fkCreatedDate = 'createdAtDate';
  static const fkStoragePath = 'storagePath';
  static const fkContent = 'content';
  static const _fkCustomFieldPrefix = 'customField_';

  final _formKey = GlobalKey<FormBuilderState>();

  /// Mirrors the title field so the SliverAppBar headline updates live.
  final _titleNotifier = ValueNotifier<String>('');

  bool _isSaving = false;
  bool _titleInitialized = false;

  @override
  void dispose() {
    _titleNotifier.dispose();
    super.dispose();
  }

  void _initTitle(String? initialTitle) {
    if (_titleInitialized) return;
    _titleInitialized = true;
    _titleNotifier.value = initialTitle ?? '';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<LocalUserAccount>().paperlessUser;
    final customFieldRepository = Provider.of<CustomFieldRepository?>(context);
    final customFieldDefinitions =
        customFieldRepository?.customFields ?? const <int, CustomFieldModel>{};

    return BlocBuilder<DocumentEditCubit, DocumentEditState>(
      builder: (context, state) {
        _initTitle(state.document.title);
        final doc = state.document;
        final suggestions = state.suggestions;

        return PopWithUnsavedChanges(
          hasChangesPredicate: () => _hasChanges(doc, customFieldDefinitions),
          child: FormBuilder(
            key: _formKey,
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              body: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(context, doc),
                  SliverPadding(
                    padding: const EdgeInsets.only(
                      top: PmSpacing.md,
                      // Keep content above the sticky bottom bar.
                      bottom: PmSpacing.xxl + 80,
                    ),
                    sliver: SliverList.list(
                      children: _buildFormSections(
                        context,
                        state,
                        suggestions,
                        currentUser,
                        customFieldDefinitions,
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: _buildBottomBar(
                context,
                doc,
                customFieldDefinitions,
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // App bar
  // ──────────────────────────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar(BuildContext context, DocumentModel doc) {
    final scheme = Theme.of(context).colorScheme;

    return SliverAppBar.large(
      leading: const BackButton(),
      pinned: true,
      stretch: true,
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: PmSpacing.lg),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        else
          IconButton(
            tooltip: S.of(context)!.saveChanges,
            icon: const Icon(Icons.save_outlined),
            onPressed: () => _onSubmit(doc, _customFieldDefs(context)),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(
          left: PmSpacing.lg,
          bottom: PmSpacing.lg,
          right: 80,
        ),
        title: ValueListenableBuilder<String>(
          valueListenable: _titleNotifier,
          builder: (context, titleValue, _) {
            final displayTitle = titleValue.trim().isEmpty
                ? S.of(context)!.editDocument
                : titleValue;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (doc.originalFileName != null)
                  Text(
                    doc.originalFileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            );
          },
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail acts as the preview peek; tapping opens the viewer.
            DocumentPreview(
              documentId: doc.id,
              title: doc.title,
              enableHero: false,
              isClickable: true,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            // Gradient overlay so the title is legible on any thumbnail.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sticky bottom action bar
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildBottomBar(
    BuildContext context,
    DocumentModel doc,
    Map<int, CustomFieldModel> customFieldDefinitions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: PmSpacing.lg,
          vertical: PmSpacing.sm,
        ),
        child: FilledButton.icon(
          onPressed: _isSaving
              ? null
              : () => _onSubmit(doc, customFieldDefinitions),
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(S.of(context)!.saveChanges),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Form sections
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildFormSections(
    BuildContext context,
    DocumentEditState state,
    FieldSuggestions? suggestions,
    UserModel currentUser,
    Map<int, CustomFieldModel> customFieldDefinitions,
  ) {
    final labelRepository = context.watch<LabelRepository>();
    final doc = state.document;
    const gap = SizedBox(height: PmSpacing.md);

    return [
      // ── Identity ─────────────────────────────────────────────────────────
      FormSectionCard(
        title: 'Identity', // TODO(l10n)
        children: [
          _buildTitleFormField(doc.title),
          const SizedBox(height: PmSpacing.md),
          _buildCreatedAtFormField(doc.created, suggestions),
        ],
      ),
      gap,

      // ── Classification ───────────────────────────────────────────────────
      if (currentUser.canViewCorrespondents ||
          currentUser.canViewDocumentTypes ||
          currentUser.canViewStoragePaths)
        FormSectionCard(
          title: 'Classification', // TODO(l10n)
          children: [
            if (currentUser.canViewCorrespondents)
              LabelFormField<Correspondent>(
                showAnyAssignedOption: false,
                showNotAssignedOption: false,
                onAddLabel: (currentInput) => CreateLabelRoute(
                  LabelType.correspondent,
                  name: currentInput,
                ).push<Correspondent>(context),
                addLabelText: S.of(context)!.addCorrespondent,
                labelText: S.of(context)!.correspondent,
                options: labelRepository.correspondents,
                initialValue: doc.correspondent != null
                    ? SetIdQueryParameter(id: doc.correspondent!)
                    : const UnsetIdQueryParameter(),
                name: fkCorrespondent,
                prefixIcon: const Icon(Icons.person_outlined),
                allowSelectUnassigned: true,
                canCreateNewLabel: currentUser.canCreateCorrespondents,
                suggestions: suggestions?.correspondents ?? [],
              ),
            if (currentUser.canViewCorrespondents &&
                currentUser.canViewDocumentTypes)
              const SizedBox(height: PmSpacing.md),
            if (currentUser.canViewDocumentTypes)
              LabelFormField<DocumentType>(
                showAnyAssignedOption: false,
                showNotAssignedOption: false,
                onAddLabel: (currentInput) => CreateLabelRoute(
                  LabelType.documentType,
                  name: currentInput,
                ).push<DocumentType>(context),
                canCreateNewLabel: currentUser.canCreateDocumentTypes,
                addLabelText: S.of(context)!.addDocumentType,
                labelText: S.of(context)!.documentType,
                initialValue: doc.documentType != null
                    ? SetIdQueryParameter(id: doc.documentType!)
                    : const UnsetIdQueryParameter(),
                options: labelRepository.documentTypes,
                name: fkDocumentType,
                prefixIcon: const Icon(Icons.description_outlined),
                allowSelectUnassigned: true,
                suggestions: suggestions?.documentTypes ?? [],
              ),
            if (currentUser.canViewDocumentTypes &&
                currentUser.canViewStoragePaths)
              const SizedBox(height: PmSpacing.md),
            if (currentUser.canViewStoragePaths)
              LabelFormField<StoragePath>(
                showAnyAssignedOption: false,
                showNotAssignedOption: false,
                onAddLabel: (currentInput) => CreateLabelRoute(
                  LabelType.storagePath,
                  name: currentInput,
                ).push<StoragePath>(context),
                canCreateNewLabel: currentUser.canCreateStoragePaths,
                addLabelText: S.of(context)!.addStoragePath,
                labelText: S.of(context)!.storagePath,
                options: labelRepository.storagePaths,
                initialValue: doc.storagePath != null
                    ? SetIdQueryParameter(id: doc.storagePath!)
                    : const UnsetIdQueryParameter(),
                name: fkStoragePath,
                prefixIcon: const Icon(Icons.folder_outlined),
                allowSelectUnassigned: true,
              ),
          ],
        ),
      if (currentUser.canViewCorrespondents ||
          currentUser.canViewDocumentTypes ||
          currentUser.canViewStoragePaths)
        gap,

      // ── Tags ─────────────────────────────────────────────────────────────
      if (currentUser.canViewTags)
        FormSectionCard(
          title: S.of(context)!.tags,
          children: [
            TagsFormField(
              options: labelRepository.tags,
              name: fkTags,
              allowOnlySelection: true,
              allowCreation: true,
              allowExclude: false,
              suggestions: suggestions?.tags ?? [],
              initialValue: IdsTagsQuery(include: doc.tags.toList()),
            ),
          ],
        ),
      if (currentUser.canViewTags) gap,

      // ── Custom Fields ─────────────────────────────────────────────────────
      if (currentUser.canViewCustomFields &&
          doc.customFields.isNotEmpty &&
          customFieldDefinitions.isNotEmpty)
        _buildCustomFieldSection(
          context,
          doc.customFields,
          customFieldDefinitions,
        ),
      if (currentUser.canViewCustomFields &&
          doc.customFields.isNotEmpty &&
          customFieldDefinitions.isNotEmpty)
        gap,

      // ── Content ───────────────────────────────────────────────────────────
      FormSectionCard(
        title: S.of(context)!.content,
        children: [
          FormBuilderTextField(
            name: fkContent,
            maxLines: null,
            minLines: 4,
            keyboardType: TextInputType.multiline,
            initialValue: doc.content,
            decoration: InputDecoration(
              hintText: 'Document text content\u2026', // TODO(l10n)
              border: OutlineInputBorder(borderRadius: PmRadii.rmd),
            ),
          ),
        ],
      ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Individual field builders
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildTitleFormField(String? initialTitle) {
    return FormBuilderTextField(
      name: fkTitle,
      initialValue: initialTitle,
      onChanged: (value) => _titleNotifier.value = value ?? '',
      decoration: InputDecoration(
        labelText: S.of(context)!.title,
        border: OutlineInputBorder(borderRadius: PmRadii.rmd),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          tooltip: S.of(context)!.clearAll,
          onPressed: () {
            _formKey.currentState?.fields[fkTitle]?.didChange(null);
            _titleNotifier.value = '';
          },
        ),
      ),
    );
  }

  Widget _buildCreatedAtFormField(
    DateTime? initialCreatedAtDate,
    FieldSuggestions? suggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormBuilderLocalizedDatePicker(
          name: fkCreatedDate,
          initialValue: initialCreatedAtDate,
          labelText: S.of(context)!.createdAt,
          firstDate: DateTime(1970, 1, 1),
          lastDate: DateTime(2100, 1, 1),
          locale: Localizations.localeOf(context),
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        if (suggestions?.hasSuggestedDates ?? false)
          SuggestionChipsRow<DateTime>(
            label: S.of(context)!.suggestions,
            suggestions: suggestions!.dates,
            itemBuilder: (context, date) => ActionChip(
              label: Text(
                DateFormat.yMMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(date),
              ),
              onPressed: () {
                _formKey.currentState?.fields[fkCreatedDate]?.didChange(
                  FormDateTime.fromDateTime(date),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCustomFieldSection(
    BuildContext context,
    Iterable<CustomFieldInstance> instances,
    Map<int, CustomFieldModel> definitions,
  ) {
    final fields = <Widget>[];
    for (final instance in instances) {
      final fieldId = instance.id;
      if (fieldId == null) continue;
      final definition = definitions[fieldId];
      if (definition == null) continue;
      final field = _buildCustomFieldEditor(definition, instance);
      if (field != null) fields.add(field);
    }
    if (fields.isEmpty) return const SizedBox.shrink();

    return FormSectionCard(
      title: S.of(context)!.customFields,
      children: [
        for (int i = 0; i < fields.length; i++) ...[
          fields[i],
          if (i < fields.length - 1) const SizedBox(height: PmSpacing.sm),
        ],
      ],
    );
  }

  Widget? _buildCustomFieldEditor(
    CustomFieldModel definition,
    CustomFieldInstance instance,
  ) {
    final fieldId = definition.id;
    if (fieldId == null) return null;
    final fieldName = _customFieldFormKey(fieldId);
    final label = definition.name ?? 'Custom field $fieldId';

    switch (definition.dataType) {
      case CustomFieldDataType.boolean:
        return FormBuilderSwitch(
          name: fieldName,
          title: Text(label),
          initialValue: _asBool(instance.value),
          secondary: const Icon(Icons.toggle_on_outlined),
        );
      case CustomFieldDataType.select:
        final options = _selectOptions(definition.extraData);
        if (options.isEmpty) {
          return _buildCustomFieldTextInput(
            name: fieldName,
            label: label,
            initialValue: instance.value?.toString(),
          );
        }
        return FormBuilderDropdown<String>(
          name: fieldName,
          initialValue: instance.value?.toString(),
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: PmRadii.rmd),
          ),
          items: [
            for (final option in options)
              DropdownMenuItem<String>(
                value: option.id,
                child: Text(option.label),
              ),
          ],
        );
      case CustomFieldDataType.documentLink:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(instance.value?.toString() ?? '-'),
        );
      case CustomFieldDataType.longText:
        return _buildCustomFieldTextInput(
          name: fieldName,
          label: label,
          initialValue: instance.value?.toString(),
          maxLines: 3,
        );
      case CustomFieldDataType.integer:
        return _buildCustomFieldTextInput(
          name: fieldName,
          label: label,
          initialValue: instance.value?.toString(),
          keyboardType: TextInputType.number,
          validator: (value) {
            final trimmed = value?.trim();
            if (trimmed == null || trimmed.isEmpty) return null;
            return int.tryParse(trimmed) == null
                ? S.of(context)!.pleaseEnterValidInteger
                : null;
          },
        );
      case CustomFieldDataType.float:
      case CustomFieldDataType.monetary:
        return _buildCustomFieldTextInput(
          name: fieldName,
          label: label,
          initialValue: instance.value?.toString(),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          validator: (value) {
            final trimmed = value?.trim();
            if (trimmed == null || trimmed.isEmpty) return null;
            return double.tryParse(trimmed) == null
                ? S.of(context)!.pleaseEnterValidNumber
                : null;
          },
        );
      case CustomFieldDataType.string:
      case CustomFieldDataType.url:
      case CustomFieldDataType.date:
        return _buildCustomFieldTextInput(
          name: fieldName,
          label: label,
          initialValue: instance.value?.toString(),
        );
    }
  }

  Widget _buildCustomFieldTextInput({
    required String name,
    required String label,
    String? initialValue,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return FormBuilderTextField(
      name: name,
      initialValue: initialValue,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: PmRadii.rmd),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Submit / dirty detection
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _onSubmit(
    DocumentModel document,
    Map<int, CustomFieldModel> customFieldDefinitions,
  ) async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    setState(() => _isSaving = true);
    // Capture all context-dependent values before any async gap.
    final cubit = context.read<DocumentEditCubit>();
    final router = GoRouter.of(context);
    final successMessage = S.of(context)!.documentSuccessfullyUpdated;
    try {
      final (
        title,
        correspondent,
        documentType,
        storagePath,
        tags,
        createdAt,
        content,
      ) = _currentValues;
      final customFields = _extractCustomFields(
        document.customFields,
        customFieldDefinitions,
      );
      final mergedDocument = document.copyWith(
        title: title,
        created: createdAt,
        correspondent: () => correspondent,
        documentType: () => documentType,
        storagePath: () => storagePath,
        tags: tags,
        content: content,
        customFields: customFields,
      );
      await cubit.updateDocument(mergedDocument);
      if (!mounted) return;
      showSnackBar(context, successMessage);
      router.pop();
    } on PaperlessApiException catch (error, stackTrace) {
      if (mounted) showErrorMessage(context, error, stackTrace);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _hasChanges(
    DocumentModel doc,
    Map<int, CustomFieldModel> customFieldDefinitions,
  ) {
    final fkState = _formKey.currentState;
    if (fkState == null) return false;
    final (
      title,
      correspondent,
      documentType,
      storagePath,
      tags,
      createdAt,
      content,
    ) = _currentValues;
    final customFields = _extractCustomFields(
      doc.customFields,
      customFieldDefinitions,
    );
    final isContentTouched =
        _formKey.currentState?.fields[fkContent]?.isDirty ?? false;
    return doc.title != title ||
        doc.correspondent != correspondent ||
        doc.documentType != documentType ||
        doc.storagePath != storagePath ||
        !const UnorderedIterableEquality().equals(doc.tags, tags) ||
        doc.created != createdAt ||
        (doc.content != content && isContentTouched) ||
        !_sameCustomFields(doc.customFields, customFields);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Value extraction helpers
  // ──────────────────────────────────────────────────────────────────────────

  (
    String? title,
    int? correspondent,
    int? documentType,
    int? storagePath,
    List<int>? tags,
    DateTime? createdAt,
    String? content,
  )
  get _currentValues {
    final fkState = _formKey.currentState!;

    final correspondentParam = fkState.getRawValue<IdQueryParameter?>(
      fkCorrespondent,
    );
    final documentTypeParam = fkState.getRawValue<IdQueryParameter?>(
      fkDocumentType,
    );
    final storagePathParam = fkState.getRawValue<IdQueryParameter?>(
      fkStoragePath,
    );
    final tagsParam = fkState.getRawValue<TagsQuery?>(fkTags);
    final title = fkState.getRawValue<String?>(fkTitle);
    final created = fkState.getRawValue<FormDateTime?>(fkCreatedDate);
    final content = fkState.getRawValue<String?>(fkContent);

    final correspondent = switch (correspondentParam) {
      SetIdQueryParameter(id: var id) => id,
      _ => null,
    };
    final documentType = switch (documentTypeParam) {
      SetIdQueryParameter(id: var id) => id,
      _ => null,
    };
    final storagePath = switch (storagePathParam) {
      SetIdQueryParameter(id: var id) => id,
      _ => null,
    };
    final tags = switch (tagsParam) {
      IdsTagsQuery(include: var i) => i,
      _ => null,
    };

    return (
      title,
      correspondent,
      documentType,
      storagePath,
      tags,
      created?.toDateTime(),
      content,
    );
  }

  Iterable<CustomFieldInstance> _extractCustomFields(
    Iterable<CustomFieldInstance> source,
    Map<int, CustomFieldModel> definitions,
  ) {
    return source
        .map((instance) {
          final fieldId = instance.id;
          if (fieldId == null) return instance;
          final definition = definitions[fieldId];
          if (definition == null) return instance;
          if (definition.dataType == CustomFieldDataType.documentLink) {
            return instance;
          }
          final formValue = _formKey.currentState?.getRawValue(
            _customFieldFormKey(fieldId),
          );
          return CustomFieldInstance(
            id: fieldId,
            value: _normalizeCustomFieldValue(definition, formValue),
          );
        })
        .toList(growable: false);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Custom field value normalisation
  // ──────────────────────────────────────────────────────────────────────────

  Object? _normalizeCustomFieldValue(
    CustomFieldModel definition,
    Object? rawValue,
  ) {
    switch (definition.dataType) {
      case CustomFieldDataType.boolean:
        return _asBool(rawValue);
      case CustomFieldDataType.integer:
        final text = rawValue?.toString().trim();
        if (text == null || text.isEmpty) return null;
        return int.tryParse(text);
      case CustomFieldDataType.float:
        final text = rawValue?.toString().trim();
        if (text == null || text.isEmpty) return null;
        return double.tryParse(text);
      case CustomFieldDataType.monetary:
      case CustomFieldDataType.select:
      case CustomFieldDataType.string:
      case CustomFieldDataType.url:
      case CustomFieldDataType.date:
      case CustomFieldDataType.longText:
      case CustomFieldDataType.documentLink:
        final text = rawValue?.toString().trim();
        return (text == null || text.isEmpty) ? null : text;
    }
  }

  bool _sameCustomFields(
    Iterable<CustomFieldInstance> a,
    Iterable<CustomFieldInstance> b,
  ) {
    return const DeepCollectionEquality().equals(
      _customFieldMap(a),
      _customFieldMap(b),
    );
  }

  Map<int, Object?> _customFieldMap(Iterable<CustomFieldInstance> fields) => {
    for (final f in fields)
      if (f.id != null) f.id!: f.value,
  };

  Map<int, CustomFieldModel> _customFieldDefs(BuildContext context) {
    final repo = Provider.of<CustomFieldRepository?>(context, listen: false);
    return repo?.customFields ?? const {};
  }

  String _customFieldFormKey(int id) => '$_fkCustomFieldPrefix$id';

  bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  List<({String id, String label})> _selectOptions(
    Map<String, dynamic>? extraData,
  ) {
    final options = extraData?['select_options'];
    if (options is! List) return const [];
    if (options.every((entry) => entry is String)) {
      return options
          .whereType<String>()
          .map((label) => (id: label, label: label))
          .toList(growable: false);
    }
    return options
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .where((entry) => entry['id'] != null && entry['label'] != null)
        .map(
          (entry) =>
              (id: entry['id'].toString(), label: entry['label'].toString()),
        )
        .toList(growable: false);
  }
}
