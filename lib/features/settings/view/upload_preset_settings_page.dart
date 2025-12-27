import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_form_field.dart';
import 'package:paperless_mobile/features/labels/view/widgets/label_form_field.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/upload_preset_helper.dart';
import 'package:paperless_mobile/routing/routes/labels_route.dart';
import 'package:provider/provider.dart';

class UploadPresetSettingsPage extends StatefulWidget {
  const UploadPresetSettingsPage({super.key});

  @override
  State<UploadPresetSettingsPage> createState() =>
      _UploadPresetSettingsPageState();
}

class _UploadPresetSettingsPageState extends State<UploadPresetSettingsPage> {
  static const _fieldEnabled = 'uploadPresetEnabled';
  static const _fieldTitleTemplate = 'uploadPresetTitleTemplate';
  static const _fieldUseCurrentDate = 'uploadPresetUseCurrentDate';

  final GlobalKey<FormBuilderState> _formKey = GlobalKey();
  late final GlobalSettings _settings;
  String _previewTitle = '';

  @override
  void initState() {
    super.initState();
    _settings =
        Hive.box<GlobalSettings>(HiveBoxes.globalSettings).getValue()!;
    _previewTitle = buildTitleFromTemplate(
      _settings.uploadPresetTitleTemplate,
      DateTime.now(),
    );
  }

  void _applyForm() {
    final formState = _formKey.currentState;
    if (formState == null) return;
    final values = formState.value;

    _settings.uploadPresetEnabled =
        values[_fieldEnabled] as bool? ?? _settings.uploadPresetEnabled;
    _settings.uploadPresetTitleTemplate =
        (values[_fieldTitleTemplate] as String?) ??
            _settings.uploadPresetTitleTemplate;
    _settings.uploadPresetUseCurrentDate =
        values[_fieldUseCurrentDate] as bool? ??
            _settings.uploadPresetUseCurrentDate;
    if (values.containsKey(DocumentModel.correspondentKey)) {
      _settings.uploadPresetCorrespondentId = _extractId(
        values[DocumentModel.correspondentKey] as IdQueryParameter?,
      );
    }
    if (values.containsKey(DocumentModel.documentTypeKey)) {
      _settings.uploadPresetDocumentTypeId = _extractId(
        values[DocumentModel.documentTypeKey] as IdQueryParameter?,
      );
    }
    if (values.containsKey(DocumentModel.storagePathKey)) {
      _settings.uploadPresetStoragePathId = _extractId(
        values[DocumentModel.storagePathKey] as IdQueryParameter?,
      );
    }
    if (values.containsKey(DocumentModel.tagsKey)) {
      _settings.uploadPresetTagIds = _extractTags(
        values[DocumentModel.tagsKey] as TagsQuery?,
      );
    }

    _settings.save();
    final template = _settings.uploadPresetTitleTemplate;
    setState(() {
      _previewTitle = buildTitleFromTemplate(
        template,
        DateTime.now(),
      );
    });
  }

  int? _extractId(IdQueryParameter? param) {
    return switch (param) {
      SetIdQueryParameter(id: final id) => id,
      _ => null,
    };
  }

  List<int> _extractTags(TagsQuery? query) {
    return switch (query) {
      IdsTagsQuery(include: final ids) => ids.toList(),
      _ => <int>[],
    };
  }

  IdQueryParameter? _idParam(int? id) {
    return id != null ? SetIdQueryParameter(id: id) : null;
  }

  @override
  Widget build(BuildContext context) {
    final labelRepository = context.watch<LabelRepository>();
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.uploadPresets),
      ),
      body: FormBuilder(
        key: _formKey,
        onChanged: _applyForm,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FormBuilderSwitch(
              name: _fieldEnabled,
              initialValue: _settings.uploadPresetEnabled,
              title: Text(S.of(context)!.uploadPresetEnableTitle),
              subtitle: Text(S.of(context)!.uploadPresetEnableSubtitle),
            ),
            const SizedBox(height: 8),
            FormBuilderTextField(
              name: _fieldTitleTemplate,
              initialValue: _settings.uploadPresetTitleTemplate,
              decoration: InputDecoration(
                labelText: S.of(context)!.uploadPresetTitleTemplate,
                helperText: S
                    .of(context)!
                    .uploadPresetTitleTemplateHelper(
                      '{date}',
                      '{datetime}',
                      '{time}',
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.uploadPresetTitleExample(_previewTitle),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            FormBuilderSwitch(
              name: _fieldUseCurrentDate,
              initialValue: _settings.uploadPresetUseCurrentDate,
              title: Text(S.of(context)!.createdAt),
              subtitle:
                  Text(S.of(context)!.uploadPresetUseCurrentDateSubtitle),
            ),
            const SizedBox(height: 16),
            if (context
                .watch<LocalUserAccount>()
                .paperlessUser
                .canViewCorrespondents)
              LabelFormField<Correspondent>(
                showAnyAssignedOption: false,
                showNotAssignedOption: false,
                onAddLabel: (initialName) => CreateLabelRoute(
                  LabelType.correspondent,
                  name: initialName,
                ).push<Correspondent>(context),
                addLabelText: S.of(context)!.addCorrespondent,
                labelText: "${S.of(context)!.correspondent} *",
                name: DocumentModel.correspondentKey,
                options: labelRepository.correspondents,
                prefixIcon: const Icon(Icons.person_outline),
                allowSelectUnassigned: true,
                canCreateNewLabel: context
                    .watch<LocalUserAccount>()
                    .paperlessUser
                    .canCreateCorrespondents,
                initialValue: _idParam(_settings.uploadPresetCorrespondentId),
              ),
            if (context
                .watch<LocalUserAccount>()
                .paperlessUser
                .canViewDocumentTypes)
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
                prefixIcon: const Icon(Icons.description_outlined),
                allowSelectUnassigned: true,
                canCreateNewLabel: context
                    .watch<LocalUserAccount>()
                    .paperlessUser
                    .canCreateDocumentTypes,
                initialValue: _idParam(_settings.uploadPresetDocumentTypeId),
              ),
            if (context
                .watch<LocalUserAccount>()
                .paperlessUser
                .canViewStoragePaths)
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
                canCreateNewLabel: context
                    .watch<LocalUserAccount>()
                    .paperlessUser
                    .canCreateStoragePaths,
                initialValue: _idParam(_settings.uploadPresetStoragePathId),
              ),
            if (context.watch<LocalUserAccount>().paperlessUser.canViewTags)
              TagsFormField(
                name: DocumentModel.tagsKey,
                allowCreation: true,
                allowExclude: false,
                allowOnlySelection: true,
                options: labelRepository.tags,
                initialValue: _settings.uploadPresetTagIds.isNotEmpty
                    ? IdsTagsQuery(include: _settings.uploadPresetTagIds)
                    : null,
              ),
            const SizedBox(height: 24),
            Text(
              '* ${S.of(context)!.uploadInferValuesHint}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.justify,
            ).padded(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
