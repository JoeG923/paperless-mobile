import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:image/image.dart' as im;
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/saved_view_repository.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/document_scan/cubit/document_scanner_cubit.dart';
import 'package:paperless_mobile/features/document_scan/scan_pdf_assembler.dart';
import 'package:paperless_mobile/features/document_scan/view/scanner_page.dart';
import 'package:paperless_mobile/features/document_upload/model/document_upload_result.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';
import 'package:paperless_mobile/features/saved_view/cubit/saved_view_cubit.dart';
import 'package:paperless_mobile/features/sharing/cubit/receive_share_cubit.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/upload_preset_helper.dart';
import 'package:paperless_mobile/features/notifications/services/local_notification_service.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

class _FakeTasksApi extends Fake implements PaperlessTasksApi {
  @override
  Future<Task?> find({int? id, String? taskId}) async {
    final dateCreated = DateTime.now();
    if (id != null) {
      return Task(
        id: id,
        taskId: taskId,
        taskFileName: 'upload',
        dateCreated: dateCreated,
        dateDone: dateCreated,
        status: TaskStatus.success,
      );
    }
    if (taskId == null) {
      return null;
    }
    return Task(
      id: 1,
      taskId: taskId,
      taskFileName: 'upload',
      dateCreated: dateCreated,
      dateDone: dateCreated,
      status: TaskStatus.success,
    );
  }

  @override
  Future<Iterable<Task>> findAll([Iterable<int>? ids]) async {
    if (ids == null) {
      return [];
    }
    return [
      for (final id in ids)
        Task(
          id: id,
          taskId: 'task-$id',
          taskFileName: 'upload',
          dateCreated: DateTime.now(),
          dateDone: DateTime.now(),
          status: TaskStatus.success,
        ),
    ];
  }

  @override
  Stream<Task> listenForTaskChanges(String taskId) async* {
    yield Task(
      id: 1,
      taskId: taskId,
      taskFileName: 'upload',
      dateCreated: DateTime.now(),
      dateDone: DateTime.now(),
      status: TaskStatus.success,
    );
  }

  @override
  Future<Task> acknowledgeTask(Task task) async => task;

  @override
  Future<Iterable<Task>> acknowledgeTasks(Iterable<Task> tasks) async => tasks;
}

class _NoopDocumentsApi extends Fake implements PaperlessDocumentsApi {}

class _NoopSavedViewsApi extends Fake implements PaperlessSavedViewsApi {}

class _RecordingSuccessDocumentsApi extends Fake
    implements PaperlessDocumentsApi {
  int createCallCount = 0;
  Uint8List? lastBytes;
  String? lastFilename;
  String? lastTitle;
  int? lastDocumentType;
  int? lastCorrespondent;
  int? lastStoragePath;
  List<int>? lastTags;
  DateTime? lastCreatedAt;

  @override
  Future<String?> create(
    Uint8List documentBytes, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    createCallCount += 1;
    lastBytes = documentBytes;
    lastFilename = filename;
    lastTitle = title;
    lastDocumentType = documentType;
    lastCorrespondent = correspondent;
    lastStoragePath = storagePath;
    lastTags = tags.toList();
    lastCreatedAt = createdAt;
    return 'task-1';
  }

  @override
  Future<String?> createFromFile(
    String filePath, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    throw StateError(
      'Unexpected createFromFile call in scanner quick upload test',
    );
  }
}

class _SlowSuccessDocumentsApi extends Fake implements PaperlessDocumentsApi {
  int createCallCount = 0;

  @override
  Future<String?> create(
    Uint8List documentBytes, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    createCallCount += 1;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return 'task-2';
  }

  @override
  Future<String?> createFromFile(
    String filePath, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    throw StateError(
      'Unexpected createFromFile call in scanner quick upload test',
    );
  }
}

class _FailingDocumentsApi extends Fake implements PaperlessDocumentsApi {
  int createCallCount = 0;

  @override
  Future<String?> create(
    Uint8List documentBytes, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    createCallCount += 1;
    throw const PaperlessApiException(ErrorCode.requestTimedOut);
  }

  @override
  Future<String?> createFromFile(
    String filePath, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    throw StateError(
      'Unexpected createFromFile call in scanner quick upload test',
    );
  }
}

class _RecordingTasksNotifier extends PendingTasksNotifier {
  final List<String> listenedTaskIds = [];

  _RecordingTasksNotifier() : super(_FakeTasksApi());

  @override
  void listenToTaskChanges(String taskId) {
    listenedTaskIds.add(taskId);
  }
}

class _RecordingScannerCubit extends DocumentScannerCubit {
  _RecordingScannerCubit(super.notificationService, {this.throwOnSave = false});

  int saveToFileCallCount = 0;
  Uint8List? lastSavedBytes;
  String? lastSavedFileName;
  String? lastSavedLocale;
  final bool throwOnSave;

  @override
  Future<void> saveToFile(
    Uint8List bytes,
    String fileName,
    String locale,
  ) async {
    saveToFileCallCount += 1;
    lastSavedBytes = bytes;
    lastSavedFileName = fileName;
    lastSavedLocale = locale;
    if (throwOnSave) {
      throw Exception('write to file failed');
    }
  }
}

class _FakeDocumentScanner extends Fake implements DocumentScanner {
  _FakeDocumentScanner({required this.scanResult, this.throwOnScan});

  final DocumentScanningResult scanResult;
  final Object? throwOnScan;

  int scanCallCount = 0;
  int closeCallCount = 0;
  Object? lastScanError;

  @override
  final String id = 'fake-scanner';

  @override
  final DocumentScannerOptions options = DocumentScannerOptions();

  @override
  Future<DocumentScanningResult> scanDocument() async {
    scanCallCount += 1;
    if (throwOnScan != null) {
      lastScanError = throwOnScan;
      if (throwOnScan is Exception) {
        throw throwOnScan as Exception;
      }
      throw Exception(throwOnScan.toString());
    }
    return scanResult;
  }

  @override
  Future<void> close() async {
    closeCallCount += 1;
  }
}

