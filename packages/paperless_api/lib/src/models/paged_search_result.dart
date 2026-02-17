import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paged_search_result.g.dart';

const pageRegex = r".*page=(\d+).*";

class PagedSearchResultJsonSerializer<T> {
  final Map<String, dynamic> json;
  JsonConverter<T, Object?> converter;

  PagedSearchResultJsonSerializer(this.json, this.converter);
}

@JsonSerializable(genericArgumentFactories: true)
class PagedSearchResult<T> extends Equatable {
  /// Total number of available items
  final int count;

  /// Link to next page
  final String? next;

  /// Link to previous page
  final String? previous;

  /// Actual items
  final List<T> results;

  int get pageKey {
    if (next != null) {
      final matches = RegExp(pageRegex).allMatches(next!);
      final group = matches.first.group(1)!;
      final nextPageKey = int.parse(group);
      return nextPageKey - 1;
    }
    if (previous != null) {
      // This is only executed if it's the last page or there is no data.
      final matches = RegExp(pageRegex).allMatches(previous!);
      if (matches.isEmpty) {
        //In case there is a match but a page is not explicitly set, the page is 1 per default. Therefore, if the previous page is 1, this page is 1+1=2
        return 2;
      }
      final group = matches.first.group(1)!;
      final previousPageKey = int.parse(group);
      return previousPageKey + 1;
    }
    return 1;
  }

  int get pageSize => results.length;

  const PagedSearchResult({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PagedSearchResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) => _$PagedSearchResultFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$PagedSearchResultToJson(this, toJsonT);

  factory PagedSearchResult.fromJsonSingleParam(
    PagedSearchResultJsonSerializer<T> serializer,
  ) {
    return PagedSearchResult.fromJson(
      serializer.json,
      serializer.converter.fromJson,
    );
  }

  PagedSearchResult<T> copyWith({
    int? count,
    String? next,
    String? previous,
    List<T>? results,
  }) {
    return PagedSearchResult(
      count: count ?? this.count,
      next: next ?? this.next,
      previous: previous ?? this.previous,
      results: results ?? this.results,
    );
  }

  ///
  /// Returns the number of pages based on the given [pageSize]. The last page
  /// might not exhaust its capacity.
  ///
  int inferPageCount({required int pageSize}) {
    if (pageSize == 0) {
      return 0;
    }
    return (count / pageSize).round() + 1;
  }

  @override
  List<Object?> get props => [count, next, previous, results];
}
