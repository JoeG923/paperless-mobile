import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/features/document_details/cubit/document_details_cubit.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/archive_serial_number_field.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/document_permissions_widget.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_widget.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/format_helpers.dart';
import 'package:paperless_mobile/routing/routes/documents_route.dart';
import 'package:provider/provider.dart';

class DocumentInfoWidget extends StatelessWidget {
  final DocumentModel document;
  final DocumentMetaData? metaData;
  final String? queryString;

  const DocumentInfoWidget({
    super.key,
    required this.document,
    this.metaData,
    this.queryString,
  });

  @override
  Widget build(BuildContext context) {
    final hasMultiUserSupport = context
        .watch<LocalUserAccount>()
        .hasMultiUserSupport;

    return ListView(
      padding: PmSpacing.pagePadding,
      children: [
        _buildDocumentMetadataCard(context),
        const SizedBox(height: PmSpacing.md),
        _buildDatesCard(context),
        const SizedBox(height: PmSpacing.md),
        _buildSystemCard(context),
        if (_hasCustomFields(context)) ...[
          const SizedBox(height: PmSpacing.md),
          _buildCustomFieldsCard(context),
        ],
        if (hasMultiUserSupport) ...[
          const SizedBox(height: PmSpacing.md),
          _buildPermissionsCard(context),
        ],
      ],
    );
  }

  Widget _buildDocumentMetadataCard(BuildContext context) {
    final user = context.watch<LocalUserAccount>().paperlessUser;
    final labelRepository = context.watch<LabelRepository>();

    return Card.filled(
      child: Padding(
        padding: PmSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Details', // TODO(l10n)
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: PmSpacing.md),
            if (document.title.isNotEmpty)
              _DetailRow(
                icon: Icons.title,
                label: S.of(context)!.title,
                value: document.title,
                onTap: () => EditDocumentRoute(document).push(context),
              ),
            if (document.correspondent != null && user.canViewCorrespondents)
              _DetailRow(
                icon: Icons.person_outline,
                label: S.of(context)!.correspondent,
                value:
                    labelRepository
                        .correspondents[document.correspondent]
                        ?.name ??
                    '-',
                onTap: () => EditDocumentRoute(document).push(context),
              ),
            if (document.documentType != null && user.canViewDocumentTypes)
              _DetailRow(
                icon: Icons.category_outlined,
                label: S.of(context)!.documentType,
                value:
                    labelRepository
                        .documentTypes[document.documentType]
                        ?.name ??
                    '-',
                onTap: () => EditDocumentRoute(document).push(context),
              ),
            if (document.storagePath != null && user.canViewStoragePaths)
              _DetailRow(
                icon: Icons.folder_outlined,
                label: S.of(context)!.storagePath,
                value:
                    labelRepository.storagePaths[document.storagePath]?.name ??
                    '-',
                onTap: () => EditDocumentRoute(document).push(context),
              ),
            if (user.canViewTags) _buildTagsRow(context, labelRepository),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsRow(BuildContext context, LabelRepository labelRepository) {
    final tags = document.tags
        .map((e) => labelRepository.tags[e])
        .whereType<Tag>()
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: PmSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.label_outline,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: PmSpacing.md),
              Text(
                S.of(context)!.tags,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => EditDocumentRoute(document).push(context),
              ),
            ],
          ),
          const SizedBox(height: PmSpacing.xs),
          if (tags.isEmpty)
            Text(
              'No tags', // TODO(l10n)
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            TagsWidget(isClickable: false, tags: tags),
        ],
      ),
    );
  }

  Widget _buildDatesCard(BuildContext context) {
    final dateFormat = DateFormat.yMMMMd(
      Localizations.localeOf(context).toString(),
    );

    return Card.filled(
      child: Padding(
        padding: PmSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dates', // TODO(l10n)
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: PmSpacing.md),
            _DetailRow(
              icon: Icons.event,
              label: S.of(context)!.createdAt,
              value: dateFormat.format(document.created),
            ),
            _DetailRow(
              icon: Icons.add_circle_outline,
              label: S.of(context)!.addedAt,
              value: dateFormat.format(document.added),
            ),
            _DetailRow(
              icon: Icons.update,
              label: S.of(context)!.modifiedAt,
              value: dateFormat.format(document.modified),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemCard(BuildContext context) {
    final user = context.watch<LocalUserAccount>().paperlessUser;
    return Card.filled(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            'System', // TODO(l10n)
            style: Theme.of(context).textTheme.titleSmall,
          ),
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PmSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user.canEditDocuments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: PmSpacing.md),
                      child: ArchiveSerialNumberField(document: document),
                    ),
                  if (metaData != null) ...[
                    _DetailRow(
                      icon: Icons.storage,
                      label: S.of(context)!.mediaFilename,
                      value: metaData!.mediaFilename,
                    ),
                    if (document.originalFileName != null)
                      _DetailRow(
                        icon: Icons.description,
                        label: 'Original Filename', // TODO(l10n)
                        value: document.originalFileName!,
                      ),
                    _DetailRow(
                      icon: Icons.fingerprint,
                      label: S.of(context)!.originalMD5Checksum,
                      value: metaData!.originalChecksum,
                      valueStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    _DetailRow(
                      icon: Icons.data_usage,
                      label: S.of(context)!.originalFileSize,
                      value: formatBytes(metaData!.originalSize, 2),
                    ),
                    _DetailRow(
                      icon: Icons.code,
                      label: S.of(context)!.originalMIMEType,
                      value: metaData!.originalMimeType,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasCustomFields(BuildContext context) {
    final user = context.watch<LocalUserAccount>().paperlessUser;
    final customFieldRepository = Provider.of<CustomFieldRepository?>(context);
    return document.customFields.isNotEmpty &&
        user.canViewCustomFields &&
        customFieldRepository != null;
  }

  Widget _buildCustomFieldsCard(BuildContext context) {
    final customFieldRepository = Provider.of<CustomFieldRepository>(context);

    final fields = <Widget>[];
    for (final fieldInstance in document.customFields) {
      final fieldId = fieldInstance.id;
      if (fieldId == null) continue;

      final customField = customFieldRepository.customFields[fieldId];
      if (customField == null) continue;

      final fieldName = customField.name;
      if (fieldName == null || fieldName.trim().isEmpty) continue;

      fields.add(
        _DetailRow(
          icon: Icons.extension,
          label: fieldName,
          value: _formatCustomFieldValue(fieldInstance.value),
        ),
      );
    }

    if (fields.isEmpty) return const SizedBox.shrink();

    return Card.filled(
      child: Padding(
        padding: PmSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom Fields', // TODO(l10n)
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: PmSpacing.md),
            ...fields,
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsCard(BuildContext context) {
    return Card.filled(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            S.of(context)!.permissions,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PmSpacing.lg),
              child: DocumentPermissionsWidget(
                document: document,
                onUpdatePermissions: (update) {
                  return context.read<DocumentDetailsCubit>().updatePermissions(
                    permissions: update.permissions,
                    merge: update.merge,
                    owner: update.owner,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCustomFieldValue(Object? value) {
    if (value == null) {
      return '-';
    }
    if (value is List) {
      if (value.isEmpty) {
        return '-';
      }
      return value.join(', ');
    }
    if (value is Map) {
      if (value.isEmpty) {
        return '-';
      }
      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');
    }
    return value.toString();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: PmSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: PmSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: valueStyle ?? Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onTap,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PmRadii.sm),
        child: content,
      );
    }

    return content;
  }
}
