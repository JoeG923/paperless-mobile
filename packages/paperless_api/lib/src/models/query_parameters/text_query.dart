import 'package:hive_ce/hive.dart';
import 'package:paperless_api/config/hive/hive_type_ids.dart';

import 'query_type.dart';

part 'text_query.g.dart';

@HiveType(typeId: PaperlessApiHiveTypeIds.textQuery)
class TextQuery {
  @HiveField(0)
  final QueryType queryType;
  @HiveField(1)
  final String? queryText;

  const TextQuery({this.queryType = QueryType.titleAndContent, this.queryText});

  const TextQuery.title(this.queryText) : queryType = QueryType.title;

  const TextQuery.titleAndContent(this.queryText)
    : queryType = QueryType.titleAndContent;

  const TextQuery.extended(this.queryText) : queryType = QueryType.extended;

  TextQuery copyWith({QueryType? queryType, String? queryText}) {
    return TextQuery(
      queryType: queryType ?? this.queryType,
      queryText: queryText ?? this.queryText,
    );
  }

  Map<String, String> toQueryParameter({int apiVersion = 9}) {
    final params = <String, String>{};
    if (queryText != null && queryText!.isNotEmpty) {
      params.addAll({
        queryType.queryParamForApiVersion(apiVersion): queryText!,
      });
    }
    return params;
  }

  String? get titleOnlyMatchString {
    if (queryType == QueryType.title) {
      return queryText?.isEmpty ?? true ? null : queryText;
    }
    return null;
  }

  String? get titleAndContentMatchString {
    if (queryType == QueryType.titleAndContent) {
      return queryText?.isEmpty ?? true ? null : queryText;
    }
    return null;
  }

  String? get extendedMatchString {
    if (queryType == QueryType.extended) {
      return queryText?.isEmpty ?? true ? null : queryText;
    }
    return null;
  }

  bool matches({required String title, String? content, int? asn}) {
    if (queryText?.isEmpty ?? true) return true;
    switch (queryType) {
      case QueryType.title:
        return _containsIgnoreCase(title, queryText!);
      case QueryType.titleAndContent:
        return _containsIgnoreCase(title, queryText!) ||
            _containsIgnoreCase(content, queryText!);
      case QueryType.extended:
        return _matchesExtendedQuery(
          query: queryText!,
          title: title,
          content: content,
          asn: asn,
        );
      case QueryType.asn:
        return int.tryParse(queryText!) == asn;
    }
  }

  bool _matchesExtendedQuery({
    required String query,
    required String title,
    required String? content,
    required int? asn,
  }) {
    final terms = RegExp(r'-?(?:[A-Za-z_]+:"[^"]+"|"[^"]+"|\S+)')
        .allMatches(query)
        .map((match) => match.group(0)!)
        .map(_QueryTerm.parse)
        .where((term) => term.value.isNotEmpty)
        .toList();
    if (terms.isEmpty) {
      return true;
    }

    for (final term in terms) {
      final doesMatch = term.matches(title: title, content: content, asn: asn);
      if (!term.negated && !doesMatch) {
        return false;
      }
      if (term.negated && doesMatch) {
        return false;
      }
    }
    return true;
  }

  bool _containsIgnoreCase(String? source, String query) {
    if (source == null) {
      return false;
    }
    return source.toLowerCase().contains(query.toLowerCase());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TextQuery) return false;
    if (queryText == null && other.queryText == null) {
      return true;
    }
    return other.queryText == queryText && other.queryType == queryType;
  }

  @override
  String toString() {
    return "TextQuery($queryText, $queryType)";
  }

  @override
  int get hashCode => Object.hash(queryText, queryType);
}

enum _QueryTermField { title, content, asn, any }

class _QueryTerm {
  final _QueryTermField field;
  final String value;
  final bool negated;

  const _QueryTerm({
    required this.field,
    required this.value,
    required this.negated,
  });

  factory _QueryTerm.parse(String raw) {
    var token = raw.trim();
    var negated = false;
    if (token.startsWith('-')) {
      negated = true;
      token = token.substring(1);
    }
    if (token.startsWith('"') && token.endsWith('"') && token.length >= 2) {
      token = token.substring(1, token.length - 1);
    }

    final separatorIndex = token.indexOf(':');
    if (separatorIndex <= 0 || separatorIndex == token.length - 1) {
      return _QueryTerm(
        field: _QueryTermField.any,
        value: token.trim(),
        negated: negated,
      );
    }

    final fieldToken = token.substring(0, separatorIndex).toLowerCase();
    final valueToken = _trimWrappedQuotes(
      token.substring(separatorIndex + 1).trim(),
    );
    final field = switch (fieldToken) {
      'title' => _QueryTermField.title,
      'content' => _QueryTermField.content,
      'asn' => _QueryTermField.asn,
      _ => _QueryTermField.any,
    };

    return _QueryTerm(field: field, value: valueToken, negated: negated);
  }

  static String _trimWrappedQuotes(String value) {
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  bool matches({
    required String title,
    required String? content,
    required int? asn,
  }) {
    final normalizedValue = value.toLowerCase();
    if (normalizedValue.isEmpty) {
      return true;
    }
    switch (field) {
      case _QueryTermField.title:
        return title.toLowerCase().contains(normalizedValue);
      case _QueryTermField.content:
        return (content ?? '').toLowerCase().contains(normalizedValue);
      case _QueryTermField.asn:
        return asn?.toString() == normalizedValue;
      case _QueryTermField.any:
        return title.toLowerCase().contains(normalizedValue) ||
            (content ?? '').toLowerCase().contains(normalizedValue) ||
            asn?.toString() == normalizedValue;
    }
  }
}
