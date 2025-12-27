import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/security/trusted_certificate_pin.dart';
import 'package:paperless_mobile/core/security/trusted_certificate_store.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class TrustedCertificatesPage extends StatelessWidget {
  const TrustedCertificatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.trustedCertificates),
      ),
      body: ValueListenableBuilder<Box<GlobalSettings>>(
        valueListenable:
            Hive.box<GlobalSettings>(HiveBoxes.globalSettings).listenable(),
        builder: (context, box, _) {
          final settings = box.getValue();
          final pins = settings?.trustedCertificatePins ?? const [];
          if (pins.isEmpty) {
            return Center(
              child: Text(S.of(context)!.noTrustedCertificates),
            );
          }
          return ListView.separated(
            itemCount: pins.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final pin = pins[index];
              return ListTile(
                title: Text(pin.hostPort),
                subtitle: Text(
                  pin.fingerprintSha256,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _showPinDetails(context, pin),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmRemove(context, pin),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    TrustedCertificatePin pin,
  ) async {
    final shouldRemove = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(S.of(context)!.removeTrustedCertificate),
            content: Text(
              S.of(context)!.removeTrustedCertificateConfirm(pin.hostPort),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(S.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(S.of(context)!.remove),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldRemove) {
      return;
    }
    await TrustedCertificateStore.removeTrustedPin(pin);
  }

  Future<void> _showPinDetails(
    BuildContext context,
    TrustedCertificatePin pin,
  ) async {
    final theme = Theme.of(context).textTheme;
    final labelStyle = theme.labelSmall;
    final valueStyle = theme.bodySmall;
    final localizations = MaterialLocalizations.of(context);
    String formatDate(DateTime date) {
      return localizations.formatMediumDate(date);
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

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context)!.certificateDetailsTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              detailRow(
                S.of(context)!.certificateAddedOn,
                formatDate(pin.addedAt),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.of(context)!.close),
          ),
        ],
      ),
    );
  }
}
