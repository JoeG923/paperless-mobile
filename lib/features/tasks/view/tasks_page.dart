import 'package:flutter/material.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:paperless_mobile/routing/routes/documents_route.dart';
import 'package:provider/provider.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late Future<Iterable<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _loadTasks();
  }

  Future<Iterable<Task>> _loadTasks() {
    return context.read<PaperlessTasksApi>().findAll();
  }

  Future<void> _refresh() async {
    setState(() {
      _tasksFuture = _loadTasks();
    });
    await _tasksFuture;
  }

  Future<void> _acknowledgeTask(Task task) async {
    try {
      final tasksApi = context.read<PaperlessTasksApi>();
      final pendingTasksNotifier = context.read<PendingTasksNotifier>();

      await tasksApi.acknowledgeTask(task);
      final taskId = task.taskId;
      if (taskId != null) {
        await pendingTasksNotifier.acknowledgeTasks([taskId]);
      }
      if (!mounted) return;
      showSnackBar(context, S.of(context)!.taskAcknowledged);
      await _refresh();
    } on PaperlessApiException catch (error, stackTrace) {
      if (!mounted) return;
      showErrorMessage(context, error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.tasksTitle),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Consumer<PendingTasksNotifier>(
        builder: (context, notifier, _) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<Iterable<Task>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                final pendingTasks = notifier.value.values;
                final serverTasks = snapshot.data ?? const [];
                final combined = <int, Task>{
                  for (final task in serverTasks) task.id: task,
                  for (final task in pendingTasks) task.id: task,
                };
                final tasks =
                    combined.values.where((task) => !task.acknowledged).toList()
                      ..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

                if (snapshot.hasError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: 120),
                      Center(child: Text(S.of(context)!.couldNotLoadTasks)),
                    ],
                  );
                }

                if (tasks.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: 120),
                      Center(child: Text(S.of(context)!.noPendingTasks)),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final status = task.status;
                    final statusLabel = _statusLabel(status);
                    final subtitle = task.result?.isNotEmpty == true
                        ? task.result!
                        : (task.taskFileName ?? statusLabel);
                    final canAcknowledge =
                        status == TaskStatus.success ||
                        status == TaskStatus.failure;

                    return ListTile(
                      leading: Icon(_statusIcon(status)),
                      title: Text(
                        _taskTitle(context, task),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: canAcknowledge
                          ? IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () => _acknowledgeTask(task),
                            )
                          : Text(
                              statusLabel,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                      onTap: task.relatedDocument != null
                          ? () {
                              DocumentDetailsRoute(
                                id: task.relatedDocument!,
                              ).push(context);
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _taskTitle(BuildContext context, Task task) {
    if (task.taskFileName != null) return task.taskFileName!;
    if (task.type == 'llm_index') return 'LLM Index';
    return S.of(context)!.taskFallbackTitle(task.id);
  }

  String _statusLabel(TaskStatus? status) {
    switch (status) {
      case TaskStatus.pending:
        return S.of(context)!.taskStatusPending;
      case TaskStatus.started:
        return S.of(context)!.taskStatusProcessing;
      case TaskStatus.success:
        return S.of(context)!.taskStatusCompleted;
      case TaskStatus.failure:
        return S.of(context)!.taskStatusFailed;
      default:
        return S.of(context)!.taskStatusUnknown;
    }
  }

  IconData _statusIcon(TaskStatus? status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.schedule;
      case TaskStatus.started:
        return Icons.sync;
      case TaskStatus.success:
        return Icons.check_circle_outline;
      case TaskStatus.failure:
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }
}
