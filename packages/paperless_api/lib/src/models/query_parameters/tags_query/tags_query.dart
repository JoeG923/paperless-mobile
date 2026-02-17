import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/config/hive/hive_type_ids.dart';

part 'tags_query.g.dart';

sealed class TagsQuery with EquatableMixin {
  const TagsQuery();
  Map<String, String> toQueryParameter();
  bool matches(Iterable<int> ids);
}

// @HiveType(typeId: PaperlessApiHiveTypeIds.notAssignedTagsQuery)
class NotAssignedTagsQuery extends TagsQuery {
  const NotAssignedTagsQuery();
  @override
  Map<String, String> toQueryParameter() {
    return {'is_tagged': '0'};
  }

  @override
  bool matches(Iterable<int> ids) => ids.isEmpty;

  @override
  List<Object?> get props => [];
}

@HiveType(typeId: PaperlessApiHiveTypeIds.anyAssignedTagsQuery)
class AnyAssignedTagsQuery extends TagsQuery {
  @HiveField(0)
  final List<int> tagIds;
  const AnyAssignedTagsQuery({this.tagIds = const []});

  @override
  Map<String, String> toQueryParameter() {
    if (tagIds.isEmpty) {
      return {'is_tagged': '1'};
    }
    return {'tags__id__in': tagIds.join(',')};
  }

  @override
  bool matches(Iterable<int> ids) => ids.isNotEmpty;

  AnyAssignedTagsQuery copyWith({List<int>? tagIds}) {
    return AnyAssignedTagsQuery(tagIds: tagIds ?? this.tagIds);
  }

  @override
  List<Object?> get props => [tagIds];
}

@HiveType(typeId: PaperlessApiHiveTypeIds.idsTagsQuery)
class IdsTagsQuery extends TagsQuery {
  @HiveField(0)
  final List<int> include;
  @HiveField(1)
  final List<int> exclude;
  const IdsTagsQuery({this.include = const [], this.exclude = const []});
  @override
  Map<String, String> toQueryParameter() {
    final Map<String, String> params = {};
    if (include.isNotEmpty) {
      params.putIfAbsent('tags__id__all', () => include.join(','));
    }
    if (exclude.isNotEmpty) {
      params.putIfAbsent('tags__id__none', () => exclude.join(','));
    }
    return params;
  }

  @override
  bool matches(Iterable<int> ids) {
    return include.toSet().difference(ids.toSet()).isEmpty &&
        exclude.toSet().intersection(ids.toSet()).isEmpty;
  }

  IdsTagsQuery copyWith({List<int>? include, List<int>? exclude}) {
    return IdsTagsQuery(
      include: include ?? this.include,
      exclude: exclude ?? this.exclude,
    );
  }

  @override
  List<Object?> get props => [include, exclude];
}

/// Custom adapters

class NotAssignedTagsQueryAdapter extends TypeAdapter<NotAssignedTagsQuery> {
  @override
  final int typeId = PaperlessApiHiveTypeIds.notAssignedTagsQuery;

  @override
  NotAssignedTagsQuery read(BinaryReader reader) {
    reader.readByte();
    return const NotAssignedTagsQuery();
  }

  @override
  void write(BinaryWriter writer, NotAssignedTagsQuery obj) {
    writer.writeByte(0);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotAssignedTagsQueryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
