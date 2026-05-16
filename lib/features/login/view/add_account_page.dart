import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/constants.dart';
import 'package:paperless_mobile/core/exception/server_message_exception.dart';
import 'package:paperless_mobile/core/model/info_message_exception.dart';
import 'package:paperless_mobile/core/security/trusted_certificate_pin.dart';
import 'package:paperless_mobile/core/security/trusted_certificate_store.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/features/login/model/client_certificate.dart';
import 'package:paperless_mobile/features/login/model/login_form_credentials.dart';
import 'package:paperless_mobile/features/login/model/reachability_status.dart';
import 'package:paperless_mobile/features/login/view/widgets/form_fields/client_certificate_form_field.dart';
import 'package:paperless_mobile/features/login/view/widgets/form_fields/server_address_form_field.dart';
import 'package:paperless_mobile/features/login/view/widgets/form_fields/user_credentials_form_field.dart';
import 'package:paperless_mobile/generated/assets.gen.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:paperless_mobile/keys.dart';
import 'package:paperless_mobile/routing/routes/app_logs_route.dart';

class AddAccountPage extends StatefulWidget {
  final FutureOr<void> Function(
    BuildContext context,
    LoginFormCredentials credentials,
    String serverUrl,
    ClientCertificate? clientCertificate,
  )
  onSubmit;

  final String? initialServerUrl;
  final String? initialUsername;
  final String? initialPassword;
  final ClientCertificate? initialClientCertificate;

  final String submitText;
  final String titleText;
  final bool showLocalAccounts;
  final String? versionOverride;

  final Widget? bottomLeftButton;

  const AddAccountPage({
    super.key,
    required this.onSubmit,
    required this.submitText,
    required this.titleText,
    this.showLocalAccounts = false,
    this.initialServerUrl,
    this.initialUsername,
    this.initialPassword,
    this.initialClientCertificate,
    this.bottomLeftButton,
    this.versionOverride,
  });

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _credentialsController = UserCredentialsFormFieldController();
  bool _isCheckingConnection = false;
  ReachabilityStatus _reachabilityStatus = ReachabilityStatus.unknown;
  bool _certificateChanged = false;

