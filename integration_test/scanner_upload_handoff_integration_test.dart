import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as im;
import 'package:integration_test/integration_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/saved_view_repository.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/document_scan/cubit/document_scanner_cubit.dart';
import 'package:paperless_mobile/features/document_scan/scan_pdf_assembler.dart';
import 'package:paperless_mobile/features/document_scan/view/scanner_page.dart';
import 'package:paperless_mobile/features/document_upload/model/document_upload_result.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';
import 'package:paperless_mobile/features/notifications/services/local_notification_service.dart';
import 'package:paperless_mobile/features/saved_view/cubit/saved_view_cubit.dart';
import 'package:paperless_mobile/features/sharing/cubit/receive_share_cubit.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _NoopDocumentsApi extends Fake implements PaperlessDocumentsApi {}

class _NoopSavedViewsApi extends Fake implements PaperlessSavedViewsApi {}

class _NoopTasksApi extends Fake implements PaperlessTasksApi {}

class _RecordingTasksNotifier extends PendingTasksNotifier {
  _RecordingTasksNotifier() : super(_NoopTasksApi());

  final List<String> listenedTaskIds = [];

  @override
  void listenToTaskChanges(String taskId) {
    listenedTaskIds.add(taskId);
  }
}

Uint8List _buildValidPngBytes() {
  final image = im.Image(width: 10, height: 10);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 255, 255, 255, 255);
    }
  }
  return Uint8List.fromList(im.encodePng(image));
}

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  registerHiveAdapters();
  await Hive.openBox<GlobalSettings>(HiveBoxes.globalSettings);
  await Hive.openBox<LocalUserAccount>(HiveBoxes.localUserAccount);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory scansDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('scanner_integration_');
    await _initHive(tempDir);
    const accountId = 'integration-user';
    final account = LocalUserAccount(
      id: accountId,
      serverUrl: 'https://example.com',
      settings: LocalUserSettings(),
      paperlessUser: UserModelV3(
        id: 1,
        username: 'integration',
        email: 'integration@example.com',
        firstName: 'Integration',
        lastName: 'User',
        dateJoined: DateTime(2025, 1, 1),
        isStaff: false,
        isActive: true,
        isSuperuser: false,
        groups: const [],
        userPermissions: const ['view_document'],
        inheritedPermissions: const [],
      ),
      apiVersion: 3,
    );
    await Hive.box<LocalUserAccount>(
      HiveBoxes.localUserAccount,
    ).put(account.id, account);
    await Hive.box<GlobalSettings>(HiveBoxes.globalSettings).setValue(
      GlobalSettings(
        preferredLocaleSubtag: 'en',
        loggedInUserId: accountId,
        uploadPresetEnabled: false,
        enforceSinglePagePdfUpload: true,
      ),
    );
  });

  setUp(() async {
    scansDir = await Directory('${tempDir.path}/scans').create(recursive: true);
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

  testWidgets('scanner flow uploads prepared scan and tracks task id', (
    tester,
  ) async {
    final account = Hive.box<LocalUserAccount>(
      HiveBoxes.localUserAccount,
    ).get('integration-user')!;
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

    final sourceScan = File('${scansDir.path}/source_scan.png');
    sourceScan.writeAsBytesSync(_buildValidPngBytes(), flush: true);
    var allocatedCount = 0;

    final previousPermissionProvider = ScannerPage.permissionRequestProvider;
    final previousPlatformProvider = ScannerPage.platformIsAndroidProvider;
    final previousFactory = ScannerPage.documentScannerFactory;
    final previousScanProvider = ScannerPage.documentScannerScanProvider;
    final previousCloseProvider = ScannerPage.documentScannerCloseProvider;
    final previousAllocator = ScannerPage.temporaryScanFileAllocator;
    final previousCopier = ScannerPage.scannedFileCopier;
    final previousAssembler = ScannerPage.scanAssembler;
    final previousUploadProvider = ScannerPage.documentUploadRouteProvider;

    addTearDown(() async {
      ScannerPage.permissionRequestProvider = previousPermissionProvider;
      ScannerPage.platformIsAndroidProvider = previousPlatformProvider;
      ScannerPage.documentScannerFactory = previousFactory;
      ScannerPage.documentScannerScanProvider = previousScanProvider;
      ScannerPage.documentScannerCloseProvider = previousCloseProvider;
      ScannerPage.temporaryScanFileAllocator = previousAllocator;
      ScannerPage.scannedFileCopier = previousCopier;
      ScannerPage.scanAssembler = previousAssembler;
      ScannerPage.documentUploadRouteProvider = previousUploadProvider;
      await scannerCubit.close();
      await documentsCubit.close();
      await savedViewCubit.close();
      tasksNotifier.dispose();
    });

    final fakeScanner = DocumentScanner(
      options: DocumentScannerOptions(pageLimit: 1),
    );
    ScannerPage.permissionRequestProvider = (_) async => true;
    ScannerPage.platformIsAndroidProvider = () => true;
    ScannerPage.documentScannerFactory = () async => fakeScanner;
    ScannerPage.documentScannerScanProvider = (_) async =>
        DocumentScanningResult(images: [sourceScan.path], pdf: null);
    ScannerPage.documentScannerCloseProvider = (_) async {};
    ScannerPage.temporaryScanFileAllocator =
        ({required extension, required create}) async {
          final file = File(
            '${scansDir.path}/allocated_${allocatedCount++}.$extension',
          );
          if (create) {
            await file.create(recursive: true);
          }
          return file;
        };
    ScannerPage.scannedFileCopier = (sourcePath, destinationPath) async {
      final bytes = File(sourcePath).readAsBytesSync();
      File(destinationPath).writeAsBytesSync(bytes, flush: true);
    };
    ScannerPage.scanAssembler = (files, {forcePdf = false}) async {
      return ScannedAssembledFile(
        extension: '.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );
    };
    ScannerPage.documentUploadRouteProvider = (context, file) async {
      return const DocumentUploadResult.success('task-integration-1');
    };

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
            ChangeNotifierProvider<PendingTasksNotifier>.value(
              value: tasksNotifier,
            ),
            ChangeNotifierProvider<ConsumptionChangeNotifier>.value(
              value: ConsumptionChangeNotifier(),
            ),
            Provider<ConnectivityStatusService>.value(
              value: ConnectivityStatusServiceMock(true),
            ),
            Provider<PaperlessDocumentsApi>.value(value: _NoopDocumentsApi()),
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

    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    for (var i = 0; i < 20 && scannerCubit.state.scans.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(scannerCubit.state.scans, isNotEmpty);

    await tester.tap(find.byKey(const Key('scanner_upload_button')));
    await tester.pumpAndSettle();

    expect(tasksNotifier.listenedTaskIds, ['task-integration-1']);
    expect(scannerCubit.state.scans, isEmpty);
  });
}
