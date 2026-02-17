import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/widgets/form_builder_fields/form_builder_localized_date_picker.dart';
import 'package:paperless_mobile/core/widgets/future_or_builder.dart';
import 'package:paperless_mobile/features/document_upload/cubit/document_upload_cubit.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_form_field.dart';
import 'package:paperless_mobile/features/labels/view/widgets/label_form_field.dart';
import 'package:paperless_mobile/features/logging/data/logger.dart';
import 'package:paperless_mobile/features/sharing/view/widgets/file_thumbnail.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:paperless_mobile/helpers/upload_preset_helper.dart';
import 'package:paperless_mobile/routing/routes/labels_route.dart';
import 'package:provider/provider.dart';

class DocumentUploadPreparationPage extends StatefulWidget {
  final FutureOr<Uint8List> fileBytes;
  final String? title;
  final String? filename;
  final String? fileExtension;

  const DocumentUploadPreparationPage({
    super.key,
    required this.fileBytes,
    this.title,
    this.filename,
    this.fileExtension,
  });

  @override
  State<DocumentUploadPreparationPage> createState() =>
      _DocumentUploadPreparationPageState();
}

class _DocumentUploadPreparationPageState
    extends State<DocumentUploadPreparationPage> {
  static const fkFileName = "filename";
  static const _fkCustomFieldPrefix = 'customField_';

  final GlobalKey<FormBuilderState> _formKey = GlobalKey();
  Map<String, String> _errors = {};
  late bool _syncTitleAndFilename;
  final _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTitleAndFilename = widget.filename == null && widget.title == null;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<LocalUserAccount>().paperlessUser;
    final labelRepository = context.watch<LabelRepository>();
    final customFieldRepository = Provider.of<CustomFieldRepository?>(context);
    final customFieldDefinitions = {
      for (final field
          in customFieldRepository?.customFields.values ??
              const <CustomFieldModel>[])
        if (field.id != null) field.id!: field,
    };
    final settings = Hive.box<GlobalSettings>(
      HiveBoxes.globalSettings,
    ).getValue()!;
    final preset = UploadPreset.fromSettings(settings);
    final defaultTitle =
        widget.title ??
        (preset.enabled ? preset.buildTitle(_now) : defaultScanTitle(_now));
    final defaultFileName = widget.filename ?? formatFilename(defaultTitle);
    final initialCreatedDate = preset.enabled && preset.useCurrentDate
        ? _now
        : null;
    final initialTags = preset.enabled && preset.tagIds.isNotEmpty
        ? IdsTagsQuery(include: preset.tagIds)
        : null;
    final initialCorrespondent = preset.enabled
        ? _buildIdParam(preset.correspondentId)
        : null;
    final initialDocumentType = preset.enabled
        ? _buildIdParam(preset.documentTypeId)
        : null;
    final initialStoragePath = preset.enabled
        ? _buildIdParam(preset.storagePathId)
        : null;
    return BlocBuilder<DocumentUploadCubit, DocumentUploadState>(
      builder: (context, state) {
        return Scaffold(
          extendBodyBehindAppBar: false,
          resizeToAvoidBottomInset: true,
          floatingActionButton: Visibility(
            visible: MediaQuery.of(context).viewInsets.bottom == 0,
            child: FloatingActionButton.extended(
              heroTag: "fab_document_upload",
              onPressed: state.uploadProgress == null ? _onSubmit : null,
              label: state.uploadProgress == null
                  ? Text(S.of(context)!.upload)
                  : Text(S.of(context)!.uploading),
              icon: state.uploadProgress == null
                  ? const Icon(Icons.upload)
                  : SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        value: state.uploadProgress,
                      ),
                    ).padded(4),
            ),
          ),
          body: FormBuilder(
            key: _formKey,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverAppBar(
                    leading: const BackButton(),
                    pinned: true,
                    expandedHeight: 150,
                    actions: [
                      if (state.uploadProgress != null)
                        TextButton(
                          onPressed: () => context
                              .read<DocumentUploadCubit>()
                              .cancelUpload(),
                          child: Text(S.of(context)!.cancel),
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: FutureOrBuilder<Uint8List>(
                        future: widget.fileBytes,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          return FileThumbnail(
                            bytes: snapshot.data!,
                            fit: BoxFit.fitWidth,
                            width: MediaQuery.sizeOf(context).width,
                          );
                        },
                      ),
                      title: Text(S.of(context)!.prepareDocument),
                      collapseMode: CollapseMode.pin,
                    ),
                  ),
                ),
              ],
              body: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Builder(
                  builder: (context) {
                    final bottomPadding =
                        MediaQuery.of(context).padding.bottom + 96;
                    return CustomScrollView(
                      slivers: [
                        SliverOverlapInjector(
                          handle:
                              NestedScrollView.sliverOverlapAbsorberHandleFor(
                                context,
                              ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.only(bottom: bottomPadding),
                          sliver: SliverList.list(
                            children: [
                              // Title
                              FormBuilderTextField(
                                autovalidateMode: AutovalidateMode.always,
                                key: const ValueKey<String>(
                                  DocumentModel.titleKey,
                                ),
                                name: DocumentModel.titleKey,
                                initialValue: defaultTitle,
                                validator: (value) {
                                  if (value?.trim().isEmpty ?? true) {
                                    return S.of(context)!.thisFieldIsRequired;
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: S.of(context)!.title,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _formKey
                                          .currentState
                                          ?.fields[DocumentModel.titleKey]
                                          ?.didChange("");
                                      if (_syncTitleAndFilename) {
                                        _formKey
                                            .currentState
                                            ?.fields[fkFileName]
                                            ?.didChange("");
                                      }
                                    },
                                  ),
                                  errorText: _errors[DocumentModel.titleKey],
                                ),
                                onChanged: (value) {
                                  final String transformedValue =
                                      _formatFilename(value ?? '');
                                  if (_syncTitleAndFilename) {
                                    _formKey.currentState?.fields[fkFileName]
                                        ?.didChange(transformedValue);
                                  }
                                },
                              ),
                              // Filename
                              FormBuilderTextField(
                                autovalidateMode: AutovalidateMode.always,
                                readOnly: _syncTitleAndFilename,
                                enabled: !_syncTitleAndFilename,
                                name: fkFileName,
                                key: const ValueKey<String>(fkFileName),
                                decoration: InputDecoration(
                                  labelText: S.of(context)!.fileName,
                                  suffixText: widget.fileExtension,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _formKey
                                        .currentState
                                        ?.fields[fkFileName]
                                        ?.didChange(''),
                                  ),
                                ),
                                initialValue:
                                    widget.filename ?? defaultFileName,
                              ),
                              // Synchronize title and filename
                              SwitchListTile(
                                value: _syncTitleAndFilename,
                                onChanged: (value) {
                                  setState(() => _syncTitleAndFilename = value);
                                  if (_syncTitleAndFilename) {
                                    final String
                                    transformedValue = _formatFilename(
                                      _formKey
                                              .currentState
                                              ?.fields[DocumentModel.titleKey]
                                              ?.value
                                          as String,
                                    );
                                    if (_syncTitleAndFilename) {
                                      _formKey.currentState?.fields[fkFileName]
                                          ?.didChange(transformedValue);
                                    }
                                  }
                                },
                                title: Text(
                                  S.of(context)!.synchronizeTitleAndFilename,
                                ),
                              ),
                              // Created at
                              FormBuilderLocalizedDatePicker(
                                name: DocumentModel.createdKey,
                                firstDate: DateTime(1970, 1, 1),
                                lastDate: DateTime(2100, 1, 1),
                                locale: Localizations.localeOf(context),
                                labelText: "${S.of(context)!.createdAt} *",
                                allowUnset: true,
                                initialValue: initialCreatedDate,
                              ),
                              // Correspondent
                              if (user.canViewCorrespondents)
                                LabelFormField<Correspondent>(
                                  showAnyAssignedOption: false,
                                  showNotAssignedOption: false,
                                  onAddLabel: (initialName) => CreateLabelRoute(
                                    LabelType.correspondent,
                                    name: initialName,
                                  ).push<Correspondent>(context),
                                  addLabelText: S.of(context)!.addCorrespondent,
                                  labelText:
                                      "${S.of(context)!.correspondent} *",
                                  name: DocumentModel.correspondentKey,
                                  options: labelRepository.correspondents,
                                  prefixIcon: const Icon(Icons.person_outline),
                                  allowSelectUnassigned: true,
                                  canCreateNewLabel:
                                      user.canCreateCorrespondents,
                                  initialValue: initialCorrespondent,
                                ),
                              // Document type
                              if (user.canViewDocumentTypes)
                                LabelFormField<DocumentType>(
                                  showAnyAssignedOption: false,
                                  showNotAssignedOption: false,
                                  onAddLabel: (initialName) => CreateLabelRoute(
                                    LabelType.documentType,
                                    name: initialName,
                                  ).push<DocumentType>(context),
                                  addLabelText: S.of(context)!.addDocumentType,
                                  labelText: "${S.of(context)!.documentType} *",
                                  name: DocumentModel.documentTypeKey,
                                  options: labelRepository.documentTypes,
                                  prefixIcon: const Icon(
                                    Icons.description_outlined,
                                  ),
                                  allowSelectUnassigned: true,
                                  canCreateNewLabel:
                                      user.canCreateDocumentTypes,
                                  initialValue: initialDocumentType,
                                ),
                              if (user.canViewStoragePaths)
                                LabelFormField<StoragePath>(
                                  showAnyAssignedOption: false,
                                  showNotAssignedOption: false,
                                  onAddLabel: (initialName) => CreateLabelRoute(
                                    LabelType.storagePath,
                                    name: initialName,
                                  ).push<StoragePath>(context),
                                  addLabelText: S.of(context)!.addStoragePath,
                                  labelText: "${S.of(context)!.storagePath} *",
                                  name: DocumentModel.storagePathKey,
                                  options: labelRepository.storagePaths,
                                  prefixIcon: const Icon(Icons.folder_open),
                                  allowSelectUnassigned: true,
                                  canCreateNewLabel: user.canCreateStoragePaths,
                                  initialValue: initialStoragePath,
                                ),
                              if (user.canViewTags)
                                TagsFormField(
                                  name: DocumentModel.tagsKey,
                                  allowCreation: true,
                                  allowExclude: false,
                                  allowOnlySelection: true,
                                  options: labelRepository.tags,
                                  initialValue: initialTags,
                                ),
                              if (user.canViewCustomFields &&
                                  customFieldDefinitions.isNotEmpty)
                                ..._buildCustomFieldInputs(
                                  context,
                                  customFieldDefinitions,
                                ),
                              Text(
                                "* ${S.of(context)!.uploadInferValuesHint}",
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.justify,
                              ).padded(),
                            ].padded(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSubmit() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final cubit = context.read<DocumentUploadCubit>();
      try {
        final formValues = _formKey.currentState!.value;

        final correspondentParam =
            formValues[DocumentModel.correspondentKey] as IdQueryParameter?;
        final docTypeParam =
            formValues[DocumentModel.documentTypeKey] as IdQueryParameter?;
        final storagePathParam =
            formValues[DocumentModel.storagePathKey] as IdQueryParameter?;
        final tagsParam = formValues[DocumentModel.tagsKey] as TagsQuery?;
        final createdAt = formValues[DocumentModel.createdKey] as FormDateTime?;
        final title = formValues[DocumentModel.titleKey] as String;
        final correspondent = switch (correspondentParam) {
          SetIdQueryParameter(id: var id) => id,
          _ => null,
        };
        final docType = switch (docTypeParam) {
          SetIdQueryParameter(id: var id) => id,
          _ => null,
        };
        final storagePath = switch (storagePathParam) {
          SetIdQueryParameter(id: var id) => id,
          _ => null,
        };
        final tags = switch (tagsParam) {
          IdsTagsQuery(include: var ids) => ids,
          _ => const <int>[],
        };
        final customFieldRepository = Provider.of<CustomFieldRepository?>(
          context,
          listen: false,
        );
        final customFieldDefinitions = {
          for (final field
              in customFieldRepository?.customFields.values ??
                  const <CustomFieldModel>[])
            if (field.id != null) field.id!: field,
        };
        final customFieldValues = _extractCustomFieldValues(
          formValues,
          customFieldDefinitions,
        );
        final customFields = customFieldValues.isEmpty
            ? null
            : UploadCustomFields.values(customFieldValues);

        final asn = formValues[DocumentModel.asnKey] as int?;
        final outcome = await cubit.upload(
          await widget.fileBytes,
          filename: _padWithExtension(
            _formKey.currentState?.value[fkFileName],
            widget.fileExtension,
          ),
          title: title,
          documentType: docType,
          correspondent: correspondent,
          storagePath: storagePath,
          tags: tags,
          customFields: customFields,
          createdAt: createdAt?.toDateTime(),
          asn: asn,
        );
        if (!mounted) return;
        if (outcome.cancelled) {
          showSnackBar(context, S.of(context)!.requestCancelled);
          return;
        }
        if (!outcome.success) {
          final error = outcome.error;
          if (error != null) {
            showErrorMessage(context, error);
          } else {
            showSnackBar(context, S.of(context)!.couldNotUploadDocument);
          }
          return;
        }
        final details = outcome.taskId == null
            ? S.of(context)!.uploadProcessingStatusUnavailable
            : null;
        showSnackBar(
          context,
          S.of(context)!.documentSuccessfullyUploadedProcessing,
          details: details,
        );
        context.pop(outcome);
      } on PaperlessFormValidationException catch (exception) {
        setState(() => _errors = exception.validationMessages);
      } catch (error, stackTrace) {
        logger.fe(
          "An unknown error occurred during document upload.",
          className: runtimeType.toString(),
          methodName: "_onSubmit",
          error: error,
          stackTrace: stackTrace,
        );
        if (mounted) {
          showErrorMessage(
            context,
            const PaperlessApiException.unknown(),
            stackTrace,
          );
        }
      }
    }
  }

  String _padWithExtension(String source, [String? extension]) {
    final ext = extension ?? '.pdf';
    return source.endsWith(ext) ? source : '$source$ext';
  }

  String _formatFilename(String source) {
    return formatFilename(source);
  }

  IdQueryParameter? _buildIdParam(int? id) {
    return id != null ? SetIdQueryParameter(id: id) : null;
  }

  List<Widget> _buildCustomFieldInputs(
    BuildContext context,
    Map<int, CustomFieldModel> customFieldDefinitions,
  ) {
    final fields = customFieldDefinitions.values.toList(growable: false)
      ..sort(
        (a, b) => (a.name ?? '').toLowerCase().compareTo(
          (b.name ?? '').toLowerCase(),
        ),
      );
    final children = <Widget>[
      const SizedBox(height: 8),
      Text(
        S.of(context)!.customFields,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
    ];
    for (final definition in fields) {
      final input = _buildCustomFieldInput(context, definition);
      if (input == null) {
        continue;
      }
      children.add(input);
      children.add(const SizedBox(height: 8));
    }
    return children;
  }

  Widget? _buildCustomFieldInput(
    BuildContext context,
    CustomFieldModel definition,
  ) {
    final fieldId = definition.id;
    if (fieldId == null) {
      return null;
    }
    final label = definition.name ?? 'Custom field $fieldId';
    final fieldName = _customFieldFormKey(fieldId);

    switch (definition.dataType) {
      case CustomFieldDataType.boolean:
        return FormBuilderDropdown<String>(
          key: ValueKey<String>(fieldName),
          name: fieldName,
          initialValue: null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(S.of(context)!.none),
            ),
            DropdownMenuItem<String>(
              value: 'true',
              child: Text(S.of(context)!.customFieldBooleanTrue),
            ),
            DropdownMenuItem<String>(
              value: 'false',
              child: Text(S.of(context)!.customFieldBooleanFalse),
            ),
          ],
        );
      case CustomFieldDataType.select:
        final options = _selectOptions(definition.extraData);
        if (options.isEmpty) {
          return _buildCustomFieldTextInput(
            context: context,
            name: fieldName,
            label: label,
          );
        }
        return FormBuilderDropdown<String>(
          key: ValueKey<String>(fieldName),
          name: fieldName,
          initialValue: null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(S.of(context)!.none),
            ),
            for (final option in options)
              DropdownMenuItem<String>(
                value: option.id,
                child: Text(option.label),
              ),
          ],
        );
      case CustomFieldDataType.integer:
        return _buildCustomFieldTextInput(
          context: context,
          name: fieldName,
          label: label,
          keyboardType: TextInputType.number,
          validator: (value) {
            final trimmed = value?.trim();
            if (trimmed == null || trimmed.isEmpty) {
              return null;
            }
            return int.tryParse(trimmed) == null
                ? S.of(context)!.pleaseEnterValidInteger
                : null;
          },
        );
      case CustomFieldDataType.float:
      case CustomFieldDataType.monetary:
        return _buildCustomFieldTextInput(
          context: context,
          name: fieldName,
          label: label,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          validator: (value) {
            final trimmed = value?.trim();
            if (trimmed == null || trimmed.isEmpty) {
              return null;
            }
            return double.tryParse(trimmed) == null
                ? S.of(context)!.pleaseEnterValidNumber
                : null;
          },
        );
      case CustomFieldDataType.date:
        return FormBuilderLocalizedDatePicker(
          name: fieldName,
          firstDate: DateTime(1970, 1, 1),
          lastDate: DateTime(2100, 1, 1),
          locale: Localizations.localeOf(context),
          labelText: label,
          allowUnset: true,
        );
      case CustomFieldDataType.longText:
        return _buildCustomFieldTextInput(
          context: context,
          name: fieldName,
          label: label,
          maxLines: 3,
        );
      case CustomFieldDataType.documentLink:
      case CustomFieldDataType.string:
      case CustomFieldDataType.url:
        return _buildCustomFieldTextInput(
          context: context,
          name: fieldName,
          label: label,
        );
    }
  }

  Widget _buildCustomFieldTextInput({
    required BuildContext context,
    required String name,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return FormBuilderTextField(
      key: ValueKey<String>(name),
      name: name,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Map<int, Object?> _extractCustomFieldValues(
    Map<String, dynamic> formValues,
    Map<int, CustomFieldModel> customFieldDefinitions,
  ) {
    final values = <int, Object?>{};
    for (final entry in customFieldDefinitions.entries) {
      final fieldId = entry.key;
      final definition = entry.value;
      final rawValue = formValues[_customFieldFormKey(fieldId)];
      final normalizedValue = _normalizeCustomFieldValue(
        definition.dataType,
        rawValue,
      );
      if (normalizedValue != null) {
        values[fieldId] = normalizedValue;
      }
    }
    return values;
  }

  Object? _normalizeCustomFieldValue(
    CustomFieldDataType type,
    Object? rawValue,
  ) {
    switch (type) {
      case CustomFieldDataType.boolean:
        if (rawValue == null) {
          return null;
        }
        final text = rawValue.toString().trim();
        if (text.isEmpty) {
          return null;
        }
        return text.toLowerCase() == 'true' || text == '1';
      case CustomFieldDataType.integer:
        final text = rawValue?.toString().trim();
        if (text == null || text.isEmpty) {
          return null;
        }
        return int.tryParse(text);
      case CustomFieldDataType.float:
      case CustomFieldDataType.monetary:
        final text = rawValue?.toString().trim();
        if (text == null || text.isEmpty) {
          return null;
        }
        return double.tryParse(text);
      case CustomFieldDataType.date:
        if (rawValue is FormDateTime) {
          final date = rawValue.toDateTime();
          if (date == null) {
            return null;
          }
          return date.toIso8601String().split('T').first;
        }
        final text = rawValue?.toString().trim();
        return (text == null || text.isEmpty) ? null : text;
      case CustomFieldDataType.select:
      case CustomFieldDataType.documentLink:
      case CustomFieldDataType.longText:
      case CustomFieldDataType.string:
      case CustomFieldDataType.url:
        final text = rawValue?.toString().trim();
        return (text == null || text.isEmpty) ? null : text;
    }
  }

  String _customFieldFormKey(int fieldId) => '$_fkCustomFieldPrefix$fieldId';

  List<({String id, String label})> _selectOptions(
    Map<String, dynamic>? extraData,
  ) {
    final options = extraData?['select_options'];
    if (options is! List) {
      return const [];
    }
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

  // Future<Color> _computeAverageColor() async {
  //   final bitmap = img.decodeImage(await widget.fileBytes);
  //   if (bitmap == null) {
  //     return Colors.black;
  //   }
  //   int redBucket = 0;
  //   int greenBucket = 0;
  //   int blueBucket = 0;
  //   int pixelCount = 0;

  //   for (int y = 0; y < bitmap.height; y++) {
  //     for (int x = 0; x < bitmap.width; x++) {
  //       final c = bitmap.getPixel(x, y);

  //       pixelCount++;
  //       redBucket += c.r.toInt();
  //       greenBucket += c.g.toInt();
  //       blueBucket += c.b.toInt();
  //     }
  //   }

  //   return Color.fromRGBO(
  //     redBucket ~/ pixelCount,
  //     greenBucket ~/ pixelCount,
  //     blueBucket ~/ pixelCount,
  //     1,
  //   );
  // }
}
