import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/edit_label/view/add_label_page.dart';
import 'package:paperless_mobile/features/labels/cubit/label_cubit.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class AddCorrespondentPage extends StatelessWidget {
  final String? initialName;
  const AddCorrespondentPage({super.key, this.initialName});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LabelCubit(context.read()),
      child: AddLabelPage<Correspondent>(
        pageTitle: Text(S.of(context)!.addCorrespondent),
        fromJsonT: Correspondent.fromJson,
        initialName: initialName,
        onSubmit: (context, label) =>
            context.read<LabelCubit>().addCorrespondent(label),
      ),
    );
  }
}
