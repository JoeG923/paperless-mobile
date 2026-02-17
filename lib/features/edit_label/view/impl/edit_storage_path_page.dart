import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/features/edit_label/view/edit_label_page.dart';
import 'package:paperless_mobile/features/labels/cubit/label_cubit.dart';
import 'package:paperless_mobile/features/labels/storage_path/view/widgets/storage_path_autofill_form_builder_field.dart';

class EditStoragePathPage extends StatelessWidget {
  final StoragePath storagePath;
  const EditStoragePathPage({super.key, required this.storagePath});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LabelCubit(context.read()),
      child: EditLabelPage<StoragePath>(
        label: storagePath,
        fromJsonT: StoragePath.fromJson,
        onSubmit: (context, label) =>
            context.read<LabelCubit>().replaceStoragePath(label),
        onDelete: (context, label) =>
            context.read<LabelCubit>().removeStoragePath(label),
        canDelete: context
            .watch<LocalUserAccount>()
            .paperlessUser
            .canDeleteStoragePaths,
        additionalFields: [
          StoragePathAutofillFormBuilderField(
            name: StoragePath.pathKey,
            initialValue: storagePath.path,
          ),
          const SizedBox(height: 120.0),
        ],
      ),
    );
  }
}
