import 'package:flutter/material.dart';
import 'package:paperless_mobile/features/settings/view/trusted_certificates_page.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class TrustedCertificatesTile extends StatelessWidget {
  const TrustedCertificatesTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.verified_user_outlined),
      title: Text(S.of(context)!.trustedCertificates),
      subtitle: Text(S.of(context)!.trustedCertificatesSubtitle),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TrustedCertificatesPage(),
          ),
        );
      },
    );
  }
}
