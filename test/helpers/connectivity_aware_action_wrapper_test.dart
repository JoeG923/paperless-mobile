import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/login/model/client_certificate.dart';
import 'package:paperless_mobile/features/login/model/reachability_status.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/connectivity_aware_action_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class SilentConnectivityStatusService implements ConnectivityStatusService {
  @override
  Stream<bool> connectivityChanges() => const Stream<bool>.empty();

  @override
  Future<bool> isConnectedToInternet() async => true;

  @override
  Future<bool> isServerReachable(String serverAddress) async => true;

  @override
  Future<ReachabilityStatus> isPaperlessServerReachable(
    String serverAddress, [
    ClientCertificate? clientCertificate,
  ]) async => ReachabilityStatus.reachable;
}

void main() {
  testWidgets(
    'does not show offline snackbar when disabled and connectivity is unknown',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        Provider<ConnectivityStatusService>.value(
          value: SilentConnectivityStatusService(),
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: Center(
                child: ConnectivityAwareActionWrapper(
                  disabled: true,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Upload'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Upload'), warnIfMissed: false);
      await tester.pump();

      expect(
        find.text(
          'You are currently offline. Please make sure you are connected to the internet.',
        ),
        findsNothing,
      );
    },
  );
}
