import 'dart:io';
import 'dart:developer' as dev;

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
import 'package:paperless_mobile/features/document_upload/util/upload_task_tracker.dart';
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

typedef ScanAssembler =
    Future<ScannedAssembledFile> Function(List<File> files, {bool forcePdf});
typedef ExportFilenameProvider = Future<String?> Function(BuildContext context);
typedef DocumentUploadRouteProvider =
    Future<DocumentUploadResult?> Function(
      BuildContext context,
      ScannedAssembledFile file,
    );
typedef PreviewRouteProvider =
    Future<void> Function(BuildContext context, List<File> scans);
typedef PermissionRequestProvider =
    Future<bool> Function(Permission permission);
typedef DocumentScannerFactory = Future<DocumentScanner> Function();
typedef DocumentScannerScanProvider =
    Future<DocumentScanningResult> Function(DocumentScanner scanner);
typedef DocumentScannerCloseProvider =
    Future<void> Function(DocumentScanner scanner);
typedef FilePickerProvider =
    Future<String?> Function({required List<String> allowedExtensions});
typedef FilesystemUploadRouteProvider =
    Future<DocumentUploadResult?> Function(
      BuildContext context,
      Uint8List fileBytes,
      String filename,
      String title,
      String fileExtension,
    );
typedef PlatformIsAndroidProvider = bool Function();
typedef TemporaryScanFileAllocator =
    Future<File> Function({required String extension, required bool create});
typedef ScannedFileCopier =
    Future<void> Function(String sourcePath, String destinationPath);

