import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/features/edit_label/view/label_form.dart';
import 'package:paperless_mobile/features/labels/cubit/label_cubit.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class AddLabelPage<T extends Label> extends StatelessWidget {
  final String? initialName;
  final Widget pageTitle;
  final T Function(Map<String, dynamic> json) fromJsonT;
  final List<Widget> additionalFields;
  final Future<T> Function(BuildContext context, T label) onSubmit;

  const AddLabelPage({
    super.key,
    this.initialName,
    required this.pageTitle,
    required this.fromJsonT,
    this.additionalFields = const [],
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LabelCubit(context.read<LabelRepository>()),
      child: AddLabelFormWidget(
        pageTitle: pageTitle,
        label: initialName != null ? fromJsonT({'name': initialName}) : null,
        additionalFields: additionalFields,
        fromJsonT: fromJsonT,
        onSubmit: onSubmit,
      ),
    );
  }
}

class AddLabelFormWidget<T extends Label> extends StatelessWidget {
  final T? label;
  final T Function(Map<String, dynamic> json) fromJsonT;
  final List<Widget> additionalFields;
  final Future<T> Function(BuildContext context, T label) onSubmit;

  final Widget pageTitle;
  const AddLabelFormWidget({
    super.key,
    this.label,
    required this.fromJsonT,
    required this.additionalFields,
    required this.pageTitle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: pageTitle),
      body: LabelForm<T>(
        autofocusNameField: true,
        initialValue: label,
        fromJsonT: fromJsonT,
        submitButtonConfig: SubmitButtonConfig<T>(
          icon: const Icon(Icons.add),
          label: Text(S.of(context)!.create),
          onSubmit: (label) => onSubmit(context, label),
        ),
        additionalFields: additionalFields,
      ),
    );
  }
}
