import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/features/edit_label/view/edit_label_page.dart';
import 'package:paperless_mobile/features/labels/cubit/label_cubit.dart';

class EditDocumentTypePage extends StatelessWidget {
  final DocumentType documentType;
  const EditDocumentTypePage({super.key, required this.documentType});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LabelCubit(context.read()),
      child: EditLabelPage<DocumentType>(
        label: documentType,
        fromJsonT: DocumentType.fromJson,
        onSubmit: (context, label) =>
            context.read<LabelCubit>().replaceDocumentType(label),
        onDelete: (context, label) =>
            context.read<LabelCubit>().removeDocumentType(label),
        canDelete: context
            .watch<LocalUserAccount>()
            .paperlessUser
            .canDeleteDocumentTypes,
      ),
    );
  }
}
