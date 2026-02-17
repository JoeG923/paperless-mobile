import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/features/edit_label/view/edit_label_page.dart';
import 'package:paperless_mobile/features/labels/cubit/label_cubit.dart';

class EditCorrespondentPage extends StatelessWidget {
  final Correspondent correspondent;
  const EditCorrespondentPage({super.key, required this.correspondent});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      lazy: false,
      create: (context) => LabelCubit(context.read()),
      child: Builder(
        builder: (context) {
          return EditLabelPage<Correspondent>(
            label: correspondent,
            fromJsonT: Correspondent.fromJson,
            onSubmit: (context, label) =>
                context.read<LabelCubit>().replaceCorrespondent(label),
            onDelete: (context, label) =>
                context.read<LabelCubit>().removeCorrespondent(label),
            canDelete: context
                .watch<LocalUserAccount>()
                .paperlessUser
                .canDeleteCorrespondents,
          );
        },
      ),
    );
  }
}
