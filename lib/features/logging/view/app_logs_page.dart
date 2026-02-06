import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:paperless_mobile/features/logging/cubit/app_logs_cubit.dart';
import 'package:paperless_mobile/features/logging/models/parsed_log_message.dart';
import 'package:paperless_mobile/core/extensions/dart_extensions.dart';
import 'package:paperless_mobile/core/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class AppLogsPage extends StatefulWidget {
  const AppLogsPage({super.key});

  @override
  State<AppLogsPage> createState() => _AppLogsPageState();
}

class _AppLogsPageState extends State<AppLogsPage> {
  final ScrollController _scrollController = ScrollController();

  bool autoScroll = true;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    return BlocBuilder<AppLogsCubit, AppLogsState>(
      builder: (context, state) {
        final formattedDate = DateFormat.yMMMd(locale).format(state.date);
        return Scaffold(
          bottomNavigationBar: BottomAppBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: switch (state) {
                AppLogsStateInitial() => [],
                AppLogsStateLoading() => [],
                AppLogsStateLoaded() => [
                  IconButton(
                    tooltip: S.of(context)!.copyToClipboard,
                    onPressed: () {
                      context.read<AppLogsCubit>().copyToClipboard(state.date);
                    },
                    icon: const Icon(Icons.copy),
                  ).padded(),
                  IconButton(
                    tooltip: S.of(context)!.saveLogsToFile,
                    onPressed: () {
                      context.read<AppLogsCubit>().saveLogs(state.date, locale);
                    },
                    icon: const Icon(Icons.download),
                  ).padded(),
                  IconButton(
                    tooltip: S.of(context)!.clearLogs(formattedDate),
                    onPressed: () {
                      context.read<AppLogsCubit>().clearLogs(state.date);
                    },
                    icon: Icon(
                      Icons.delete_sweep,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ).padded(),
                ],
                _ => [],
              },
            ),
          ),
          appBar: AppBar(
            title: Text(
              S.of(context)!.appLogs(formattedDate),
            ), //TODO: CHange to App-Logs in german
            actions: [
              if (state is AppLogsStateLoaded && state.availableLogs.isNotEmpty)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).datePickerHelpText,
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: state.date,
                      firstDate: state.availableLogs.first,
                      lastDate: state.availableLogs.last,
                      selectableDayPredicate: (day) => state.availableLogs.any(
                        (date) => day.isOnSameDayAs(date),
                      ),
                      initialEntryMode: DatePickerEntryMode.calendarOnly,
                    );
                    if (selectedDate != null && context.mounted) {
                      context.read<AppLogsCubit>().loadLogs(selectedDate);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                ).padded(),
            ],
          ),
          body: switch (state) {
            AppLogsStateLoaded(logs: var logs) => Builder(
              builder: (context) {
                if (state.logs.isEmpty) {
                  return Center(
                    child: Text(S.of(context)!.noLogsFoundOn(formattedDate)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Center(
                        child: Text(
                          S.of(context)!.logfileBottomReached,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ).padded(24);
                    }
                    final messages = state.logs;
                    final logMessage = messages[index - 1];
                    final altColor = CupertinoDynamicColor.withBrightness(
                      color: Colors.grey.shade200,
                      darkColor: Colors.grey.shade800,
                    ).resolveFrom(context);
                    return ParsedLogMessageTile(
                      message: logMessage,
                      backgroundColor: (index % 2 == 0)
                          ? theme.colorScheme.surface
                          : altColor,
                    );
                  },
                  itemCount: logs.length + 1,
                );
              },
            ),
            AppLogsStateError() => Center(
              child: Text(
                S.of(context)!.couldNotLoadLogfileFrom(formattedDate),
              ),
            ),
            _ => _buildLoadingLogs(state.date),
          },
        );
      },
    );
  }

  Widget _buildLoadingLogs(DateTime date) {
    final formattedDate = DateFormat.yMd(
      Localizations.localeOf(context).toString(),
    ).format(date);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          Text(S.of(context)!.loadingLogsFrom(formattedDate)),
        ],
      ),
    );
  }
}

class ParsedLogMessageTile extends StatelessWidget {
  final ParsedLogMessage message;
  final Color backgroundColor;

  const ParsedLogMessageTile({
    super.key,
    required this.message,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return switch (message) {
      ParsedFormattedLogMessage m => FormattedLogMessageWidget(
        message: m,
        backgroundColor: backgroundColor,
      ),
      UnformattedLogMessage(message: var m) => Text(m),
    };
  }
}

class FormattedLogMessageWidget extends StatelessWidget {
  final ParsedFormattedLogMessage message;
  final Color backgroundColor;
  const FormattedLogMessageWidget({
    super.key,
    required this.message,
    required this.backgroundColor,
  });
  static final _timeFormat = DateFormat("HH:mm:ss.SSS");
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    final icon = switch (message.level) {
      Level.trace => Icons.troubleshoot,
      Level.debug => Icons.bug_report,
      Level.info => Icons.info_outline,
      Level.warning => Icons.warning,
      Level.error => Icons.error,
      Level.fatal => Icons.error_outline,
      _ => null,
    };
    final color = switch (message.level) {
      Level.trace => c.onSurface.withAlpha(191),
      Level.warning => Colors.yellow.shade600,
      Level.error => Colors.red,
      Level.fatal => Colors.red.shade900,
      Level.info => Colors.blue,
      _ => c.onSurface,
    };

    final logStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 12);
    final formattedMethodName = message.methodName != null
        ? '${message.methodName!.trim()}()'
        : '';
    final source = switch (message.className) {
      '' || null => formattedMethodName,
      String className => '$className.$formattedMethodName',
    };
    return Material(
      color: backgroundColor,
      child: ExpansionTile(
        leading: Text(
          _timeFormat.format(message.timestamp),
          style: logStyle?.copyWith(color: color),
        ),
        title: Text(message.message, style: logStyle?.copyWith(color: color)),
        trailing: Icon(icon, color: color),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        expandedAlignment: Alignment.topLeft,
        children: source.isNotEmpty
            ? [
                Row(
                  children: [
                    const Icon(Icons.arrow_right),
                    Flexible(
                      child: Text(
                        'In $source',
                        style: logStyle?.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                ..._buildErrorWidgets(context),
              ]
            : _buildErrorWidgets(context),
      ),
    );
  }

  List<Widget> _buildErrorWidgets(BuildContext context) {
    if (message.error != null) {
      return [
        Divider(),
        Text(
          message.error!.error,
          style: TextStyle(color: Colors.red),
        ).padded(),
        if (message.error?.stackTrace != null) ...[
          Text(
            message.error!.stackTrace!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ).paddedOnly(left: 8),
        ],
      ];
    } else {
      return [];
    }
  }
}
