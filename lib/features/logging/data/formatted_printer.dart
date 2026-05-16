import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:paperless_mobile/features/logging/data/log_redactor.dart';
import 'package:paperless_mobile/features/logging/models/formatted_log_message.dart';

class FormattedPrinter extends LogPrinter {
  static final _timestampFormat = DateFormat("yyyy-MM-dd HH:mm:ss.SSS");
  static const _mulitlineObjectEncoder = JsonEncoder.withIndent(null);

  @override
  List<String> log(LogEvent event) {
    final unformattedMessage = event.message;
    final rawFormattedMessage = switch (unformattedMessage) {
      FormattedLogMessage m => m.format(),
      Iterable i =>
        _mulitlineObjectEncoder
            .convert(i)
            .padLeft(FormattedLogMessage.maxLength),
      Map m =>
        _mulitlineObjectEncoder
            .convert(m)
            .padLeft(FormattedLogMessage.maxLength),
      _ => unformattedMessage.toString().padLeft(FormattedLogMessage.maxLength),
    };
    final formattedMessage = rawFormattedMessage.redactForLogs();
    final formattedLevel = event.level.name.toUpperCase().padRight(
      Level.values.map((e) => e.name.length).max,
    );
    final formattedTimestamp = _timestampFormat.format(event.time);

    return [
      '$formattedTimestamp\t$formattedLevel --- $formattedMessage',
      if (event.error != null) ...[
        "---BEGIN ERROR---",
        LogRedactor.redact(event.error),
        "---END ERROR---",
      ],
      if (event.stackTrace != null) ...[
        "---BEGIN STACKTRACE---",
        LogRedactor.redact(event.stackTrace),
        "---END STACKTRACE---",
      ],
    ];
  }
}