  final _pageController = PageController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(widget.titleText)),
      body: SafeArea(
        top: false,
        child: FormBuilder(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Assets.logos.paperlessLogoGreenPng.image(
                  width: 150,
                  height: 150,
                ),
                Text(
                  S.of(context)!.paperlessMobileAppName,
                  style: Theme.of(context).textTheme.displaySmall,
                ).padded(),
                SizedBox(height: 24),
                Expanded(
                  child: PageView(
                    physics: NeverScrollableScrollPhysics(),
                    controller: _pageController,
                    allowImplicitScrolling: false,
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            ServerAddressFormField(
                              onChanged: (value) {
                                setState(() {
                                  _reachabilityStatus =
                                      ReachabilityStatus.unknown;
                                  _certificateChanged = false;
                                });
                              },
                            ).paddedSymmetrically(horizontal: 12, vertical: 12),
                            ClientCertificateFormField(
                              initialBytes:
                                  widget.initialClientCertificate?.bytes,
                              initialPassphrase:
                                  widget.initialClientCertificate?.passphrase,
                            ).padded(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                //TODO: Move additional headers and client cert to separate page
                                // IconButton.filledTonal(
                                //   onPressed: () {
                                //     Navigator.of(context).push(
                                //       MaterialPageRoute(builder: (context) {
                                //         return LoginSettingsPage();
                                //       }),
                                //     );
                                //   },
                                //   icon: Icon(Icons.settings),
                                // ),
                                SizedBox(width: 8),
                                FilledButton.icon(
                                  key: TestKeys.login.continueButton,
                                  onPressed: () async {
                                    final status = await _updateReachability();
                                    if (!mounted) return;
                                    if (status ==
                                        ReachabilityStatus
                                            .untrustedCertificate) {
                                      final shouldTrust =
                                          await _showUntrustedCertificateDialog();
                                      if (!mounted) return;
                                      if (shouldTrust) {
                                        await _trustCurrentServer();
                                        final recheck =
                                            await _updateReachability();
                                        if (!mounted) return;
                                        if (recheck ==
                                            ReachabilityStatus.reachable) {
                                          Future.delayed(1.seconds, () {
                                            _pageController.nextPage(
                                              duration: Duration(
                                                milliseconds: 300,
                                              ),
                                              curve: Curves.easeInOut,
                                            );
                                          });
                                        }
                                      }
                                      return;
                                    }
                                    if (status ==
                                        ReachabilityStatus.reachable) {
                                      Future.delayed(1.seconds, () {
                                        _pageController.nextPage(
                                          duration: Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      });
                                    }
                                  },
                                  icon: _isCheckingConnection
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSecondary,
                                          ),
                                        )
                                      : _reachabilityStatus ==
                                            ReachabilityStatus.reachable
                                      ? Icon(Icons.done)
                                      : Icon(Icons.arrow_forward),
                                  label: Text(S.of(context)!.continueLabel),
                                ),
                              ],
                            ).paddedSymmetrically(horizontal: 16, vertical: 8),
                            _buildStatusIndicator().padded(),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            UserCredentialsFormField(
                              formKey: _formKey,
                              controller: _credentialsController,
                              initialUsername: widget.initialUsername,
                              initialPassword: widget.initialPassword,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  icon: Icon(Icons.arrow_back),
                                  label: Text(S.of(context)!.edit),
                                ),
                                FilledButton(
                                  key: TestKeys.login.loginButton,
                                  onPressed: () {
                                    _onSubmit();
                                  },
                                  child: Text(S.of(context)!.signIn),
                                ),
                              ],
                            ).padded(),
                            Text(
                              S.of(context)!.loginRequiredPermissionsHint,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.apply(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withAlpha(153),
                                  ),
                            ).padded(16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.labelLarge,
                    children: [
                      TextSpan(
                        text: S
                            .of(context)!
                            .version(
                              widget.versionOverride ?? packageInfo.version,
                            ),
                      ),
                      WidgetSpan(child: SizedBox(width: 24)),
                      TextSpan(
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        text: S.of(context)!.appLogs(''),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            AppLogsRoute().push(context);
                          },
                      ),
                    ],
                  ),
                ).padded(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<ReachabilityStatus> _updateReachability([String? address]) async {
    setState(() {
      _isCheckingConnection = true;
    });
    final selectedCertificate = _formKey.currentState
        ?.getRawValue<ClientCertificate>(
          ClientCertificateFormField.fkClientCertificate,
        );
    final status = await context
        .read<ConnectivityStatusService>()
        .isPaperlessServerReachable(
          address ??
              _formKey.currentState!.getRawValue(
                ServerAddressFormField.fkServerAddress,
              ),
          selectedCertificate,
        );
    final uri = _currentServerUri();
    final lastPin = uri == null
        ? null
        : TrustedCertificateStore.getLastUntrustedPinForUri(uri);
    final trustedPin = uri == null
        ? null
        : TrustedCertificateStore.getTrustedPinForUri(uri);
    final certificateChanged =
        lastPin != null &&
        trustedPin != null &&
        lastPin.fingerprintSha256 != trustedPin.fingerprintSha256;
    setState(() {
      _isCheckingConnection = false;
      _reachabilityStatus = status;
      _certificateChanged =
          status == ReachabilityStatus.untrustedCertificate &&
          certificateChanged;
    });
    return status;
  }

  Widget _buildStatusIndicator() {
    Widget buildIconText(IconData icon, String text, [Color? color]) {
      return ListTile(
        title: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
        leading: Icon(icon, color: color),
      );
    }

    Color errorColor = Theme.of(context).colorScheme.error;
    switch (_reachabilityStatus) {
      case ReachabilityStatus.notReachable:
        return buildIconText(
          Icons.close,
          S.of(context)!.couldNotEstablishConnectionToTheServer,
          errorColor,
        );
      case ReachabilityStatus.unknownHost:
        return buildIconText(
          Icons.close,
          S.of(context)!.hostCouldNotBeResolved,
          errorColor,
        );
      case ReachabilityStatus.missingClientCertificate:
        return buildIconText(
          Icons.close,
          S.of(context)!.loginPageReachabilityMissingClientCertificateText,
          errorColor,
        );
      case ReachabilityStatus.invalidClientCertificateConfiguration:
        return buildIconText(
          Icons.close,
          S.of(context)!.incorrectOrMissingCertificatePassphrase,
          errorColor,
        );
      case ReachabilityStatus.connectionTimeout:
        return buildIconText(
          Icons.close,
          S.of(context)!.connectionTimedOut,
          errorColor,
        );
      case ReachabilityStatus.untrustedCertificate:
        return buildIconText(
          Icons.warning_amber,
          _certificateChanged
              ? S.of(context)!.certificateChangedWarning
              : S.of(context)!.untrustedCertificateWarning,
          Theme.of(context).colorScheme.tertiary,
        );
      default:
        return const ListTile();
    }
  }

  Future<void> _trustCurrentServer() async {
    final uri = _currentServerUri();
    if (uri == null) {
      return;
    }
    final trusted = await TrustedCertificateStore.trustLastUntrustedForUri(uri);
    if (!trusted && mounted) {
      showSnackBar(context, S.of(context)!.certificateDetailsUnavailable);
    }
  }

  Future<bool> _showUntrustedCertificateDialog() async {
    final uri = _currentServerUri();
    final pin = uri == null
        ? null
        : TrustedCertificateStore.getLastUntrustedPinForUri(uri);
    final trustedPin = uri == null
        ? null
        : TrustedCertificateStore.getTrustedPinForUri(uri);
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            final details = pin == null
                ? Text(S.of(context)!.certificateDetailsUnavailable)
                : _buildCertificateDetails(context, pin, trustedPin);
            return AlertDialog(
              title: Text(S.of(context)!.untrustedCertificateTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.of(context)!.untrustedCertificateDescription),
                    const SizedBox(height: 16),
                    details,
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(S.of(context)!.cancel),
                ),
                FilledButton(
                  onPressed: pin == null
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: Text(S.of(context)!.trustServerCertificate),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Uri? _currentServerUri() {
    final serverAddress = _formKey.currentState?.getRawValue(
      ServerAddressFormField.fkServerAddress,
    );
    if (serverAddress == null) {
      return null;
    }
    final uri = Uri.tryParse(serverAddress);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  Widget _buildCertificateDetails(
    BuildContext context,
    TrustedCertificatePin pin,
    TrustedCertificatePin? trustedPin,
  ) {
    final theme = Theme.of(context).textTheme;
    final labelStyle = theme.labelSmall;
    final valueStyle = theme.bodySmall;
    final dateFormatter = MaterialLocalizations.of(context);
    String formatDate(DateTime date) {
      return dateFormatter.formatMediumDate(date);
    }

    Widget detailRow(String label, String value, {bool selectable = false}) {
      final valueWidget = selectable
          ? SelectableText(value, style: valueStyle)
          : Text(value, style: valueStyle);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            valueWidget,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trustedPin != null &&
            trustedPin.fingerprintSha256 != pin.fingerprintSha256)
          detailRow(
            S.of(context)!.certificatePreviousFingerprint,
            trustedPin.fingerprintSha256,
            selectable: true,
          ),
        detailRow(S.of(context)!.certificateHost, pin.hostPort),
        detailRow(
          S.of(context)!.certificateFingerprint,
          pin.fingerprintSha256,
          selectable: true,
        ),
        detailRow(S.of(context)!.certificateSubject, pin.subject),
        detailRow(S.of(context)!.certificateIssuer, pin.issuer),
        detailRow(
          S.of(context)!.certificateValidFrom,
          formatDate(pin.startValidity),
        ),
        detailRow(
          S.of(context)!.certificateValidUntil,
          formatDate(pin.endValidity),
        ),
      ],
    );
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final form = _formKey.currentState!.value;
      final clientCertFormModel =
          form[ClientCertificateFormField.fkClientCertificate]
              as ClientCertificate?;

      final credentials =
          form[UserCredentialsFormField.fkCredentials] as LoginFormCredentials;
      _credentialsController.clearMfaCode();
      try {
        await widget.onSubmit(
          context,
          credentials,
          form[ServerAddressFormField.fkServerAddress],
          clientCertFormModel,
        );
      } on PaperlessApiException catch (error) {
        if (mounted) showErrorMessage(context, error);
      } on ServerMessageException catch (error) {
        if (mounted) showLocalizedError(context, error.message);
      } on InfoMessageException catch (error) {
        if (mounted) showInfoMessage(context, error);
      } catch (error) {
        if (mounted) showGenericError(context, error);
      }
    }
  }
}
