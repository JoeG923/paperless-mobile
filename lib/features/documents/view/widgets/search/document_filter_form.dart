import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/core/json/json_canonicalizer.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/widgets/form_builder_fields/extended_date_range_form_field/form_builder_extended_date_range_picker.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_form_field.dart';
import 'package:paperless_mobile/features/labels/view/widgets/label_form_field.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

import 'text_query_form_field.dart';

class DocumentFilterForm extends StatefulWidget {
  static const fkCorrespondent = DocumentModel.correspondentKey;
  static const fkDocumentType = DocumentModel.documentTypeKey;
  static const fkStoragePath = DocumentModel.storagePathKey;
  static const fkQuery = 'query';
  static const fkCustomFieldQuery = 'customFieldQuery';
  static const fkCreatedAt = DocumentModel.createdKey;
  static const fkAddedAt = DocumentModel.addedKey;

  static DocumentFilter assembleFilter(
    GlobalKey<FormBuilderState> formKey,
    DocumentFilter initialFilter,
  ) {
    formKey.currentState?.save();
    final v = formKey.currentState!.value;
    return initialFilter.copyWith(
      correspondent:
          v[DocumentFilterForm.fkCorrespondent] as IdQueryParameter? ??
          DocumentFilter.initial.correspondent,
      documentType:
          v[DocumentFilterForm.fkDocumentType] as IdQueryParameter? ??
          DocumentFilter.initial.documentType,
      storagePath:
          v[DocumentFilterForm.fkStoragePath] as IdQueryParameter? ??
          DocumentFilter.initial.storagePath,
      tags:
          v[DocumentModel.tagsKey] as TagsQuery? ?? DocumentFilter.initial.tags,
      query:
          v[DocumentFilterForm.fkQuery] as TextQuery? ??
          DocumentFilter.initial.query,
      customFieldQuery: () {
        final input = (v[DocumentFilterForm.fkCustomFieldQuery] as String?)
            ?.trim();
        return canonicalizeJsonString(input);
      },
      created: (v[DocumentFilterForm.fkCreatedAt] as DateRangeQuery),
      added: (v[DocumentFilterForm.fkAddedAt] as DateRangeQuery),
      page: 1,
    );
  }

  final Widget? header;
  final GlobalKey<FormBuilderState> formKey;
  final DocumentFilter initialFilter;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  const DocumentFilterForm({
    super.key,
    this.header,
    required this.formKey,
    required this.initialFilter,
    this.scrollController,
    this.padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  });

  @override
  State<DocumentFilterForm> createState() => _DocumentFilterFormState();
}

class _DocumentFilterFormState extends State<DocumentFilterForm> {
  late bool _allowOnlyExtendedQuery;

  @override
  void initState() {
    super.initState();
    _allowOnlyExtendedQuery = widget.initialFilter.forceExtendedQuery;
  }