bool isSupportedUploadExtension(String extension) {
  return supportedFileExtensions.contains(extension.toLowerCase());
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @visibleForTesting
  static ScanAssembler scanAssembler = assembleScannedFiles;
  @visibleForTesting
  static PreviewRouteProvider previewRouteProvider =
      _defaultPreviewRouteProvider;
  @visibleForTesting
  static PermissionRequestProvider permissionRequestProvider =
      _defaultPermissionRequestProvider;
  @visibleForTesting
  static DocumentScannerFactory documentScannerFactory =
      _defaultDocumentScannerFactory;
  @visibleForTesting
  static DocumentScannerScanProvider documentScannerScanProvider =
      _defaultDocumentScannerScanProvider;
  @visibleForTesting
  static DocumentScannerCloseProvider documentScannerCloseProvider =
      _defaultDocumentScannerCloseProvider;
  @visibleForTesting
  static PlatformIsAndroidProvider platformIsAndroidProvider =
      _defaultPlatformIsAndroidProvider;
  @visibleForTesting
  static TemporaryScanFileAllocator temporaryScanFileAllocator =
      _defaultTemporaryScanFileAllocator;
  @visibleForTesting
  static ScannedFileCopier scannedFileCopier = _defaultScannedFileCopier;
  @visibleForTesting
  static FilePickerProvider filePickerProvider = _defaultFilePickerProvider;
  @visibleForTesting
  static FilesystemUploadRouteProvider filesystemUploadRouteProvider =
      _defaultFilesystemUploadRouteProvider;
  @visibleForTesting
  static ExportFilenameProvider exportFilenameProvider =
      _defaultExportFilenameProvider;
  @visibleForTesting
  static DocumentUploadRouteProvider documentUploadRouteProvider =
      _defaultDocumentUploadRouteProvider;

  static Future<DocumentUploadResult?> _defaultDocumentUploadRouteProvider(
    BuildContext context,
    ScannedAssembledFile file,
  ) {
    return DocumentUploadRoute(
      $extra: file.bytes,
      fileExtension: file.extension,
    ).push<DocumentUploadResult>(context);
  }

  static Future<String?> _defaultExportFilenameProvider(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => const ExportScansDialog(),
    );
  }

  static Future<void> _defaultPreviewRouteProvider(
    BuildContext context,
    List<File> scans,
  ) async {
    final file = await ScannerPage.scanAssembler(scans, forcePdf: true);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DocumentView(bytes: Future.value(file.bytes)),
      ),
    );
  }

  static Future<bool> _defaultPermissionRequestProvider(Permission permission) {
    return askForPermission(permission);
  }

  static Future<DocumentScanner> _defaultDocumentScannerFactory() async {
    return DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        pageLimit: 30,
        isGalleryImport: true,
      ),
    );
  }

  static Future<DocumentScanningResult> _defaultDocumentScannerScanProvider(
    DocumentScanner scanner,
  ) {
    return scanner.scanDocument();
  }

  static Future<void> _defaultDocumentScannerCloseProvider(
    DocumentScanner scanner,
  ) {
    return scanner.close();
  }

  static Future<String?> _defaultFilePickerProvider({
    required List<String> allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  static Future<DocumentUploadResult?> _defaultFilesystemUploadRouteProvider(
    BuildContext context,
    Uint8List fileBytes,
    String filename,
    String title,
    String fileExtension,
  ) {
    return DocumentUploadRoute(
      $extra: fileBytes,
      filename: filename,
      title: title,
      fileExtension: fileExtension,
    ).push<DocumentUploadResult>(context);
  }

  static bool _defaultPlatformIsAndroidProvider() {
    return Platform.isAndroid;
  }

  static Future<File> _defaultTemporaryScanFileAllocator({
    required String extension,
    required bool create,
  }) {
    return FileService.instance.allocateTemporaryFile(
      PaperlessDirectoryType.scans,
      extension: extension,
      create: create,
    );
  }

  static Future<void> _defaultScannedFileCopier(
    String sourcePath,
    String destinationPath,
  ) async {
    await File(sourcePath).copy(destinationPath);
  }

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
                LoadingStatus.loading => Center(
                  child: Text(S.of(context)!.restoringScans),
                ),
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
                    key: const Key('scanner_preview_button'),
                    label: Text(S.of(context)!.previewScan),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                    ),
                    onPressed: state.scans.isNotEmpty
                        ? () => _onPreviewScans(context, state.scans)
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
                            key: const Key('scanner_quick_upload_button'),
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
                          key: const Key('scanner_quick_upload_button'),
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
                        key: const Key('scanner_upload_button'),
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
                      key: const Key('scanner_upload_button'),
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
                    key: const Key('scanner_export_button'),
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
    final fileName = await ScannerPage.exportFilenameProvider(context);
    if (fileName != null) {
      if (!mounted) return;
      final cubit = context.read<DocumentScannerCubit>();
      try {
        final file = await ScannerPage.scanAssembler(
          context.read<DocumentScannerCubit>().state.scans,
          forcePdf: true,
        );
        final globalSettings = Hive.box<GlobalSettings>(
          HiveBoxes.globalSettings,
        ).getValue()!;
        if (Platform.isAndroid && androidInfo!.version.sdkInt <= 29) {
          final isGranted = await askForPermission(Permission.storage);
          if (!isGranted) {
            if (!mounted) return;
            showSnackBar(
              context,
              S.of(context)!.grantFilesystemAccessPermission,
              action: SnackBarActionConfig(
                label: S.of(context)!.ok,
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
      } catch (error, stackTrace) {
        if (!mounted) return;
        showGenericError(context, error, stackTrace);
      }
    }
  }

  void _onPreviewScans(BuildContext context, List<File> scans) async {
    try {
      await ScannerPage.previewRouteProvider(context, scans);
    } catch (error, stackTrace) {
      if (!context.mounted) return;
      showGenericError(context, error, stackTrace);
    }
  }

  void _openDocumentScanner(BuildContext context) async {
    if (!ScannerPage.platformIsAndroidProvider()) {
      showSnackBar(context, S.of(context)!.documentScanningAndroidOnly);
      return;
    }
    final scannerCubit = context.read<DocumentScannerCubit>();
    final hasCameraPermission = await ScannerPage.permissionRequestProvider(
      Permission.camera,
    );
    if (!hasCameraPermission) {
      return;
    }
    final scanner = await ScannerPage.documentScannerFactory();
    try {
      final result = await ScannerPage.documentScannerScanProvider(scanner);
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
        final file = await ScannerPage.temporaryScanFileAllocator(
          extension: extension.replaceFirst('.', ''),
          create: false,
        );
        await ScannerPage.scannedFileCopier(imagePath, file.path);
        if (kDebugMode) {
          dev.log('[ScannerPage] Saved scan to temporary file: ${file.path}');
        }
        scannerCubit.addScan(file);
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
      try {
        await ScannerPage.documentScannerCloseProvider(scanner);
      } catch (error, stackTrace) {
        if (kDebugMode) {
          dev.log(
            '[ScannerPage] Failed to close document scanner.',
            error: error,
            stackTrace: stackTrace,
          );
        }
        if (!context.mounted) return;
        showGenericError(context, error, stackTrace);
      }
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

    try {
      final assembled = await assembleScannedFiles(
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
    } catch (error, stackTrace) {
      if (!context.mounted) return;
      showGenericError(context, error, stackTrace);
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
    try {
      final file = await ScannerPage.scanAssembler(
        scans,
        forcePdf: Hive.box<GlobalSettings>(
          HiveBoxes.globalSettings,
        ).getValue()!.enforceSinglePagePdfUpload,
      );
      if (!context.mounted) return;
      final uploadResult = await ScannerPage.documentUploadRouteProvider(
        context,
        file,
      );
      if (uploadResult?.success ?? false) {
        if (!context.mounted) return;
        // For paperless version older than 1.11.3, task id will always be null!
        trackUploadTaskFromResult(
          trackTaskId: context.read<PendingTasksNotifier>().listenToTaskChanges,
          result: uploadResult,
        );
        context.read<DocumentScannerCubit>().reset();
      }
    } on PaperlessApiException catch (error, stackTrace) {
      if (!context.mounted) return;
      showErrorMessage(context, error, stackTrace);
    } catch (error, stackTrace) {
      if (!context.mounted) return;
      showGenericError(context, error, stackTrace);
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
              child: _filesystemUploadButtonFromEmptyState(context),
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
    try {
      final pickedPath = await ScannerPage.filePickerProvider(
        allowedExtensions: supportedFileExtensions
            .map((e) => e.replaceAll(".", ""))
            .toList(),
      );
      if (pickedPath == null) {
        return;
      }
      final path = pickedPath;
      final extension = p.extension(path);
      final filename = p.basenameWithoutExtension(path);
      File file = File(path);
      if (!isSupportedUploadExtension(extension)) {
        if (!mounted) return;
        showErrorMessage(
          context,
          const PaperlessApiException(ErrorCode.unsupportedFileFormat),
        );
        return;
      }
      if (!mounted) return;
      final uploadResult = await ScannerPage.filesystemUploadRouteProvider(
        context,
        file.readAsBytesSync(),
        filename,
        filename,
        extension,
      );
      if (!mounted || !(uploadResult?.success ?? false)) {
        return;
      }
      trackUploadTaskFromResult(
        trackTaskId: context.read<PendingTasksNotifier>().listenToTaskChanges,
        result: uploadResult,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      showGenericError(context, error, stackTrace);
    }
  }

  Widget _filesystemUploadButtonFromEmptyState(BuildContext context) {
    return TextButton(
      key: const Key('scanner_filesystem_upload_button'),
      onPressed: _onUploadFromFilesystem,
      child: Text(S.of(context)!.uploadADocumentFromThisDevice),
    );
  }
}
