import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_cancel_button.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class ExportScansDialog extends StatefulWidget {
  final int scanCount;

  const ExportScansDialog({super.key, this.scanCount = 0});

  @override
  State<ExportScansDialog> createState() => _ExportScansDialogState();
}

class _ExportScansDialogState extends State<ExportScansDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _filename;
  late String _placeholder;

  @override
  void initState() {
    super.initState();
    final date = DateFormat("yyyy_MM_ddThhmmss").format(DateTime.now());
    _placeholder = "paperless_mobile_scan_$date";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog.adaptive(
      icon: Icon(
        Icons.picture_as_pdf_outlined,
        size: 32,
        color: colorScheme.primary,
      ),
      title: Text(S.of(context)!.exportScansToPdf),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              onSaved: (newValue) {
                _filename = newValue;
              },
              autofocus: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                final matches = RegExp(r'[<>:"/\|?*]').allMatches(value!);
                if (matches.isNotEmpty) {
                  final illegalCharacters = matches
                      .map((match) => match.group(0))
                      .toList()
                      .toSet()
                      .join(" ");
                  return S
                      .of(context)!
                      .invalidFilenameCharacter(illegalCharacters);
                }

                return null;
              },
              decoration: InputDecoration(
                labelText: S.of(context)!.fileName,
                errorMaxLines: 5,
                suffixText: ".pdf",
                hintText: _placeholder,
                helperText: S.of(context)!.allScansWillBeMerged,
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const DialogCancelButton(),
        ),
        FilledButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              _formKey.currentState?.save();
              final effectiveFilename = (_filename?.trim().isEmpty ?? true)
                  ? _placeholder
                  : _filename;
              Navigator.pop(context, effectiveFilename);
            }
          },
          child: Text(S.of(context)!.export),
        ),
      ],
    );
  }
}