  @override
  Widget build(BuildContext context) {
    final labelRepository = context.watch<LabelRepository>();
    final customFields = _loadCustomFields(context);
    return FormBuilder(
      key: widget.formKey,
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          if (widget.header != null) widget.header!,
          ..._buildFormFieldList(labelRepository, customFields),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Map<int, CustomFieldModel> _loadCustomFields(BuildContext context) {
    try {
      return context.read<CustomFieldRepository>().customFields;
    } catch (_) {
      return {};
    }
  }

  List<Widget> _buildFormFieldList(
    LabelRepository labelRepository,
    Map<int, CustomFieldModel> customFields,
  ) {
    return [
      _buildQueryFormField().paddedSymmetrically(horizontal: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          S.of(context)!.advanced,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ).paddedLTRB(12, 16, 12, 0),
      FormBuilderExtendedDateRangePicker(
        name: DocumentFilterForm.fkCreatedAt,
        initialValue: widget.initialFilter.created,
        labelText: S.of(context)!.createdAt,
        onChanged: (_) {
          _checkQueryConstraints();
        },
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
      FormBuilderExtendedDateRangePicker(
        name: DocumentFilterForm.fkAddedAt,
        initialValue: widget.initialFilter.added,
        labelText: S.of(context)!.addedAt,
        onChanged: (_) {
          _checkQueryConstraints();
        },
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
      _buildCustomFieldQueryFormField(
        customFields,
      ).paddedSymmetrically(horizontal: 12),
      _buildCorrespondentFormField(
        labelRepository.correspondents,
      ).paddedSymmetrically(horizontal: 16, vertical: 4),
      _buildDocumentTypeFormField(
        labelRepository.documentTypes,
      ).paddedSymmetrically(horizontal: 16, vertical: 4),
      _buildStoragePathFormField(
        labelRepository.storagePaths,
      ).paddedSymmetrically(horizontal: 16, vertical: 4),
      _buildTagsFormField(
        labelRepository.tags,
      ).paddedSymmetrically(horizontal: 16, vertical: 4),
    ].map((e) => SliverToBoxAdapter(child: e)).toList();
  }

  void _checkQueryConstraints() {
    final filter = DocumentFilterForm.assembleFilter(
      widget.formKey,
      widget.initialFilter,
    );
    if (filter.forceExtendedQuery) {
      setState(() => _allowOnlyExtendedQuery = true);
      final queryField =
          widget.formKey.currentState?.fields[DocumentFilterForm.fkQuery];
      queryField?.didChange(
        (queryField.value as TextQuery?)?.copyWith(
          queryType: QueryType.extended,
        ),
      );
    } else {
      setState(() => _allowOnlyExtendedQuery = false);
    }
  }

  Widget _buildDocumentTypeFormField(Map<int, DocumentType> documentTypes) {
    return LabelFormField<DocumentType>(
      name: DocumentFilterForm.fkDocumentType,
      options: documentTypes,
      labelText: S.of(context)!.documentType,
      initialValue: widget.initialFilter.documentType,
      prefixIcon: const Icon(Icons.description_outlined),
      allowSelectUnassigned: false,
      canCreateNewLabel: context
          .watch<LocalUserAccount>()
          .paperlessUser
          .canCreateDocumentTypes,
    );
  }

  Widget _buildCorrespondentFormField(Map<int, Correspondent> correspondents) {
    return LabelFormField<Correspondent>(
      name: DocumentFilterForm.fkCorrespondent,
      options: correspondents,
      labelText: S.of(context)!.correspondent,
      initialValue: widget.initialFilter.correspondent,
      prefixIcon: const Icon(Icons.person_outline),
      allowSelectUnassigned: false,
      canCreateNewLabel: context
          .watch<LocalUserAccount>()
          .paperlessUser
          .canCreateCorrespondents,
    );
  }

  Widget _buildStoragePathFormField(Map<int, StoragePath> storagePaths) {
    return LabelFormField<StoragePath>(
      name: DocumentFilterForm.fkStoragePath,
      options: storagePaths,
      labelText: S.of(context)!.storagePath,
      initialValue: widget.initialFilter.storagePath,
      prefixIcon: const Icon(Icons.folder_outlined),
      allowSelectUnassigned: false,
      canCreateNewLabel: context
          .watch<LocalUserAccount>()
          .paperlessUser
          .canCreateStoragePaths,
    );
  }

  Widget _buildQueryFormField() {
    return TextQueryFormField(
      name: DocumentFilterForm.fkQuery,
      onlyExtendedQueryAllowed: _allowOnlyExtendedQuery,
      initialValue: widget.initialFilter.query,
    );
  }

  Widget _buildCustomFieldQueryFormField(
    Map<int, CustomFieldModel> customFields,
  ) {
    return FormBuilderTextField(
      name: DocumentFilterForm.fkCustomFieldQuery,
      initialValue: widget.initialFilter.customFieldQuery,
      readOnly: true,
      decoration: InputDecoration(
        labelText: S.of(context)!.customFieldQuery,
        hintText: S.of(context)!.customFieldQueryHint,
        suffixIcon: IconButton(
          icon: const Icon(Icons.edit_note_outlined),
          tooltip: S.of(context)!.advanced,
          onPressed: () => _openCustomFieldQueryBuilder(customFields),
        ),
      ),
      validator: _validateCustomFieldQuery,
      maxLines: 3,
      minLines: 1,
      onTap: () => _openCustomFieldQueryBuilder(customFields),
    );
  }

  void _openCustomFieldQueryBuilder(
    Map<int, CustomFieldModel> customFields,
  ) async {
    final formField = widget
        .formKey
        .currentState
        ?.fields[DocumentFilterForm.fkCustomFieldQuery];
    if (formField == null) {
      return;
    }
    final currentValue = formField.value as String?;

    final nextValue = await showDialog<String?>(
      context: context,
      builder: (_) => _CustomFieldQueryBuilderDialog(
        initialQuery: currentValue,
        customFields: customFields,
      ),
    );

    if (mounted && nextValue != null) {
      formField.didChange(nextValue);
    }
  }

  String? _validateCustomFieldQuery(String? value) {
    final input = value?.trim();
    if (input == null || input.isEmpty) {
      return null;
    }
    try {
      jsonDecode(input);
      return null;
    } catch (_) {
      return S.of(context)!.enterCustomFieldValue;
    }
  }

  Widget _buildTagsFormField(Map<int, Tag> tags) {
    return TagsFormField(
      name: DocumentModel.tagsKey,
      initialValue: widget.initialFilter.tags,
      options: tags,
      allowExclude: false,
      allowOnlySelection: false,
      allowCreation: false,
    );
  }
}

class _CustomFieldQueryBuilderDialog extends StatefulWidget {
  final String? initialQuery;
  final Map<int, CustomFieldModel> customFields;

  const _CustomFieldQueryBuilderDialog({
    required this.initialQuery,
    required this.customFields,
  });

  @override
  State<_CustomFieldQueryBuilderDialog> createState() =>
      _CustomFieldQueryBuilderDialogState();
}

class _CustomFieldQueryBuilderDialogState
    extends State<_CustomFieldQueryBuilderDialog> {
  static const _allOperators = [
    'exact',
    'in',
    'isnull',
    'exists',
    'icontains',
    'istartswith',
    'iendswith',
    'gt',
    'gte',
    'lt',
    'lte',
    'range',
    'contains',
  ];

  static const _dateQueryComponentOperators = [
    'exact',
    'gt',
    'gte',
    'lt',
    'lte',
    'range',
  ];

  static const _dateQueryComponents = [
    'year',
    'iso_year',
    'month',
    'day',
    'week',
    'week_day',
    'iso_week_day',
    'quarter',
  ];

  static const _logicOptions = ['and', 'or', 'not'];

  late final TextEditingController _rawQueryController;
  late bool _useRawMode;
  late String _logic;
  late List<_CustomFieldQueryRule> _rules;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final fields = _availableFields;
    final parsed = _tryParseQuery(widget.initialQuery);
    _logic = parsed?.logic ?? 'and';
    if (fields.isEmpty) {
      _useRawMode = true;
      _rules = [];
    } else if (parsed == null) {
      _useRawMode = widget.initialQuery?.trim().isNotEmpty == true;
      _rules = [
        _newRule(
          fieldId: fields.first.id!,
          operator: _suggestedOperators(fields.first.dataType).first,
        ),
      ];
    } else {
      _useRawMode = false;
      _rules = parsed.rules;
    }
    _rawQueryController = TextEditingController(
      text: widget.initialQuery ?? '',
    );
  }

  @override
  void dispose() {
    for (final rule in _rules) {
      rule.dispose();
    }
    _rawQueryController.dispose();
    super.dispose();
  }

  List<CustomFieldModel> get _availableFields {
    final fields =
        widget.customFields.values
            .where((field) => field.id != null)
            .toList(growable: false)
          ..sort(
            (a, b) => (a.name ?? 'Custom field ${a.id}')
                .toLowerCase()
                .compareTo((b.name ?? 'Custom field ${b.id}').toLowerCase()),
          );
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final availableFields = _availableFields;

    return AlertDialog(
      title: Text(S.of(context)!.customFieldQuery),
      content: SizedBox(
        width: 560,
        child: _useRawMode || availableFields.isEmpty
            ? _buildRawJsonEditor()
            : _buildBuilderBody(context, availableFields),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.of(context)!.cancel),
        ),
        TextButton(
          onPressed: () {
            if (_useRawMode || availableFields.isEmpty) {
              final normalized = canonicalizeJsonString(
                _rawQueryController.text.trim(),
              );
              if (normalized == null &&
                  _rawQueryController.text.trim().isNotEmpty) {
                setState(
                  () => _validationError = S.of(context)!.enterCustomFieldValue,
                );
                return;
              }
              Navigator.pop(context, normalized);
              return;
            }

            final nextQuery = _buildQueryForSubmit();
            if (nextQuery == null) {
              setState(
                () => _validationError = S.of(context)!.enterCustomFieldValue,
              );
              return;
            }
            Navigator.pop(context, nextQuery);
          },
          child: Text(S.of(context)!.done),
        ),
      ],
    );
  }

  Widget _buildRawJsonEditor() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_rawQueryController.text.trim().isNotEmpty)
          const Text('Unsupported structure: edited as raw JSON.'),
        TextField(
          controller: _rawQueryController,
          maxLines: 8,
          minLines: 4,
          decoration: InputDecoration(
            hintText: S.of(context)!.customFieldQueryHint,
            errorText: _validationError,
          ),
          onChanged: (_) => _validationError = null,
        ),
      ],
    );
  }

  Widget _buildBuilderBody(
    BuildContext context,
    List<CustomFieldModel> availableFields,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          value: _logic,
          isExpanded: true,
          onChanged: (next) {
            if (next == null) {
              return;
            }
            setState(() {
              _logic = next;
              _validationError = null;
              if (_logic == 'not' && _rules.length > 1) {
                _rules = [_rules.first];
              }
            });
          },
          items: _logicOptions
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        ..._rules.asMap().entries.map((entry) {
          final index = entry.key;
          final rule = entry.value;
          final field = widget.customFields[rule.fieldId]!;
          final operators = _suggestedOperators(field.dataType);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<int>(
                    initialValue: rule.fieldId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Field'),
                    items: availableFields
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id!,
                            child: Text(item.name ?? 'Custom field ${item.id}'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        rule.fieldId = value;
                        final updatedOperators = _suggestedOperators(
                          widget.customFields[value]!.dataType,
                        );
                        rule.operator = updatedOperators.first;
                        rule.valueController.clear();
                        rule.boolValue = false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: rule.operator,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Operator'),
                    items: operators
                        .map(
                          (op) => DropdownMenuItem(value: op, child: Text(op)),
                        )
                        .toList(growable: false),
                    onChanged: (next) {
                      if (next == null) {
                        return;
                      }
                      setState(() {
                        rule.operator = next;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: _buildRuleValueInput(rule, field)),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      _rules.removeAt(index);
                      rule.dispose();
                      if (_rules.isEmpty) {
                        _rules.add(
                          _newRule(
                            fieldId: availableFields.first.id!,
                            operator: _suggestedOperators(
                              availableFields.first.dataType,
                            ).first,
                          ),
                        );
                      }
                    });
                  },
                ),
              ],
            ),
          );
        }),
        if (_validationError != null)
          Text(_validationError!, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _logic == 'not'
              ? null
              : () {
                  setState(() {
                    final firstField = availableFields.first;
                    _rules.add(
                      _newRule(
                        fieldId: firstField.id!,
                        operator: _suggestedOperators(
                          firstField.dataType,
                        ).first,
                      ),
                    );
                    _validationError = null;
                  });
                },
          icon: const Icon(Icons.add),
          label: const Text('Add rule'),
        ),
      ],
    );
  }

  Widget _buildRuleValueInput(
    _CustomFieldQueryRule rule,
    CustomFieldModel field,
  ) {
    final requiresBoolean =
        _requiresBoolean(rule.operator) ||
        field.dataType == CustomFieldDataType.boolean;
    if (requiresBoolean) {
      return DropdownButtonFormField<bool>(
        initialValue: rule.boolValue,
        isExpanded: true,
        decoration: InputDecoration(labelText: S.of(context)!.customFieldValue),
        items: const [
          DropdownMenuItem(value: true, child: Text('true')),
          DropdownMenuItem(value: false, child: Text('false')),
        ],
        onChanged: (next) {
          if (next == null) {
            return;
          }
          setState(() => rule.boolValue = next);
        },
      );
    }

    return TextField(
      controller: rule.valueController,
      decoration: InputDecoration(labelText: S.of(context)!.customFieldValue),
      keyboardType: _keyboardTypeFor(field.dataType),
    );
  }

  TextInputType _keyboardTypeFor(CustomFieldDataType dataType) {
    return switch (dataType) {
      CustomFieldDataType.integer => TextInputType.number,
      CustomFieldDataType.float || CustomFieldDataType.monetary =>
        const TextInputType.numberWithOptions(decimal: true, signed: true),
      _ => TextInputType.text,
    };
  }

  bool _requiresBoolean(String operator) {
    return switch (operator) {
      'isnull' || 'exists' => true,
      _ => false,
    };
  }

  List<String> _suggestedOperators(CustomFieldDataType dataType) {
    return switch (dataType) {
      CustomFieldDataType.string ||
      CustomFieldDataType.url ||
      CustomFieldDataType.longText => const [
        'exact',
        'in',
        'isnull',
        'exists',
        'icontains',
        'istartswith',
        'iendswith',
      ],
      CustomFieldDataType.boolean => const ['exact', 'in', 'isnull', 'exists'],
      CustomFieldDataType.integer ||
      CustomFieldDataType.float ||
      CustomFieldDataType.monetary => const [
        'exact',
        'in',
        'isnull',
        'exists',
        'gt',
        'gte',
        'lt',
        'lte',
        'range',
      ],
      CustomFieldDataType.date =>
        const [
              'exact',
              'in',
              'isnull',
              'exists',
              'gt',
              'gte',
              'lt',
              'lte',
              'range',
            ] +
            [
              for (final component in _dateQueryComponents)
                for (final op in _dateQueryComponentOperators)
                  '$component${'__'}$op',
            ],
      CustomFieldDataType.documentLink => const [
        'exact',
        'in',
        'isnull',
        'exists',
        'contains',
      ],
      CustomFieldDataType.select => const ['exact', 'in', 'isnull', 'exists'],
    };
  }

  String? _buildQueryForSubmit() {
    if (_rules.isEmpty) {
      return null;
    }

    final isNotQuery = _logic == 'not';
    if (isNotQuery && _rules.length != 1) {
      return null;
    }

    final parsedRules = <List<dynamic>>[];
    for (final rule in _rules) {
      final field = widget.customFields[rule.fieldId];
      if (field == null) {
        return null;
      }
      final parsedValue = _parseRuleValue(field.dataType, rule.operator, rule);
      if (parsedValue == null) {
        return null;
      }
      parsedRules.add([
        rule.fieldId,
        rule.operator,
        _normalizeRuleValue(parsedValue),
      ]);
    }

    if (isNotQuery) {
      return canonicalizeJsonString(jsonEncode(['not', parsedRules.single]));
    }

    return canonicalizeJsonString(jsonEncode([_logic, parsedRules]));
  }

  Object? _parseRuleValue(
    CustomFieldDataType dataType,
    String operator,
    _CustomFieldQueryRule rule,
  ) {
    if (dataType == CustomFieldDataType.boolean || _requiresBoolean(operator)) {
      return rule.boolValue;
    }

    if (_requiresListValue(operator)) {
      final values = rule.valueController.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (values.isEmpty) {
        if (operator == 'contains') {
          return [];
        }
        return null;
      }
      if (_operatorBase(operator) == 'range' && values.length != 2) {
        return null;
      }

      final parsedValues = values
          .map((value) => _parseSingleRuleValue(dataType, operator, value))
          .toList(growable: false);
      if (parsedValues.any((value) => value == null)) {
        return null;
      }
      return parsedValues;
    }

    return _parseSingleRuleValue(
      dataType,
      operator,
      rule.valueController.text.trim(),
    );
  }

  Object? _parseSingleRuleValue(
    CustomFieldDataType dataType,
    String operator,
    String rawValue,
  ) {
    if (rawValue.isEmpty) {
      if (dataType == CustomFieldDataType.string ||
          dataType == CustomFieldDataType.url ||
          dataType == CustomFieldDataType.longText ||
          dataType == CustomFieldDataType.select) {
        return rawValue;
      }
      return null;
    }
    return switch (dataType) {
      CustomFieldDataType.integer => int.tryParse(rawValue),
      CustomFieldDataType.float ||
      CustomFieldDataType.monetary => double.tryParse(rawValue),
      CustomFieldDataType.date => _parseDateValue(operator, rawValue),
      CustomFieldDataType.boolean => _parseBoolean(rawValue),
      CustomFieldDataType.documentLink => int.tryParse(rawValue),
      CustomFieldDataType.select => rawValue,
      _ => rawValue,
    };
  }

  String _operatorPrefix(String operator) {
    final index = operator.lastIndexOf('__');
    return index == -1 ? '' : operator.substring(0, index);
  }

  String _operatorBase(String operator) {
    final index = operator.lastIndexOf('__');
    return index == -1 ? operator : operator.substring(index + 2);
  }

  Object? _parseDateValue(String operator, String rawValue) {
    final prefix = _operatorPrefix(operator);
    if (prefix.isNotEmpty && _dateQueryComponents.contains(prefix)) {
      return int.tryParse(rawValue);
    }
    return DateTime.tryParse(rawValue);
  }

  bool _isKnownOperator(String operator) {
    if (_allOperators.contains(operator)) {
      return true;
    }
    final prefix = _operatorPrefix(operator);
    if (prefix.isEmpty) {
      return false;
    }
    return _dateQueryComponents.contains(prefix) &&
        _allOperators.contains(_operatorBase(operator));
  }

  Object _normalizeRuleValue(Object value) {
    if (value is DateTime) {
      return value.toIso8601String().split('T').first;
    }
    if (value is List) {
      return value
          .map((value) => _normalizeRuleValue(value))
          .toList(growable: false);
    }
    return value;
  }

  bool? _parseBoolean(String rawValue) {
    return switch (rawValue.toLowerCase()) {
      'true' => true,
      'false' => false,
      '1' => true,
      '0' => false,
      _ => null,
    };
  }

  bool _requiresListValue(String operator) {
    final baseOperator = _operatorBase(operator);
    return baseOperator == 'in' ||
        baseOperator == 'range' ||
        operator == 'contains';
  }

  _CustomFieldQueryRule? _tryParseRule(List<dynamic> rawRule) {
    if (rawRule.length != 3) {
      return null;
    }

    final field = _lookupCustomField(rawRule[0]);
    if (field == null) {
      return null;
    }
    final fieldId = field.id;
    if (fieldId == null) {
      return null;
    }

    final operator = rawRule[1]?.toString().toLowerCase();
    if (operator == null || !_isKnownOperator(operator)) {
      return null;
    }
    if (!_suggestedOperators(field.dataType).contains(operator)) {
      return null;
    }

    final operatorsNeedBoolean =
        _requiresBoolean(operator) ||
        field.dataType == CustomFieldDataType.boolean;
    final stringValue = _valueToString(rawRule[2]);
    final parsedBool = operatorsNeedBoolean ? _parseBoolean(stringValue) : null;

    return _CustomFieldQueryRule(
      fieldId: fieldId,
      operator: operator,
      boolValue: parsedBool ?? false,
      initialValue: operatorsNeedBoolean
          ? parsedBool == true
                ? 'true'
                : parsedBool == false
                ? 'false'
                : ''
          : stringValue,
    );
  }

  String _valueToString(Object? value) {
    if (value is List) {
      return value.join(',');
    }
    return value?.toString() ?? '';
  }

  CustomFieldModel? _lookupCustomField(Object? rawFieldRef) {
    if (rawFieldRef is int) {
      return widget.customFields[rawFieldRef];
    }

    if (rawFieldRef is String) {
      final normalized = rawFieldRef.trim();
      if (normalized.isEmpty) {
        return null;
      }

      for (final field in widget.customFields.values) {
        if (field.name == normalized) {
          return field;
        }
      }

      final lowerCaseName = normalized.toLowerCase();
      for (final field in widget.customFields.values) {
        if (field.name?.toLowerCase() == lowerCaseName) {
          return field;
        }
      }
    }

    return null;
  }

  _ParsedCustomFieldQuery? _tryParseQuery(String? query) {
    final input = query?.trim();
    if (input == null || input.isEmpty) {
      return null;
    }
    try {
      final value = jsonDecode(input);
      if (value is Map) {
        final operatorBasedParseResult = _tryParseQueryByOperatorField(value);
        if (operatorBasedParseResult != null) {
          return operatorBasedParseResult;
        }

        final keyBasedParseResult = _tryParseQueryByLogicKey(value);
        if (keyBasedParseResult != null) {
          return keyBasedParseResult;
        }
        return null;
      }

      if (value is List &&
          value.length == 2 &&
          value[0] is String &&
          value[1] is List &&
          _logicOptions.contains((value[0] as String).toLowerCase())) {
        final logic = (value[0] as String).toLowerCase();
        final rawRules = value[1] as List;
        if (logic == 'not') {
          if (rawRules.length != 3) {
            return null;
          }
          final parsedRule = _tryParseRule(rawRules.cast<dynamic>());
          return parsedRule == null
              ? null
              : _ParsedCustomFieldQuery(logic: logic, rules: [parsedRule]);
        }
        if (rawRules.isEmpty) {
          return null;
        }
        final rules = rawRules
            .whereType<List>()
            .map(_tryParseRule)
            .whereType<_CustomFieldQueryRule>()
            .toList(growable: false);
        if (rules.isEmpty) {
          return null;
        }
        return _ParsedCustomFieldQuery(logic: logic, rules: rules);
      }

      if (value is List && value.length == 3) {
        final parsed = _tryParseRule(value);
        return parsed == null
            ? null
            : _ParsedCustomFieldQuery(logic: 'and', rules: [parsed]);
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  _ParsedCustomFieldQuery? _tryParseQueryByOperatorField(
    Map<dynamic, dynamic> value,
  ) {
    final logic = value['operator']?.toString().toLowerCase();
    final rawRules = value['rules'];
    return _buildParsedQuery(logic, rawRules);
  }

  _ParsedCustomFieldQuery? _tryParseQueryByLogicKey(
    Map<dynamic, dynamic> value,
  ) {
    for (final logic in _logicOptions) {
      final rawRules = value[logic];
      if (rawRules == null) {
        continue;
      }
      final parsed = _buildParsedQuery(logic, rawRules);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  _ParsedCustomFieldQuery? _buildParsedQuery(String? logic, Object? rawRules) {
    if (logic == null || !_logicOptions.contains(logic) || rawRules is! List) {
      return null;
    }
    if (rawRules.isEmpty) {
      return null;
    }

    if (logic == 'not') {
      if (rawRules.length != 1) {
        return null;
      }
      if (rawRules.first is! List<dynamic>) {
        return null;
      }
      final parsedRule = _tryParseRule(rawRules.first as List<dynamic>);
      if (parsedRule == null) {
        return null;
      }
      return _ParsedCustomFieldQuery(logic: logic, rules: [parsedRule]);
    }

    final rules = rawRules
        .whereType<List>()
        .map(_tryParseRule)
        .whereType<_CustomFieldQueryRule>()
        .toList(growable: false);
    if (rules.isEmpty) {
      return null;
    }
    return _ParsedCustomFieldQuery(logic: logic, rules: rules);
  }

  _CustomFieldQueryRule _newRule({
    required int fieldId,
    required String operator,
    String? initialValue,
    bool boolValue = false,
  }) => _CustomFieldQueryRule(
    fieldId: fieldId,
    operator: operator,
    initialValue: initialValue,
    boolValue: boolValue,
  );
}

class _CustomFieldQueryRule {
  int fieldId;
  String operator;
  bool boolValue;
  final TextEditingController valueController;

  _CustomFieldQueryRule({
    required this.fieldId,
    required this.operator,
    String? initialValue,
    this.boolValue = false,
  }) : valueController = TextEditingController(text: initialValue ?? '');

  void dispose() {
    valueController.dispose();
  }
}

class _ParsedCustomFieldQuery {
  _ParsedCustomFieldQuery({required this.logic, required this.rules});

  final String logic;
  final List<_CustomFieldQueryRule> rules;
}