Future<bool> _pressQuickUpload(WidgetTester tester) async {
  final quickUploadButton = find.byKey(
    const Key('scanner_quick_upload_button'),
  );
  expect(quickUploadButton, findsOneWidget);
  final widget = tester.widget<TextButton>(quickUploadButton);
  final onPressed = widget.onPressed;
  if (onPressed == null) {
    return false;
  }
  await tester.runAsync(() async {
    onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
  return true;
}

Future<bool> _pressPreview(WidgetTester tester) async {
  final previewButton = find.byKey(const Key('scanner_preview_button'));
  expect(previewButton, findsOneWidget);
  final widget = tester.widget<TextButton>(previewButton);
  final onPressed = widget.onPressed;
  if (onPressed == null) {
    return false;
  }
  await tester.runAsync(() async {
    onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
  return true;
}

Future<bool> _pressPrepareUpload(WidgetTester tester) async {
  final uploadButton = find.byKey(const Key('scanner_upload_button'));
  expect(uploadButton, findsOneWidget);
  final widget = tester.widget<FilledButton>(uploadButton);
  final onPressed = widget.onPressed;
  if (onPressed == null) {
    return false;
  }
  await tester.runAsync(() async {
    onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
  return true;
}

Future<bool> _pressFilesystemUpload(WidgetTester tester) async {
  final uploadFromFilesystemButton = find.byKey(
    const Key('scanner_filesystem_upload_button'),
  );
  expect(uploadFromFilesystemButton, findsOneWidget);
  final widget = tester.widget<OutlinedButton>(uploadFromFilesystemButton);
  final onPressed = widget.onPressed;
  if (onPressed == null) {
    return false;
  }
  await tester.runAsync(() async {
    onPressed();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
  return true;
}

Future<ScannedAssembledFile> _assembleTestScans(
  List<File> files, {
  bool forcePdf = false,
}) async {
  if (files.isEmpty) {
    throw ArgumentError('At least one scanned file is required');
  }
  final assembled = ScannedAssembledFile(
    extension: '.pdf',
    bytes: files.first.readAsBytesSync(),
  );
  return assembled;
}

Future<File> _createScanFile({
  required Directory dir,
  required String name,
}) async {
  final file = File('${dir.path}/$name.jpg');
  file.writeAsBytesSync(List<int>.generate(8, (i) => i), flush: true);
  return file;
}

TemporaryScanFileAllocator _createTemporaryScanAllocator(Directory dir) {
  var fileCounter = 0;
  return ({required String extension, required bool create}) async {
    final file = File('${dir.path}/scanner_temp_${fileCounter++}.$extension');
    if (create) {
      await file.create(recursive: true);
    }
    return file;
  };
}

Future<File> _createValidScanFile({
  required Directory dir,
  required String name,
  String extension = 'jpg',
}) async {
  final image = im.Image(width: 10, height: 10);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 255, 255, 255, 255);
    }
  }
  final bytes = extension.toLowerCase() == 'jpg'
      ? im.encodeJpg(image)
      : im.encodePng(image);
  final file = File('${dir.path}/$name.$extension');
  file.writeAsBytesSync(bytes, flush: true);
  return file;
}

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  registerHiveAdapters();
  await Hive.openBox<GlobalSettings>(HiveBoxes.globalSettings);
  await Hive.openBox<LocalUserAccount>(HiveBoxes.localUserAccount);
}

Future<void> _setGlobalSettings(GlobalSettings settings) async {
  await Hive.box<GlobalSettings>(HiveBoxes.globalSettings).setValue(settings);
}

Future<void> _seedAccount(LocalUserAccount account) async {
  final accountBox = Hive.box<LocalUserAccount>(HiveBoxes.localUserAccount);
  await accountBox.put(account.id, account);
}

Future<void> _pumpScannerPage(
  WidgetTester tester, {
  required DocumentScannerCubit scannerCubit,
  required PaperlessDocumentsApi documentsApi,
  required ConnectivityStatusService connectivity,
  required _RecordingTasksNotifier tasksNotifier,
  required SavedViewCubit savedViewCubit,
  required DocumentsCubit documentsCubit,
  required LocalUserAccount account,
  ScanAssembler? scanAssembler,
  PreviewRouteProvider? previewRouteProvider,
  PermissionRequestProvider? permissionRequestProvider,
  DocumentScannerFactory? documentScannerFactory,
  DocumentScannerScanProvider? documentScannerScanProvider,
  DocumentScannerCloseProvider? documentScannerCloseProvider,
  PlatformIsAndroidProvider? platformIsAndroidProvider,
  FilePickerProvider? filePickerProvider,
  FilesystemUploadRouteProvider? filesystemUploadRouteProvider,
  ExportFilenameProvider? exportFilenameProvider,
  DocumentUploadRouteProvider? documentUploadRouteProvider,
  TemporaryScanFileAllocator? temporaryScanFileAllocator,
  ScannedFileCopier? scannedFileCopier,
}) async {
  ScanAssembler? previousScanAssembler;
  if (scanAssembler != null) {
    previousScanAssembler = ScannerPage.scanAssembler;
    ScannerPage.scanAssembler = scanAssembler;
    addTearDown(() {
      if (previousScanAssembler != null) {
        ScannerPage.scanAssembler = previousScanAssembler;
      } else {
        ScannerPage.scanAssembler = assembleScannedFiles;
      }
    });
  }
  ExportFilenameProvider? previousExportFilenameProvider;
  if (exportFilenameProvider != null) {
    previousExportFilenameProvider = ScannerPage.exportFilenameProvider;
    ScannerPage.exportFilenameProvider = exportFilenameProvider;
    addTearDown(() {
      ScannerPage.exportFilenameProvider = previousExportFilenameProvider!;
    });
  }
  PreviewRouteProvider? previousPreviewRouteProvider;
  if (previewRouteProvider != null) {
    previousPreviewRouteProvider = ScannerPage.previewRouteProvider;
    ScannerPage.previewRouteProvider = previewRouteProvider;
    addTearDown(() {
      ScannerPage.previewRouteProvider = previousPreviewRouteProvider!;
    });
  }
  PermissionRequestProvider? previousPermissionRequestProvider;
  if (permissionRequestProvider != null) {
    previousPermissionRequestProvider = ScannerPage.permissionRequestProvider;
    ScannerPage.permissionRequestProvider = permissionRequestProvider;
    addTearDown(() {
      ScannerPage.permissionRequestProvider =
          previousPermissionRequestProvider!;
    });
  }
  DocumentScannerFactory? previousDocumentScannerFactory;
  if (documentScannerFactory != null) {
    previousDocumentScannerFactory = ScannerPage.documentScannerFactory;
    ScannerPage.documentScannerFactory = documentScannerFactory;
    addTearDown(() {
      ScannerPage.documentScannerFactory = previousDocumentScannerFactory!;
    });
  }
  DocumentScannerScanProvider? previousDocumentScannerScanProvider;
  if (documentScannerScanProvider != null) {
    previousDocumentScannerScanProvider =
        ScannerPage.documentScannerScanProvider;
    ScannerPage.documentScannerScanProvider = documentScannerScanProvider;
    addTearDown(() {
      ScannerPage.documentScannerScanProvider =
          previousDocumentScannerScanProvider!;
    });
  }
  DocumentScannerCloseProvider? previousDocumentScannerCloseProvider;
  if (documentScannerCloseProvider != null) {
    previousDocumentScannerCloseProvider =
        ScannerPage.documentScannerCloseProvider;
    ScannerPage.documentScannerCloseProvider = documentScannerCloseProvider;
    addTearDown(() {
      ScannerPage.documentScannerCloseProvider =
          previousDocumentScannerCloseProvider!;
    });
  }
  PlatformIsAndroidProvider? previousPlatformIsAndroidProvider;
  if (platformIsAndroidProvider != null) {
    previousPlatformIsAndroidProvider = ScannerPage.platformIsAndroidProvider;
    ScannerPage.platformIsAndroidProvider = platformIsAndroidProvider;
    addTearDown(() {
      ScannerPage.platformIsAndroidProvider =
          previousPlatformIsAndroidProvider!;
    });
  }
  TemporaryScanFileAllocator? previousTemporaryScanFileAllocator;
  if (temporaryScanFileAllocator != null) {
    previousTemporaryScanFileAllocator = ScannerPage.temporaryScanFileAllocator;
    ScannerPage.temporaryScanFileAllocator = temporaryScanFileAllocator;
    addTearDown(() {
      ScannerPage.temporaryScanFileAllocator =
          previousTemporaryScanFileAllocator!;
    });
  }
  ScannedFileCopier? previousScannedFileCopier;
  if (scannedFileCopier != null) {
    previousScannedFileCopier = ScannerPage.scannedFileCopier;
    ScannerPage.scannedFileCopier = scannedFileCopier;
    addTearDown(() {
      ScannerPage.scannedFileCopier = previousScannedFileCopier!;
    });
  }
  FilePickerProvider? previousFilePickerProvider;
  if (filePickerProvider != null) {
    previousFilePickerProvider = ScannerPage.filePickerProvider;
    ScannerPage.filePickerProvider = filePickerProvider;
    addTearDown(() {
      ScannerPage.filePickerProvider = previousFilePickerProvider!;
    });
  }
  FilesystemUploadRouteProvider? previousFilesystemUploadRouteProvider;
  if (filesystemUploadRouteProvider != null) {
    previousFilesystemUploadRouteProvider =
        ScannerPage.filesystemUploadRouteProvider;
    ScannerPage.filesystemUploadRouteProvider = filesystemUploadRouteProvider;
    addTearDown(() {
      ScannerPage.filesystemUploadRouteProvider =
          previousFilesystemUploadRouteProvider!;
    });
  }
  DocumentUploadRouteProvider? previousDocumentUploadRouteProvider;
  if (documentUploadRouteProvider != null) {
    previousDocumentUploadRouteProvider =
        ScannerPage.documentUploadRouteProvider;
    ScannerPage.documentUploadRouteProvider = documentUploadRouteProvider;
    addTearDown(() {
      ScannerPage.documentUploadRouteProvider =
          previousDocumentUploadRouteProvider!;
    });
  }
  tester.view.physicalSize = const Size(1440, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<DocumentScannerCubit>.value(value: scannerCubit),
        BlocProvider<SavedViewCubit>.value(value: savedViewCubit),
        BlocProvider<DocumentsCubit>.value(value: documentsCubit),
      ],
      child: MultiProvider(
        providers: [
          Provider<LocalUserAccount>.value(value: account),
          Provider<PaperlessDocumentsApi>.value(value: documentsApi),
          ChangeNotifierProvider<PendingTasksNotifier>.value(
            value: tasksNotifier,
          ),
          ChangeNotifierProvider<ConsumptionChangeNotifier>.value(
            value: ConsumptionChangeNotifier(),
          ),
          Provider<ConnectivityStatusService>.value(value: connectivity),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: const ScannerPage(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late Directory tempDir;
  late Directory scansDir;
  late LocalUserAccount account;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('scanner_page_test_');
    await _initHive(tempDir);
    account = LocalUserAccount(
      id: '1',
      serverUrl: 'https://example.com',
      settings: LocalUserSettings(),
      paperlessUser: UserModelV3(
        id: 1,
        username: 'tester',
        email: 'tester@example.com',
        firstName: 'Test',
        lastName: 'User',
        dateJoined: DateTime(2025, 1, 1),
        isStaff: false,
        isActive: true,
        isSuperuser: false,
        groups: const [],
        userPermissions: const [
          'view_document',
          'view_tag',
          'view_document_type',
          'view_correspondent',
          'view_storage_path',
        ],
        inheritedPermissions: const [],
      ),
      apiVersion: 3,
    );
    await _seedAccount(account);
    await _setGlobalSettings(
      GlobalSettings(preferredLocaleSubtag: 'en', uploadPresetEnabled: true),
    );
  });

  setUp(() async {
    scansDir = await Directory(
      '${tempDir.path}/paperless_scans',
    ).create(recursive: true);
    final previousAllocator = ScannerPage.temporaryScanFileAllocator;
    final previousCopier = ScannerPage.scannedFileCopier;
    ScannerPage.temporaryScanFileAllocator = _createTemporaryScanAllocator(
      scansDir,
    );
    ScannerPage.scannedFileCopier = (sourcePath, destinationPath) async {
      final bytes = await File(sourcePath).readAsBytes();
      await File(destinationPath).writeAsBytes(bytes, flush: true);
    };
    addTearDown(() {
      ScannerPage.temporaryScanFileAllocator = previousAllocator;
      ScannerPage.scannedFileCopier = previousCopier;
    });
  });

  tearDown(() async {
    if (scansDir.existsSync()) {
      await scansDir.delete(recursive: true);
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('quick upload sends scan upload with preset metadata', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(
          preferredLocaleSubtag: 'en',
          uploadPresetEnabled: true,
          uploadPresetTitleTemplate: 'Invoice',
          uploadPresetUseCurrentDate: false,
          uploadPresetCorrespondentId: 17,
          uploadPresetDocumentTypeId: 42,
          uploadPresetStoragePathId: 99,
          uploadPresetTagIds: const [7, 8],
        ),
      ),
    );

    testWidgets('quick upload sends scan upload with preset metadata', (
      WidgetTester tester,
    ) async {
      final scan = await _createScanFile(dir: scansDir, name: 'scan_one');
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final api = _RecordingSuccessDocumentsApi();
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      scannerCubit.addScan(scan);
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: api,
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
      );

      await _pressQuickUpload(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(api.createCallCount, 1);
      expect(api.lastTitle, 'Invoice');
      expect(api.lastFilename, '${formatFilename('Invoice')}.jpg');
      expect(api.lastCorrespondent, 17);
      expect(api.lastDocumentType, 42);
      expect(api.lastStoragePath, 99);
      expect(api.lastTags, [7, 8]);
      expect(api.lastCreatedAt, isNull);
      expect(api.lastBytes, isNotNull);
      expect(tasksNotifier.listenedTaskIds, ['task-1']);
      expect(scannerCubit.state.scans, isEmpty);
      expect(
        find.text('Document successfully uploaded, processing...'),
        findsOneWidget,
      );
    });
  });

  group('quick upload is blocked while offline', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(preferredLocaleSubtag: 'en', uploadPresetEnabled: true),
      ),
    );

    testWidgets(
      'quick upload is blocked while offline and does not start upload',
      (WidgetTester tester) async {
        final scan = await _createScanFile(dir: scansDir, name: 'scan_offline');
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final api = _RecordingSuccessDocumentsApi();
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(false),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: api,
          connectivity: ConnectivityStatusServiceMock(false),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
        );

        final quickUploadPressed = await _pressQuickUpload(tester);
        expect(quickUploadPressed, isFalse);
        await tester.tap(
          find.ancestor(
            of: find.byKey(const Key('scanner_quick_upload_button')),
            matching: find.byType(GestureDetector),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();

        expect(api.createCallCount, 0);
      },
    );
  });

  group('quick upload button visibility', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(preferredLocaleSubtag: 'en', uploadPresetEnabled: false),
      ),
    );

    testWidgets(
      'quick upload button is only visible when upload preset is enabled',
      (WidgetTester tester) async {
        final scan = await _createScanFile(dir: scansDir, name: 'scan_hidden');
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final api = _RecordingSuccessDocumentsApi();
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: api,
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
        );

        expect(find.text('Quick upload'), findsNothing);
        expect(api.createCallCount, 0);
      },
    );
  });

  group('quick upload tap guard', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(
          preferredLocaleSubtag: 'en',
          uploadPresetEnabled: true,
          uploadPresetUseCurrentDate: false,
        ),
      ),
    );

    testWidgets('quick upload ignores subsequent taps while running', (
      WidgetTester tester,
    ) async {
      final scan = await _createScanFile(dir: scansDir, name: 'scan_tap_guard');
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final api = _SlowSuccessDocumentsApi();
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      scannerCubit.addScan(scan);
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: api,
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
      );

      await _pressQuickUpload(tester);
      await tester.pump();
      await _pressQuickUpload(tester);
      await tester.pump();

      expect(api.createCallCount, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.createCallCount, 1);
      expect(tasksNotifier.listenedTaskIds, ['task-2']);
    });
  });

  group('quick upload failure flow', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(
          preferredLocaleSubtag: 'en',
          uploadPresetEnabled: true,
          uploadPresetUseCurrentDate: false,
          uploadPresetTitleTemplate: 'Invoice',
        ),
      ),
    );

    testWidgets('quick upload keeps scans if upload fails and reports error', (
      WidgetTester tester,
    ) async {
      final scan = await _createScanFile(dir: scansDir, name: 'scan_fail');
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final api = _FailingDocumentsApi();
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      scannerCubit.addScan(scan);
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: api,
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
      );

      await _pressQuickUpload(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 4));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(api.createCallCount, 3);
      expect(scannerCubit.state.scans, isNotEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('quick upload corrupted scan handling', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(
          preferredLocaleSubtag: 'en',
          uploadPresetEnabled: true,
          uploadPresetTitleTemplate: 'Invoice',
          uploadPresetUseCurrentDate: false,
          enforceSinglePagePdfUpload: true,
        ),
      ),
    );

    testWidgets(
      'quick upload keeps scans and reports parse error when assembling corrupt image',
      (WidgetTester tester) async {
        final scan = await _createScanFile(dir: scansDir, name: 'scan_corrupt');
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final api = _RecordingSuccessDocumentsApi();
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: api,
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
        );

        final pressed = await _pressQuickUpload(tester);
        expect(pressed, isTrue);
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();

        expect(api.createCallCount, 0);
        expect(scannerCubit.state.scans, isNotEmpty);
        expect(
          scannerCubit.state.scans.first.path,
          endsWith('scan_corrupt.jpg'),
        );
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });

  group('quick upload single-page pdf', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(
          preferredLocaleSubtag: 'en',
          uploadPresetEnabled: true,
          enforceSinglePagePdfUpload: true,
          uploadPresetTitleTemplate: 'Invoice',
        ),
      ),
    );

    testWidgets(
      'quick upload enforces single-page pdf extension when configured',
      (WidgetTester tester) async {
        final scan = await _createValidScanFile(
          dir: scansDir,
          name: 'scan_pdf',
          extension: 'jpg',
        );
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final api = _RecordingSuccessDocumentsApi();
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: api,
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
        );

        await _pressQuickUpload(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(api.createCallCount, 1);
        expect(api.lastFilename, isNotNull);
        expect(api.lastBytes, isNotNull);
        expect(api.lastFilename!.endsWith('.pdf'), isTrue);
        expect(api.lastBytes![0], equals(0x25));
        expect(api.lastBytes![1], equals(0x50));
        expect(api.lastBytes![2], equals(0x44));
        expect(api.lastBytes![3], equals(0x46));
      },
    );
  });

  group('prepare upload handoff', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(
          preferredLocaleSubtag: 'en',
          uploadPresetEnabled: false,
          enforceSinglePagePdfUpload: true,
        ),
      ),
    );

    testWidgets(
      'prepare upload forwards assembled file to upload route and resets on success',
      (WidgetTester tester) async {
        final scan = await _createValidScanFile(
          dir: scansDir,
          name: 'scan_prepare_success',
          extension: 'jpg',
        );
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        ScannedAssembledFile? capturedFile;
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          scanAssembler: (files, {forcePdf = false}) async =>
              ScannedAssembledFile(
                extension: forcePdf ? '.pdf' : '.jpg',
                bytes: Uint8List.fromList([9, 8, 7]),
              ),
          documentUploadRouteProvider: (context, file) async {
            capturedFile = file;
            return const DocumentUploadResult.success('task-1');
          },
        );

        final pressed = await _pressPrepareUpload(tester);
        expect(pressed, isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(capturedFile, isNotNull);
        expect(capturedFile!.extension, '.pdf');
        expect(capturedFile!.bytes, equals(Uint8List.fromList([9, 8, 7])));
        expect(scannerCubit.state.scans, isEmpty);
        expect(tasksNotifier.listenedTaskIds, ['task-1']);
      },
    );

    testWidgets(
      'prepare upload keeps scans and shows error when upload route throws',
      (WidgetTester tester) async {
        final scan = await _createValidScanFile(
          dir: scansDir,
          name: 'scan_prepare_route_error',
          extension: 'jpg',
        );
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          documentUploadRouteProvider: (context, file) async {
            throw Exception('route failed');
          },
        );

        final pressed = await _pressPrepareUpload(tester);
        expect(pressed, isTrue);
        await tester.pump();

        expect(scannerCubit.state.scans, isNotEmpty);
        expect(tasksNotifier.listenedTaskIds, isEmpty);
        expect(find.text('Exception: route failed'), findsOneWidget);
      },
    );

    testWidgets(
      'prepare upload resets scans on success even without a task id',
      (WidgetTester tester) async {
        final scan = await _createValidScanFile(
          dir: scansDir,
          name: 'scan_prepare_taskless',
          extension: 'jpg',
        );
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          documentUploadRouteProvider: (context, file) async =>
              const DocumentUploadResult.success('   '),
        );

        final pressed = await _pressPrepareUpload(tester);
        expect(pressed, isTrue);
        await tester.pump();

        expect(scannerCubit.state.scans, isEmpty);
        expect(tasksNotifier.listenedTaskIds, isEmpty);
      },
    );

    testWidgets('prepare upload keeps scans when upload returns failure', (
      WidgetTester tester,
    ) async {
      final scan = await _createValidScanFile(
        dir: scansDir,
        name: 'scan_prepare_fail',
        extension: 'jpg',
      );
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      bool calledRoute = false;
      scannerCubit.addScan(scan);
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        documentUploadRouteProvider: (context, file) async {
          calledRoute = true;
          return DocumentUploadResult.failure(
            const PaperlessApiException(ErrorCode.requestTimedOut),
          );
        },
      );

      final pressed = await _pressPrepareUpload(tester);
      expect(pressed, isTrue);
      await tester.pump();

      expect(calledRoute, isTrue);
      expect(scannerCubit.state.scans, isNotEmpty);
      expect(tasksNotifier.listenedTaskIds, isEmpty);
    });

    testWidgets('prepare upload keeps scans when upload is cancelled', (
      WidgetTester tester,
    ) async {
      final scan = await _createValidScanFile(
        dir: scansDir,
        name: 'scan_prepare_cancel',
        extension: 'jpg',
      );
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      scannerCubit.addScan(scan);
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        documentUploadRouteProvider: (context, file) async =>
            const DocumentUploadResult.cancelled(),
      );

      final pressed = await _pressPrepareUpload(tester);
      expect(pressed, isTrue);
      await tester.pump();

      expect(scannerCubit.state.scans, isNotEmpty);
      expect(tasksNotifier.listenedTaskIds, isEmpty);
    });

    testWidgets(
      'prepare upload keeps scans and shows error when assembler fails',
      (WidgetTester tester) async {
        final scan = await _createValidScanFile(
          dir: scansDir,
          name: 'scan_prepare_assemble_fail',
          extension: 'jpg',
        );
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        bool routeCalled = false;
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          scanAssembler: (files, {forcePdf = false}) async =>
              throw Exception('scan assemble failed'),
          documentUploadRouteProvider: (context, file) async {
            routeCalled = true;
            return const DocumentUploadResult.success('task-1');
          },
        );

        final pressed = await _pressPrepareUpload(tester);
        expect(pressed, isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(routeCalled, isFalse);
        expect(scannerCubit.state.scans, isNotEmpty);
        expect(find.text('Exception: scan assemble failed'), findsOneWidget);
      },
    );

    testWidgets('prepare upload is disabled when no scans exist', (
      WidgetTester tester,
    ) async {
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
      );

      final pressed = await _pressPrepareUpload(tester);
      expect(pressed, isFalse);
      expect(tasksNotifier.listenedTaskIds, isEmpty);
    });
  });

  group('document scanner guardrails', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(preferredLocaleSubtag: 'en', uploadPresetEnabled: false),
      ),
    );

    testWidgets('scan a document button blocks non-android camera scanning', (
      WidgetTester tester,
    ) async {
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        scanAssembler: _assembleTestScans,
      );

      await tester.tap(find.byKey(const Key('scanner_empty_scan_button')));
      await tester.pump();

      expect(
        find.text('Document scanning is currently available on Android only.'),
        findsOneWidget,
      );
    });

    testWidgets('scan flow is blocked when permission is denied', (
      WidgetTester tester,
    ) async {
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      bool scannerFactoryCalled = false;
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        permissionRequestProvider: (permission) async => false,
        platformIsAndroidProvider: () => true,
        documentScannerFactory: () async {
          scannerFactoryCalled = true;
          return _FakeDocumentScanner(
            scanResult: DocumentScanningResult(images: [], pdf: null),
          );
        },
      );

      await tester.tap(find.byKey(const Key('scanner_empty_scan_button')));
      await tester.pump();

      expect(scannerFactoryCalled, isFalse);
      expect(scannerCubit.state.scans, isEmpty);
    });

    testWidgets('scan flow with empty results keeps scan list unchanged', (
      WidgetTester tester,
    ) async {
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      final fakeScanner = _FakeDocumentScanner(
        scanResult: DocumentScanningResult(images: [], pdf: null),
      );
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        permissionRequestProvider: (_) async => true,
        platformIsAndroidProvider: () => true,
        documentScannerFactory: () async => fakeScanner,
      );

      await tester.tap(find.byKey(const Key('scanner_empty_scan_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeScanner.scanCallCount, 1);
      expect(fakeScanner.closeCallCount, 1);
      expect(scannerCubit.state.scans, isEmpty);
    });

    testWidgets('scan flow handles scan exceptions without adding scans', (
      WidgetTester tester,
    ) async {
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      final fakeScanner = _FakeDocumentScanner(
        scanResult: DocumentScanningResult(images: [], pdf: null),
        throwOnScan: Exception('scan failed'),
      );
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        permissionRequestProvider: (_) async => true,
        platformIsAndroidProvider: () => true,
        documentScannerFactory: () async => fakeScanner,
      );

      await tester.tap(find.byKey(const Key('scanner_empty_scan_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeScanner.scanCallCount, 1);
      expect(fakeScanner.closeCallCount, 1);
      expect(scannerCubit.state.scans, isEmpty);
      expect(find.text('Exception: scan failed'), findsOneWidget);
    });

    testWidgets(
      'scan flow with scan results passes source path and extension to copier',
      (WidgetTester tester) async {
        final sourceScan = File('${scansDir.path}/scan_result.png');
        sourceScan.writeAsBytesSync([10, 11, 12, 13], flush: true);
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        final fakeScanner = _FakeDocumentScanner(
          scanResult: DocumentScanningResult(
            images: [sourceScan.path],
            pdf: null,
          ),
        );
        String? allocatedExtension;
        String? copiedSourcePath;
        String? copiedDestinationPath;
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          permissionRequestProvider: (_) async => true,
          platformIsAndroidProvider: () => true,
          documentScannerFactory: () async => fakeScanner,
          documentScannerScanProvider: (scanner) => scanner.scanDocument(),
          temporaryScanFileAllocator: ({required extension, required create}) {
            allocatedExtension = extension;
            return Future.value(
              File('${scansDir.path}/scan_handoff_destination.$extension'),
            );
          },
          scannedFileCopier: (sourcePath, destinationPath) async {
            copiedSourcePath = sourcePath;
            copiedDestinationPath = destinationPath;
            await File(destinationPath).writeAsBytes([1, 2, 3], flush: true);
          },
        );

        await tester.tap(find.byKey(const Key('scanner_empty_scan_button')));
        await tester.pump();
        for (var i = 0; i < 20 && copiedDestinationPath == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(fakeScanner.scanCallCount, 1);
        expect(allocatedExtension, 'png');
        expect(copiedSourcePath, sourceScan.path);
        expect(copiedDestinationPath, isNotNull);
        expect(p.extension(copiedDestinationPath!), '.png');
      },
    );

    testWidgets(
      'scan flow without extension falls back to jpg when copying scan result',
      (WidgetTester tester) async {
        final sourceScan = File('${scansDir.path}/scan_no_extension');
        sourceScan.writeAsBytesSync([1, 2, 3, 4], flush: true);
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        final fakeScanner = _FakeDocumentScanner(
          scanResult: DocumentScanningResult(
            images: [sourceScan.path],
            pdf: null,
          ),
        );
        String? allocatedExtension;
        String? copiedDestinationPath;
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          permissionRequestProvider: (_) async => true,
          platformIsAndroidProvider: () => true,
          documentScannerFactory: () async => fakeScanner,
          documentScannerScanProvider: (scanner) => scanner.scanDocument(),
          temporaryScanFileAllocator: ({required extension, required create}) {
            allocatedExtension = extension;
            return Future.value(
              File('${scansDir.path}/scan_handoff_no_extension.$extension'),
            );
          },
          scannedFileCopier: (sourcePath, destinationPath) async {
            copiedDestinationPath = destinationPath;
            final bytes = await File(sourcePath).readAsBytes();
            await File(destinationPath).writeAsBytes(bytes, flush: true);
          },
        );

        await tester.tap(find.byKey(const Key('scanner_empty_scan_button')));
        await tester.pump();
        for (var i = 0; i < 20 && copiedDestinationPath == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(fakeScanner.scanCallCount, 1);
        expect(allocatedExtension, 'jpg');
        expect(copiedDestinationPath, isNotNull);
        expect(p.extension(copiedDestinationPath!), '.jpg');
      },
    );

    testWidgets('scan flow reports copier failures and keeps scans unchanged', (
      WidgetTester tester,
    ) async {
      final sourceScan = File('${scansDir.path}/scan_copy_fail.png');
      sourceScan.writeAsBytesSync([5, 6, 7], flush: true);
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      final fakeScanner = _FakeDocumentScanner(
        scanResult: DocumentScanningResult(
          images: [sourceScan.path],
          pdf: null,
        ),
      );
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        permissionRequestProvider: (_) async => true,
        platformIsAndroidProvider: () => true,
        documentScannerFactory: () async => fakeScanner,
        documentScannerScanProvider: (scanner) => scanner.scanDocument(),
        scannedFileCopier: (sourcePath, destinationPath) async {
          throw Exception('copy failed');
        },
      );

      await tester.tap(find.byKey(const Key('scanner_empty_scan_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(fakeScanner.scanCallCount, 1);
      expect(fakeScanner.closeCallCount, 1);
      expect(scannerCubit.state.scans, isEmpty);
      expect(find.text('Exception: copy failed'), findsOneWidget);
    });

    testWidgets(
      'scan flow tolerates scanner close failure after successful copy',
      (WidgetTester tester) async {
        final sourceScan = File('${scansDir.path}/scan_close_fail.png');
        sourceScan.writeAsBytesSync([9, 8, 7], flush: true);
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        final fakeScanner = _FakeDocumentScanner(
          scanResult: DocumentScanningResult(
            images: [sourceScan.path],
            pdf: null,
          ),
        );
        String? copiedDestinationPath;
        var closeProviderCalled = false;
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          permissionRequestProvider: (_) async => true,
          platformIsAndroidProvider: () => true,
          documentScannerFactory: () async => fakeScanner,
          documentScannerScanProvider: (scanner) => scanner.scanDocument(),
          documentScannerCloseProvider: (scanner) async {
            closeProviderCalled = true;
            throw Exception('scanner close failed');
          },
          scannedFileCopier: (sourcePath, destinationPath) async {
            copiedDestinationPath = destinationPath;
            final bytes = File(sourcePath).readAsBytesSync();
            File(destinationPath).writeAsBytesSync(bytes, flush: true);
          },
        );

        await tester.tap(find.byKey(const Key('scanner_empty_scan_button')));
        await tester.pump();
        for (
          var i = 0;
          i < 20 && (copiedDestinationPath == null || !closeProviderCalled);
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(fakeScanner.scanCallCount, 1);
        expect(copiedDestinationPath, isNotNull);
        expect(closeProviderCalled, isTrue);
      },
    );
  });

  group('preview handoff', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(preferredLocaleSubtag: 'en', uploadPresetEnabled: false),
      ),
    );

    testWidgets(
      'preview handoff assembles scans as PDF and calls preview seam',
      (WidgetTester tester) async {
        final scan = await _createValidScanFile(
          dir: scansDir,
          name: 'preview_scan',
          extension: 'jpg',
        );
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        List<File>? capturedScans;
        bool forcePdfRequested = false;
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          scanAssembler: (files, {forcePdf = false}) async {
            forcePdfRequested = forcePdf;
            return ScannedAssembledFile(
              extension: forcePdf ? '.pdf' : '.jpg',
              bytes: Uint8List.fromList([1, 2, 3]),
            );
          },
          previewRouteProvider: (context, scans) async {
            capturedScans = scans;
            await ScannerPage.scanAssembler(scans, forcePdf: true);
          },
        );

        final pressed = await _pressPreview(tester);
        expect(pressed, isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(capturedScans, isNotEmpty);
        expect(capturedScans?.first.path, scan.path);
        expect(forcePdfRequested, isTrue);
        expect(scannerCubit.state.scans, isNotEmpty);
      },
    );

    testWidgets(
      'preview handoff shows generic error when preview assembly fails',
      (WidgetTester tester) async {
        final scan = await _createValidScanFile(
          dir: scansDir,
          name: 'preview_scan_fail',
          extension: 'jpg',
        );
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          scanAssembler: (files, {forcePdf = false}) async =>
              throw Exception('preview assemble failed'),
          previewRouteProvider: (context, scans) async {
            await ScannerPage.scanAssembler(scans, forcePdf: true);
          },
        );

        final pressed = await _pressPreview(tester);
        expect(pressed, isTrue);
        await tester.pump();

        expect(find.text('Exception: preview assemble failed'), findsOneWidget);
        expect(scannerCubit.state.scans, isNotEmpty);
      },
    );
  });

  group('filesystem upload handoff', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(preferredLocaleSubtag: 'en', uploadPresetEnabled: false),
      ),
    );

    testWidgets('filesystem handoff passes file payload to upload route', (
      WidgetTester tester,
    ) async {
      final sourceFile = await _createValidScanFile(
        dir: scansDir,
        name: 'filesystem_scan',
        extension: 'jpg',
      );
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      bool uploadCalled = false;
      Uint8List? capturedBytes;
      String? capturedFilename;
      String? capturedExtension;
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        filePickerProvider: ({allowedExtensions = const []}) async =>
            sourceFile.path,
        filesystemUploadRouteProvider:
            (context, fileBytes, filename, title, extension) async {
              uploadCalled = true;
              capturedBytes = fileBytes;
              capturedFilename = filename;
              capturedExtension = extension;
              return const DocumentUploadResult.success('task-9');
            },
      );

      final pressed = await _pressFilesystemUpload(tester);
      expect(pressed, isTrue);
      await tester.pump();

      expect(uploadCalled, isTrue);
      expect(capturedFilename, equals('filesystem_scan'));
      expect(capturedExtension, equals('.jpg'));
      expect(capturedBytes, sourceFile.readAsBytesSync());
      expect(tasksNotifier.listenedTaskIds, ['task-9']);
    });

    testWidgets(
      'filesystem handoff blocks unsupported extensions with an error message',
      (WidgetTester tester) async {
        final sourceFile = await _createValidScanFile(
          dir: scansDir,
          name: 'filesystem_scan_bad',
          extension: 'txt',
        );
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        bool uploadCalled = false;
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          filePickerProvider: ({allowedExtensions = const []}) async =>
              sourceFile.path,
          filesystemUploadRouteProvider:
              (context, fileBytes, filename, title, extension) async {
                uploadCalled = true;
                return const DocumentUploadResult.success('task-9');
              },
        );

        final pressed = await _pressFilesystemUpload(tester);
        expect(pressed, isTrue);
        await tester.pump();

        expect(uploadCalled, isFalse);
        expect(find.text('This file format is not supported.'), findsOneWidget);
      },
    );

    testWidgets('filesystem handoff keeps scans when route returns null', (
      WidgetTester tester,
    ) async {
      final sourceFile = await _createValidScanFile(
        dir: scansDir,
        name: 'filesystem_scan_no_task',
        extension: 'jpg',
      );
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      bool uploadCalled = false;
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        filePickerProvider: ({allowedExtensions = const []}) async =>
            sourceFile.path,
        filesystemUploadRouteProvider:
            (context, fileBytes, filename, title, extension) async {
              uploadCalled = true;
              return null;
            },
      );

      final pressed = await _pressFilesystemUpload(tester);
      expect(pressed, isTrue);
      await tester.pump();

      expect(uploadCalled, isTrue);
      expect(tasksNotifier.listenedTaskIds, isEmpty);
    });

    testWidgets('filesystem handoff shows generic error when route throws', (
      WidgetTester tester,
    ) async {
      final sourceFile = await _createValidScanFile(
        dir: scansDir,
        name: 'filesystem_scan_throw',
        extension: 'jpg',
      );
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        filePickerProvider: ({allowedExtensions = const []}) async =>
            sourceFile.path,
        filesystemUploadRouteProvider:
            (context, fileBytes, filename, title, extension) async {
              throw Exception('filesystem failed');
            },
      );

      final pressed = await _pressFilesystemUpload(tester);
      expect(pressed, isTrue);
      await tester.pump();

      expect(find.text('Exception: filesystem failed'), findsOneWidget);
    });

    testWidgets('filesystem handoff does nothing when picker returns null', (
      WidgetTester tester,
    ) async {
      final sourceScan = await _createValidScanFile(
        dir: scansDir,
        name: 'filesystem_scan_cancel',
        extension: 'jpg',
      );
      final scannerCubit = DocumentScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      bool uploadCalled = false;
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        filePickerProvider: ({allowedExtensions = const []}) async => null,
        filesystemUploadRouteProvider:
            (context, fileBytes, filename, title, extension) async {
              uploadCalled = true;
              return const DocumentUploadResult.success('task-9');
            },
      );

      final pressed = await _pressFilesystemUpload(tester);
      expect(pressed, isTrue);
      await tester.pump();

      expect(uploadCalled, isFalse);
      expect(tasksNotifier.listenedTaskIds, isEmpty);

      final extension = p.extension(sourceScan.path);
      expect(extension, '.jpg');
      expect(sourceScan.existsSync(), isTrue);
    });
  });

  group('filesystem upload validation', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(preferredLocaleSubtag: 'en', uploadPresetEnabled: false),
      ),
    );

    test('unsupported filesystem extension never passes validation', () {
      expect(isSupportedUploadExtension('.txt'), isFalse);
      expect(isSupportedUploadExtension('.md'), isFalse);
      expect(isSupportedUploadExtension('.JPG'), isTrue);
      expect(isSupportedUploadExtension('.pdf'), isTrue);
    });
  });

  group('save to file handoff', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(preferredLocaleSubtag: 'en', uploadPresetEnabled: false),
      ),
    );

    testWidgets('saving scans to file triggers scanner cubit save once', (
      WidgetTester tester,
    ) async {
      final scan = await _createValidScanFile(
        dir: scansDir,
        name: 'export_scan',
        extension: 'jpg',
      );
      final scannerCubit = _RecordingScannerCubit(LocalNotificationService());
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      scannerCubit.addScan(scan);
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        scanAssembler: _assembleTestScans,
        exportFilenameProvider: (_) async => 'scan_export',
      );
      await tester.pumpAndSettle();
      final exportButton = tester.widget<IconButton>(
        find.byKey(const Key('scanner_export_button')),
      );
      expect(exportButton.onPressed, isNotNull);
      exportButton.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(scannerCubit.saveToFileCallCount, 1);
      expect(scannerCubit.lastSavedFileName, 'scan_export.pdf');
      expect(scannerCubit.lastSavedLocale, 'en');
      expect(scannerCubit.lastSavedBytes, isNotEmpty);
    });

    testWidgets('saving scans to file surfaces write errors as snackbars', (
      WidgetTester tester,
    ) async {
      final scan = await _createValidScanFile(
        dir: scansDir,
        name: 'export_scan_fail',
        extension: 'jpg',
      );
      final scannerCubit = _RecordingScannerCubit(
        LocalNotificationService(),
        throwOnSave: true,
      );
      final tasksNotifier = _RecordingTasksNotifier();
      final documentsCubit = DocumentsCubit(
        _NoopDocumentsApi(),
        DocumentChangedNotifier(),
        LocalUserAppState(userId: account.id),
        ConnectivityStatusServiceMock(true),
      );
      final savedViewCubit = SavedViewCubit(
        SavedViewRepository(_NoopSavedViewsApi()),
      );
      scannerCubit.addScan(scan);
      addTearDown(() async {
        await scannerCubit.close();
        await documentsCubit.close();
        await savedViewCubit.close();
        tasksNotifier.dispose();
      });

      await _pumpScannerPage(
        tester,
        scannerCubit: scannerCubit,
        documentsApi: _NoopDocumentsApi(),
        connectivity: ConnectivityStatusServiceMock(true),
        tasksNotifier: tasksNotifier,
        savedViewCubit: savedViewCubit,
        documentsCubit: documentsCubit,
        account: account,
        scanAssembler: _assembleTestScans,
        exportFilenameProvider: (_) async => 'export_error',
      );

      await tester.pumpAndSettle();
      final exportButton = tester.widget<IconButton>(
        find.byKey(const Key('scanner_export_button')),
      );
      expect(exportButton.onPressed, isNotNull);
      exportButton.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      await tester.pump();

      expect(scannerCubit.saveToFileCallCount, 1);
      expect(find.text('Exception: write to file failed'), findsOneWidget);
    });

    testWidgets(
      'saving scans does nothing when export filename is not provided',
      (WidgetTester tester) async {
        final scan = await _createValidScanFile(
          dir: scansDir,
          name: 'export_scan_cancel',
          extension: 'jpg',
        );
        final scannerCubit = _RecordingScannerCubit(LocalNotificationService());
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: _NoopDocumentsApi(),
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
          scanAssembler: _assembleTestScans,
          exportFilenameProvider: (_) async => null,
        );

        await tester.pumpAndSettle();
        final exportButton = tester.widget<IconButton>(
          find.byKey(const Key('scanner_export_button')),
        );
        expect(exportButton.onPressed, isNotNull);
        exportButton.onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(scannerCubit.saveToFileCallCount, 0);
        expect(scannerCubit.state.scans, isNotEmpty);
      },
    );
  });

  group('quick upload createdAt preset', () {
    setUpAll(
      () => _setGlobalSettings(
        GlobalSettings(
          preferredLocaleSubtag: 'en',
          uploadPresetEnabled: true,
          uploadPresetUseCurrentDate: true,
          uploadPresetTitleTemplate: 'Invoice',
        ),
      ),
    );

    testWidgets(
      'quick upload sets createdAt when current-date preset is enabled',
      (WidgetTester tester) async {
        final scan = await _createScanFile(dir: scansDir, name: 'scan_date');
        final scannerCubit = DocumentScannerCubit(LocalNotificationService());
        final api = _RecordingSuccessDocumentsApi();
        final tasksNotifier = _RecordingTasksNotifier();
        final documentsCubit = DocumentsCubit(
          _NoopDocumentsApi(),
          DocumentChangedNotifier(),
          LocalUserAppState(userId: account.id),
          ConnectivityStatusServiceMock(true),
        );
        final savedViewCubit = SavedViewCubit(
          SavedViewRepository(_NoopSavedViewsApi()),
        );
        scannerCubit.addScan(scan);
        addTearDown(() async {
          await scannerCubit.close();
          await documentsCubit.close();
          await savedViewCubit.close();
          tasksNotifier.dispose();
        });

        await _pumpScannerPage(
          tester,
          scannerCubit: scannerCubit,
          documentsApi: api,
          connectivity: ConnectivityStatusServiceMock(true),
          tasksNotifier: tasksNotifier,
          savedViewCubit: savedViewCubit,
          documentsCubit: documentsCubit,
          account: account,
        );

        await _pressQuickUpload(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(api.lastCreatedAt, isNotNull);
      },
    );
  });
}
