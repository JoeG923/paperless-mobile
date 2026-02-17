import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/features/sharing/cubit/receive_share_cubit.dart';
import 'package:paperless_mobile/features/sharing/view/widgets/file_thumbnail.dart';
import 'package:paperless_mobile/features/sharing/view/widgets/event_listener_shell.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class ConsumptionQueueView extends StatelessWidget {
  const ConsumptionQueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<LocalUserAccount>();
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context)!.pendingFiles)),
      body: Consumer<ConsumptionChangeNotifier>(
        builder: (context, value, child) {
          if (value.pendingFiles.isEmpty) {
            return Center(child: Text(S.of(context)!.thereAreNoPendingFiles));
          }
          return ListView.builder(
            itemBuilder: (context, index) {
              final file = value.pendingFiles.elementAt(index);
              final filename = p.basename(file.path);
              return ListTile(
                title: Text(
                  filename,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Row(
                  children: [
                    ActionChip(
                      label: Text(S.of(context)!.upload),
                      avatar: const Icon(Icons.file_upload_outlined),
                      onPressed: () {
                        consumeLocalFile(
                          context,
                          file: file,
                          userId: currentUser.id,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      label: Text(S.of(context)!.discard),
                      avatar: const Icon(Icons.delete),
                      onPressed: () {
                        context.read<ConsumptionChangeNotifier>().discardFile(
                          file,
                          userId: currentUser.id,
                        );
                      },
                    ),
                  ],
                ),
                leading: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FileThumbnail(
                      file: file,
                      fit: BoxFit.cover,
                      width: 75,
                    ),
                  ),
                ),
              );
            },
            itemCount: value.pendingFiles.length,
          );
        },
      ),
    );
  }
}
