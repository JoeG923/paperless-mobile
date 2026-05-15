import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:paperless_mobile/core/model/github_error_report.model.dart';
import 'package:paperless_mobile/core/widgets/dialog_utils/dialog_cancel_button.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class ErrorReportPage extends StatefulWidget {
  final StackTrace? stackTrace;
  const ErrorReportPage({super.key, this.stackTrace});

  @override
  State<ErrorReportPage> createState() => _ErrorReportPageState();
}

class _ErrorReportPageState extends State<ErrorReportPage> {
  final GlobalKey<FormBuilderState> _formKey = GlobalKey();

  static const String shortDescriptionKey = 'shortDescription';
  static const String longDescriptionKey = 'longDescription';

  bool _stackTraceCopied = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(S.of(context)!.reportError),
        actions: [
          TextButton(onPressed: _onSubmit, child: Text(S.of(context)!.submit)),
        ],
      ),
      body: FormBuilder(
        key: _formKey,
        child: ListView(
          children: [
            Text(
              S.of(context)!.errorReportIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ).padded(),
            Text(
              S.of(context)!.description,
              style: Theme.of(context).textTheme.titleMedium,
            ).padded(),
            FormBuilderTextField(
              name: shortDescriptionKey,
              decoration: InputDecoration(
                label: Text(S.of(context)!.shortDescription),
                hintText: S.of(context)!.shortDescriptionHint,
              ),
            ).padded(),
            FormBuilderTextField(
              name: longDescriptionKey,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                label: Text(S.of(context)!.detailedDescription),
                hintText: S.of(context)!.detailedDescriptionHint,
              ),
            ).padded(),
            if (widget.stackTrace != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context)!.stackTrace,
                    style: Theme.of(context).textTheme.titleMedium,
                  ).paddedOnly(top: 8.0, left: 8.0, right: 8.0),
                  TextButton.icon(
                    label: Text(S.of(context)!.copy),
                    icon: const Icon(Icons.copy),
                    onPressed: _copyStackTrace,
                  ),
                ],
              ),
              Text(
                S.of(context)!.stackTraceCopyHint,
                style: Theme.of(context).textTheme.bodySmall,
              ).padded(),
              Text(
                widget.stackTrace.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ).padded(),
            ],
          ],
        ),
      ),
    );
  }

  void _copyStackTrace() {
    Clipboard.setData(
      ClipboardData(text: '```${widget.stackTrace.toString()}```'),
    ).then((_) {
      setState(() => _stackTraceCopied = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.stackTraceCopied),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _onSubmit() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final fk = _formKey.currentState!.value;
      if (!_stackTraceCopied) {
        final continueSubmission =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(S.of(context)!.continueWithoutStackTrace),
                content: Text(S.of(context)!.continueWithoutStackTraceMessage),
                actionsAlignment: MainAxisAlignment.end,
                actions: [
                  TextButton(
                    child: Text(S.of(context)!.yesContinue),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  TextButton(
                    child: Text(S.of(context)!.noCopyStackTrace),
                    onPressed: () {
                      _copyStackTrace();
                      Navigator.pop(context, true);
                    },
                  ),
                  const DialogCancelButton(),
                ],
              ),
            ) ??
            false;
        if (!continueSubmission) {
          return;
        }
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        GithubErrorReport(
          shortDescription: fk[shortDescriptionKey],
          longDescription: fk[longDescriptionKey],
        ),
      );
    }
  }
}
