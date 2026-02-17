import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:jiffy/jiffy.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:paperless_api/config/hive/hive_type_ids.dart';
import 'package:paperless_api/src/constants.dart';
import 'package:paperless_api/src/converters/local_date_time_json_converter.dart';

import 'date_range_query_field.dart';
import 'date_range_unit.dart';

part 'date_range_query.g.dart';

sealed class DateRangeQuery with EquatableMixin {
  const DateRangeQuery();

  Map<String, String> toQueryParameter(DateRangeQueryField field);

  bool matches(DateTime dt);
}

// @HiveType(typeId: PaperlessApiHiveTypeIds.unsetDateRangeQuery)
class UnsetDateRangeQuery extends DateRangeQuery {
  const UnsetDateRangeQuery();

  @override
  Map<String, String> toQueryParameter(DateRangeQueryField field) => const {};

  @override
  bool matches(DateTime dt) => true;

  @override
  List<Object?> get props => [];
}

@HiveType(typeId: PaperlessApiHiveTypeIds.relativeDateRangeQuery)
class RelativeDateRangeQuery extends DateRangeQuery {
  @HiveField(0)
  final int offset;
  @HiveField(1)
  final DateRangeUnit unit;

  const RelativeDateRangeQuery([
    this.offset = 1,
    this.unit = DateRangeUnit.day,
  ]);

  @override
  List<Object?> get props => [offset, unit];

  @override
  Map<String, String> toQueryParameter(DateRangeQueryField field) {
    return {'query': '${field.name}:[-$offset ${unit.name} to now]'};
  }

  RelativeDateRangeQuery copyWith({int? offset, DateRangeUnit? unit}) {
    return RelativeDateRangeQuery(offset ?? this.offset, unit ?? this.unit);
  }

  /// Returns the datetime when subtracting the offset given the unit from now.
  DateTime get dateTime {
    switch (unit) {
      case DateRangeUnit.day:
        return Jiffy.now().subtract(days: offset).dateTime;
      case DateRangeUnit.week:
        return Jiffy.now().subtract(weeks: offset).dateTime;
      case DateRangeUnit.month:
        return Jiffy.now().subtract(months: offset).dateTime;
      case DateRangeUnit.year:
        return Jiffy.now().subtract(years: offset).dateTime;
    }
  }

  @override
  bool matches(DateTime dt) {
    return dt.isAfter(dateTime) || dt == dateTime;
  }
}

@JsonSerializable()
@HiveType(typeId: PaperlessApiHiveTypeIds.absoluteDateRangeQuery)
class AbsoluteDateRangeQuery extends DateRangeQuery {
  @LocalDateTimeJsonConverter()
  @HiveField(0)
  final DateTime? after;

  @LocalDateTimeJsonConverter()
  @HiveField(1)
  final DateTime? before;

  const AbsoluteDateRangeQuery({this.after, this.before});

  @override
  List<Object?> get props => [after, before];

  @override
  Map<String, String> toQueryParameter(DateRangeQueryField field) {
    final Map<String, String> params = {};

    // Add/subtract one day in the following because paperless uses gt/lt not gte/lte
    if (after != null) {
      params.putIfAbsent(
        '${field.name}__date__gt',
        () => apiDateFormat.format(after!.subtract(const Duration(days: 1))),
      );
    }

    if (before != null) {
      params.putIfAbsent(
        '${field.name}__date__lt',
        () => apiDateFormat.format(before!.add(const Duration(days: 1))),
      );
    }
    return params;
  }

  AbsoluteDateRangeQuery copyWith({DateTime? before, DateTime? after}) {
    return AbsoluteDateRangeQuery(
      before: before ?? this.before,
      after: after ?? this.after,
    );
  }

  @override
  bool matches(DateTime dt) {
    //TODO: Check if after and before are inclusive or exclusive definitions.
    bool matches = true;
    if (after != null) {
      matches &= dt.isAfter(after!) || dt == after;
    }
    if (before != null) {
      matches &= dt.isBefore(before!) || dt == before;
    }
    return matches;
  }
}

class UnsetDateRangeQueryAdapter extends TypeAdapter<UnsetDateRangeQuery> {
  @override
  final int typeId = 113;

  @override
  UnsetDateRangeQuery read(BinaryReader reader) {
    reader.readByte();
    return const UnsetDateRangeQuery();
  }

  @override
  void write(BinaryWriter writer, UnsetDateRangeQuery obj) {
    writer.writeByte(0);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnsetDateRangeQueryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
