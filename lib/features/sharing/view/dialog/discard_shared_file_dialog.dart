import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_cancel_button.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_confirm_button.dart';
import 'package:paperless_mobile/core/widgets/future_or_builder.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/features/sharing/view/widgets/file_thumbnail.dart';

class DiscardSharedFileDialog extends StatelessWidget {
  final FutureOr<Uint8List> bytes;
  const DiscardSharedFileDialog({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: FutureOrBuilder<Uint8List>(
        future: bytes,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FileThumbnail(
              bytes: snapshot.data!,
              width: 150,
              height: 100,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
      title: Text(S.of(context)!.discardFile),
      content: Text(S.of(context)!.sharedFileDiscardPrompt),
      actions: [
        DialogCancelButton(),
        DialogConfirmButton(
          label: S.of(context)!.discard,
          style: DialogConfirmButtonStyle.danger,
        ),
      ],
    );
  }
}
