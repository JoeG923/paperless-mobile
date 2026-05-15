import 'dart:async';
import 'dart:io';
import 'dart:developer' as dev;
import 'dart:math';

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
import 'package:paperless_mobile/core/theme/design_tokens.dart';
import 'package:paperless_mobile/core/widgets/state/pm_empty_state.dart';
import 'package:paperless_mobile/core/widgets/state/pm_error_state.dart';
import 'package:paperless_mobile/features/app_drawer/view/app_drawer.dart';
import 'package:paperless_mobile/features/document_scan/cubit/document_scanner_cubit.dart';
import 'package:paperless_mobile/features/document_scan/view/widgets/scanned_image_item.dart';
import 'package:paperless_mobile/features/document_scan/scan_pdf_assembler.dart';
import 'package:paperless_mobile/features/document_scan/view/widgets/export_scans_dialog.dart';
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
        documentFormats: const {DocumentFormat.jpeg},
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
  final Set<int> _selectedIndices = {};
  bool _isQuickUploading = false;
  bool _isUploading = false;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySub;

  bool get _isSelectionMode => _selectedIndices.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final connectivity = context.read<ConnectivityStatusService>();
    // Seed an initial value, then subscribe to updates.
    connectivity.isConnectedToInternet().then((connected) {
      if (!mounted) return;
      setState(() => _isOffline = !connected);
    });
    _connectivitySub = connectivity.connectivityChanges().listen((connected) {
      if (!mounted) return;
      setState(() => _isOffline = !connected);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentScannerCubit, DocumentScannerState>(
      builder: (context, state) {
        final hasScans = state.scans.isNotEmpty;

        return Scaffold(
          drawer: const AppDrawer(),
          body: _buildBody(context, state),
          floatingActionButton: hasScans && !_isSelectionMode
              ? FloatingActionButton.extended(
                  heroTag: "fab_add_page",
                  onPressed: () => _openDocumentScanner(context),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add page'), // TODO(l10n)
                )
              : (hasScans
                    ? null
                    : FloatingActionButton(
                        heroTag: "fab_document_scan",
                        onPressed: () => _openDocumentScanner(context),
                        child: const Icon(Icons.add_a_photo_outlined),
                      )),
          floatingActionButtonLocation: hasScans
              ? FloatingActionButtonLocation.endFloat
              : FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: _buildBottomBar(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, DocumentScannerState state) {
    return switch (state.status) {
      LoadingStatus.initial => _buildEmptyState(),
      LoadingStatus.loading => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: PmSpacing.lg),
            Text(S.of(context)!.restoringScans),
          ],
        ),
      ),
      LoadingStatus.loaded =>
        state.scans.isEmpty
            ? _buildEmptyState()
            : _buildLoadedState(context, state),
      LoadingStatus.error => PmErrorState(
        title: 'Error loading scans', // TODO(l10n)
        message: 'Failed to restore scanned documents',
        retryLabel: 'Retry',
        onRetry: () => context.read<DocumentScannerCubit>().initialize(),
      ),
    };
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PmSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PmEmptyState(
              icon: Icons.document_scanner_outlined,
              title: S.of(context)!.noDocumentsScannedYet,
            ),
            const SizedBox(height: PmSpacing.xl),

            // Primary CTA: Scan
            FilledButton.icon(
              onPressed: () => _openDocumentScanner(context),
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(S.of(context)!.scanADocument),
            ),

            const SizedBox(height: PmSpacing.md),

            // Secondary CTA: Upload
            ConnectivityAwareActionWrapper(
              child: OutlinedButton.icon(
                key: const Key('scanner_filesystem_upload_button'),
                onPressed: _onUploadFromFilesystem,
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(S.of(context)!.uploadADocumentFromThisDevice),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, DocumentScannerState state) {
    final scans = state.scans;
    final scanCount = scans.length;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.of(context)!.scanner),
              Text(
                '$scanCount page${scanCount == 1 ? '' : 's'}', // TODO(l10n)
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(PmSpacing.md),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 1 / sqrt(2),
              crossAxisSpacing: PmSpacing.md,
              mainAxisSpacing: PmSpacing.md,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return ScannedImageItem(
                file: scans[index],
                index: index,
                totalNumberOfFiles: scanCount,
                isSelected: _selectedIndices.contains(index),
                onTap: () => _handleTileTap(index),
                onLongPress: () => _handleTileLongPress(index),
                onDelete: () => _removeSingleScan(context, scans[index]),
              );
            }, childCount: scanCount),
          ),
        ),

        // Bottom spacing for the action bar
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  void _handleTileTap(int index) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedIndices.contains(index)) {
          _selectedIndices.remove(index);
        } else {
          _selectedIndices.add(index);
        }
      });
    }
    // else: default tap is handled by ScannedImageItem (preview)
  }

  void _handleTileLongPress(int index) {
    setState(() {
      if (!_selectedIndices.contains(index)) {
        _selectedIndices.add(index);
      }
    });
  }

  Widget? _buildBottomBar(BuildContext context, DocumentScannerState state) {
    if (_isSelectionMode) {
      return _buildSelectionBar(context, state);
    }

    return _buildActionBar(context, state);
  }

  Widget _buildSelectionBar(BuildContext context, DocumentScannerState state) {
    final selectedCount = _selectedIndices.length;

    return Material(
      elevation: PmElevations.level3,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PmSpacing.lg,
            vertical: PmSpacing.md,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedIndices.clear();
                  });
                },
              ),
              const SizedBox(width: PmSpacing.md),
              Expanded(
                child: Text(
                  '$selectedCount selected', // TODO(l10n)
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _removeSelectedScans(context, state),
                icon: const Icon(Icons.delete_outline),
                label: Text(S.of(context)!.remove),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, DocumentScannerState state) {
    return Material(
      elevation: PmElevations.level3,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Offline banner
            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: PmSpacing.lg,
                  vertical: PmSpacing.sm,
                ),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off,
                      size: 16,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: PmSpacing.sm),
                    Expanded(
                      child: Text(
                        S.of(context)!.youreOffline,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(PmSpacing.md),
              child: GlobalSettingsBuilder(
                builder: (settingsCtx, settings) {
                  final scans = state.scans;
                  final canQuickUpload =
                      scans.isNotEmpty && !_isQuickUploading && !_isOffline;
                  return Row(
                    children: [
                      // Preview
                      TextButton(
                        key: const Key('scanner_preview_button'),
                        onPressed: scans.isNotEmpty
                            ? () => _onPreviewScans(context, scans)
                            : null,
                        child: Text(S.of(context)!.previewScan),
                      ),

                      // Quick upload (when preset enabled) — kept as a visible
                      // button so it can be reached without opening the
                      // overflow menu (and so widget tests can tap it).
                      if (settings.uploadPresetEnabled) ...[
                        const SizedBox(width: PmSpacing.sm),
                        ConnectivityAwareActionWrapper(
                          disabled: scans.isEmpty || _isQuickUploading,
                          child: TextButton.icon(
                            key: const Key('scanner_quick_upload_button'),
                            onPressed: canQuickUpload
                                ? () {
                                    final presetSettings =
                                        Hive.box<GlobalSettings>(
                                          HiveBoxes.globalSettings,
                                        ).getValue()!;
                                    _onQuickUpload(
                                      context,
                                      scans,
                                      presetSettings,
                                    );
                                  }
                                : null,
                            icon: _isQuickUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.upload_outlined, size: 18),
                            label: Text(S.of(context)!.quickUpload),
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Upload (primary action)
                      Expanded(
                        flex: 2,
                        child: ConnectivityAwareActionWrapper(
                          disabled: scans.isEmpty || _isUploading,
                          child: FilledButton.icon(
                            key: const Key('scanner_upload_button'),
                            onPressed: scans.isEmpty || _isUploading
                                ? null
                                : () =>
                                      _onPrepareDocumentUpload(context, scans),
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload_outlined),
                            label: Text(S.of(context)!.upload),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // More menu
                      Builder(
                        builder: (menuAnchorCtx) {
                          final pageContext = context;
                          return PopupMenuButton<String>(
                            key: const Key('scanner_more_menu'),
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) =>
                                _handleMenuAction(pageContext, state, value),
                            itemBuilder: (menuCtx) => [
                              // Export to PDF
                              PopupMenuItem<String>(
                                key: const Key('scanner_export_button'),
                                value: 'export',
                                enabled: scans.isNotEmpty,
                                onTap: scans.isNotEmpty ? _onSaveToFile : null,
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                  ),
                                  title: Text(S.of(menuCtx)!.export),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),

                              // Clear all
                              PopupMenuItem<String>(
                                value: 'clear',
                                enabled: scans.isNotEmpty,
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.delete_sweep_outlined,
                                  ),
                                  title: Text(S.of(menuCtx)!.clearAll),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    DocumentScannerState state,
    String action,
  ) {
    switch (action) {
      case 'quick_upload':
        // Handled by PopupMenuItem.onTap to keep a stable test hook.
        break;
      case 'export':
        // Handled by PopupMenuItem.onTap to keep a stable test hook.
        break;
      case 'clear':
        _showClearAllDialog(context);
        break;
    }
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context)!.clearAll),
        content: const Text(
          'Are you sure you want to remove all scanned pages?', // TODO(l10n)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'), // TODO(l10n)
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _reset(context);
            },
            child: Text(S.of(context)!.clearAll),
          ),
        ],
      ),
    );
  }

  void _removeSingleScan(BuildContext context, File file) async {
    try {
      context.read<DocumentScannerCubit>().removeScan(file);
    } on PaperlessApiException catch (error, stackTrace) {
      showErrorMessage(context, error, stackTrace);
    } on InfoMessageException catch (error, stackTrace) {
      showInfoMessage(context, error, stackTrace);
    }
  }

  void _removeSelectedScans(
    BuildContext context,
    DocumentScannerState state,
  ) async {
    final cubit = context.read<DocumentScannerCubit>();
    final scansToRemove = _selectedIndices
        .map((index) => state.scans[index])
        .toList();

    try {
      for (final file in scansToRemove) {
        await cubit.removeScan(file);
      }
      if (!mounted) return;
      setState(() {
        _selectedIndices.clear();
      });
    } on PaperlessApiException catch (error, stackTrace) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      showErrorMessage(context, error, stackTrace);
    } on InfoMessageException catch (error, stackTrace) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      showInfoMessage(context, error, stackTrace);
    }
  }

  void _onSaveToFile() async {
    final cubit = context.read<DocumentScannerCubit>();
    final fileName = await ScannerPage.exportFilenameProvider(context);

    if (!mounted) return;
    if (fileName != null) {
      try {
        final file = await ScannerPage.scanAssembler(
          cubit.state.scans,
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
      if (images == null || images.isEmpty) {
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
    setState(() => _isUploading = true);
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
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
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
}
