import 'dart:developer' as dev;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/constants.dart';
import 'package:paperless_mobile/core/bloc/loading_status.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/global/constants.dart';
import 'package:paperless_mobile/core/model/info_message_exception.dart';
import 'package:paperless_mobile/core/service/file_service.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/core/service/document_upload_service.dart';
import 'package:paperless_mobile/features/app_drawer/view/app_drawer.dart';
import 'package:paperless_mobile/features/document_scan/cubit/document_scanner_cubit.dart';
import 'package:paperless_mobile/features/document_scan/view/widgets/scanner_grid.dart';
import 'package:paperless_mobile/features/document_scan/scan_pdf_assembler.dart';
import 'package:paperless_mobile/features/document_scan/view/widgets/export_scans_dialog.dart';
import 'package:paperless_mobile/features/document_search/view/sliver_search_bar.dart';
import 'package:paperless_mobile/features/document_upload/model/document_upload_result.dart';
import 'package:paperless_mobile/features/documents/view/pages/document_view.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';
import 'package:paperless_mobile/features/settings/view/widgets/global_settings_builder.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/connectivity_aware_action_wrapper.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:paperless_mobile/helpers/permission_helpers.dart';
import 'package:paperless_mobile/helpers/upload_preset_helper.dart';
import 'package:paperless_mobile/routing/routes/scanner_route.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:sliver_tools/sliver_tools.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  final SliverOverlapAbsorberHandle searchBarHandle =
      SliverOverlapAbsorberHandle();
  final SliverOverlapAbsorberHandle actionsHandle =
      SliverOverlapAbsorberHandle();

  final _scrollController = ScrollController();
  bool _isQuickUploading = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: Scaffold(
        drawer: const AppDrawer(),
        floatingActionButton: FloatingActionButton(
          heroTag: "fab_document_edit",
          onPressed: () => _openDocumentScanner(context),
          child: const Icon(Icons.add_a_photo_outlined),
        ),
        body: NestedScrollView(
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverOverlapAbsorber(
              handle: searchBarHandle,
              sliver: SliverSearchBar(titleText: S.of(context)!.scanner),
            ),
            SliverOverlapAbsorber(
              handle: actionsHandle,
              sliver: SliverPinnedHeader(child: _buildActions()),
            ),
          ],
          body: BlocBuilder<DocumentScannerCubit, DocumentScannerState>(
            builder: (context, state) {
              return switch (state.status) {
                LoadingStatus.initial => _buildEmptyState(),
                LoadingStatus.loading => Center(child: Text("Restoring...")),
                LoadingStatus.loaded => ScannerGrid(
                  scans: state.scans,
                  searchBarHandle: searchBarHandle,
                  actionsHandle: actionsHandle,
                  onDelete: (file) async {
                    try {
                      context.read<DocumentScannerCubit>().removeScan(file);
                    } on PaperlessApiException catch (error, stackTrace) {
                      showErrorMessage(context, error, stackTrace);
                    } on InfoMessageException catch (error, stackTrace) {
                      showInfoMessage(context, error, stackTrace);
                    }
                  },
                ),
                LoadingStatus.error => Placeholder(),
              };
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: kTextTabBarHeight,
        child: BlocBuilder<DocumentScannerCubit, DocumentScannerState>(
          builder: (context, state) {
            return RawScrollbar(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              interactive: false,
              thumbVisibility: true,
              thickness: 2,
              radius: Radius.circular(2),
              controller: _scrollController,
              child: ListView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                children: [
                  SizedBox(width: 12),
                  TextButton.icon(
                    label: Text(S.of(context)!.previewScan),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                    ),
                    onPressed: state.scans.isNotEmpty
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => DocumentView(
                                bytes: _assembleFileBytes(
                                  state.scans,
                                  forcePdf: true,
                                ).then((file) => file.bytes),
                              ),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  SizedBox(width: 8),
                  GlobalSettingsBuilder(
                    builder: (context, settings) {
                      if (!settings.uploadPresetEnabled) {
                        return const SizedBox.shrink();
                      }
                      return ConnectivityAwareActionWrapper(
                        offlineBuilder: (context, child) {
                          return TextButton.icon(
                            label: Text(S.of(context)!.quickUpload),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                            ),
                            onPressed: null,
                            icon: const Icon(Icons.upload_outlined),
                          );
                        },
                        disabled: state.scans.isEmpty || _isQuickUploading,
                        child: TextButton.icon(
                          label: Text(S.of(context)!.quickUpload),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                          ),
                          onPressed: () =>
                              _onQuickUpload(context, state.scans, settings),
                          icon: _isQuickUploading
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_outlined),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 8),
                  TextButton.icon(
                    label: Text(S.of(context)!.clearAll),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                    ),
                    onPressed: state.scans.isEmpty
                        ? null
                        : () => _reset(context),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                  SizedBox(width: 8),
                  ConnectivityAwareActionWrapper(
                    offlineBuilder: (context, child) {
                      return TextButton.icon(
                        label: Text(S.of(context)!.upload),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                        ),
                        onPressed: null,
                        icon: const Icon(Icons.upload_outlined),
                      );
                    },
                    disabled: state.scans.isEmpty,
                    child: TextButton.icon(
                      label: Text(S.of(context)!.upload),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                      ),
                      onPressed: () =>
                          _onPrepareDocumentUpload(context, state.scans),
                      icon: const Icon(Icons.upload_outlined),
                    ),
                  ),
                  SizedBox(width: 8),
                  TextButton.icon(
                    label: Text(S.of(context)!.export),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                    ),
                    onPressed: state.scans.isEmpty ? null : _onSaveToFile,
                    icon: const Icon(Icons.save_alt_outlined),
                  ),
                  SizedBox(width: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _onSaveToFile() async {
    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => const ExportScansDialog(),
    );
    if (fileName != null) {
      if (!mounted) return;
      final cubit = context.read<DocumentScannerCubit>();
      final file = await _assembleFileBytes(
        forcePdf: true,
        context.read<DocumentScannerCubit>().state.scans,
      );
      try {
        final globalSettings = Hive.box<GlobalSettings>(
          HiveBoxes.globalSettings,
        ).getValue()!;
        if (Platform.isAndroid && androidInfo!.version.sdkInt <= 29) {
          final isGranted = await askForPermission(Permission.storage);
          if (!isGranted) {
            if (!mounted) return;
            showSnackBar(
              context,
              "Please grant Paperless Mobile permissions to access your filesystem.",
              action: SnackBarActionConfig(
                label: "OK",
                onPressed: openAppSettings,
              ),
            );
            return;
          }
        }
        await cubit.saveToFile(
          file.bytes,
          "$fileName.pdf",
          globalSettings.preferredLocaleSubtag,
        );
      } catch (error) {
        if (!mounted) return;
        showGenericError(context, error);
      }
    }
  }

  void _openDocumentScanner(BuildContext context) async {
    if (!Platform.isAndroid) {
      showSnackBar(
        context,
        "Document scanning is currently available on Android only.",
      );
      return;
    }
    final hasCameraPermission = await askForPermission(Permission.camera);
    if (!hasCameraPermission) {
      return;
    }
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        pageLimit: 30,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      final images = result.images;
      if (images.isEmpty) {
        if (kDebugMode) {
          dev.log('[ScannerPage] Scan canceled or returned no images.');
        }
        return;
      }
      for (final imagePath in images) {
        final extension = p.extension(imagePath).isNotEmpty
            ? p.extension(imagePath)
            : '.jpg';
        final file = await FileService.instance.allocateTemporaryFile(
          PaperlessDirectoryType.scans,
          extension: extension.replaceFirst('.', ''),
          create: true,
        );
        await File(imagePath).copy(file.path);
        if (kDebugMode) {
          dev.log('[ScannerPage] Saved scan to temporary file: ${file.path}');
        }
        if (!context.mounted) return;
        context.read<DocumentScannerCubit>().addScan(file);
      }
    } on PlatformException catch (error, stackTrace) {
      final isCancelled =
          error.code == 'DocumentScanner' &&
          (error.message?.toLowerCase().contains('cancel') ?? false);
      if (isCancelled) {
        if (kDebugMode) {
          dev.log(
            '[ScannerPage] Document scan cancelled by user.',
            error: error,
            stackTrace: stackTrace,
          );
        }
        return;
      }
      if (kDebugMode) {
        dev.log(
          '[ScannerPage] Document scan failed.',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (!context.mounted) return;
      showGenericError(context, error);
    } on Exception catch (error, stackTrace) {
      if (kDebugMode) {
        dev.log(
          '[ScannerPage] Document scan failed.',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (!context.mounted) return;
      showGenericError(context, error);
    } finally {
      await scanner.close();
    }
  }

  Future<void> _onQuickUpload(
    BuildContext context,
    List<File> scans,
    GlobalSettings settings,
  ) async {
    if (_isQuickUploading) {
      return;
    }
    final hasInternetConnection = await context
        .read<ConnectivityStatusService>()
        .isConnectedToInternet();
    if (!context.mounted) return;
    if (!hasInternetConnection) {
      showSnackBar(context, S.of(context)!.youreOffline);
      return;
    }
    if (scans.isEmpty) {
      if (!context.mounted) return;
      showSnackBar(context, S.of(context)!.noDocumentsScannedYet);
      return;
    }

    final documentsApi = context.read<PaperlessDocumentsApi>();
    final tasksNotifier = context.read<PendingTasksNotifier>();
    final preset = UploadPreset.fromSettings(settings);
    final now = DateTime.now();
    final assembled = await _assembleFileBytes(
      scans,
      forcePdf: settings.enforceSinglePagePdfUpload,
    );
    if (!mounted) return;
    final title = preset.buildTitle(now);
    final filename = _padWithExtension(
      formatFilename(title),
      assembled.extension,
    );
    final uploadService = DocumentUploadService(documentsApi, tasksNotifier);

    try {
      setState(() => _isQuickUploading = true);
      await uploadService.upload(
        assembled.bytes,
        filename: filename,
        title: title,
        correspondent: preset.correspondentId,
        documentType: preset.documentTypeId,
        storagePath: preset.storagePathId,
        tags: preset.tagIds,
        createdAt: preset.useCurrentDate ? now : null,
      );
      if (!context.mounted) return;
      showSnackBar(
        context,
        S.of(context)!.documentSuccessfullyUploadedProcessing,
      );
      context.read<DocumentScannerCubit>().reset();
    } on PaperlessApiException catch (error, stackTrace) {
      if (!context.mounted) return;
      showErrorMessage(context, error, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isQuickUploading = false);
      }
    }
  }

  String _padWithExtension(String source, String extension) {
    return source.endsWith(extension) ? source : '$source$extension';
  }

  void _onPrepareDocumentUpload(BuildContext context, List<File> scans) async {
    final file = await _assembleFileBytes(
      scans,
      forcePdf: Hive.box<GlobalSettings>(
        HiveBoxes.globalSettings,
      ).getValue()!.enforceSinglePagePdfUpload,
    );
    if (!context.mounted) return;
    final uploadResult = await DocumentUploadRoute(
      $extra: file.bytes,
      fileExtension: file.extension,
    ).push<DocumentUploadResult>(context);
    if (uploadResult?.success ?? false) {
      if (!context.mounted) return;
      // For paperless version older than 1.11.3, task id will always be null!
      context.read<DocumentScannerCubit>().reset();
      // context
      //     .read<PendingTasksNotifier>()
      //     .listenToTaskChanges(uploadResult!.taskId!);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              S.of(context)!.noDocumentsScannedYet,
              textAlign: TextAlign.center,
            ),
            TextButton(
              child: Text(S.of(context)!.scanADocument),
              onPressed: () => _openDocumentScanner(context),
            ),
            Text(S.of(context)!.or),
            ConnectivityAwareActionWrapper(
              offlineBuilder: (context, child) => TextButton(
                onPressed: null,
                child: Text(S.of(context)!.uploadADocumentFromThisDevice),
              ),
              child: TextButton(
                onPressed: _onUploadFromFilesystem,
                child: Text(S.of(context)!.uploadADocumentFromThisDevice),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reset(BuildContext context) {
    try {
      context.read<DocumentScannerCubit>().reset();
    } on PaperlessApiException catch (error, stackTrace) {
      showErrorMessage(context, error, stackTrace);
    }
  }

  void _onUploadFromFilesystem() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedFileExtensions
          .map((e) => e.replaceAll(".", ""))
          .toList(),
      withData: true,
      allowMultiple: false,
    );
    if (result?.files.single.path != null) {
      final path = result!.files.single.path!;
      final extension = p.extension(path);
      final filename = p.basenameWithoutExtension(path);
      File file = File(path);
      if (!supportedFileExtensions.contains(extension.toLowerCase())) {
        if (!mounted) return;
        showErrorMessage(
          context,
          const PaperlessApiException(ErrorCode.unsupportedFileFormat),
        );
        return;
      }
      if (!mounted) return;
      DocumentUploadRoute(
        $extra: file.readAsBytesSync(),
        filename: filename,
        title: filename,
        fileExtension: extension,
      ).push<DocumentUploadResult>(context);
      // if (uploadResult.success && uploadResult.taskId != null) {
      //   context
      //       .read<PendingTasksNotifier>()
      //       .listenToTaskChanges(uploadResult.taskId!);
      // }
    }
  }

  ///
  /// Returns the file bytes of either a single file or multiple images concatenated into a single pdf.
  ///
  Future<AssembledFile> _assembleFileBytes(
    final List<File> files, {
    bool forcePdf = false,
  }) async {
    assert(files.isNotEmpty);
    if (files.length == 1 && !forcePdf) {
      final ext = p.extension(files.first.path);
      return AssembledFile(ext, await files.first.readAsBytes());
    }
    final imageBytes = <Uint8List>[];
    for (final file in files) {
      imageBytes.add(await file.readAsBytes());
    }
    final pdfBytes = await buildPdfBytesFromImages(imageBytes);
    return AssembledFile('.pdf', pdfBytes);
  }
}

class AssembledFile {
  final String extension;
  final Uint8List bytes;

  AssembledFile(this.extension, this.bytes);
}
