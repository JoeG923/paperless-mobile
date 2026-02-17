import 'package:hive_ce/hive.dart';
import 'package:paperless_api/config/hive/hive_type_ids.dart';
part 'date_range_unit.g.dart';

@HiveType(typeId: PaperlessApiHiveTypeIds.dateRangeUnit)
enum DateRangeUnit {
  @HiveField(0)
  day,
  @HiveField(1)
  week,
  @HiveField(2)
  month,
  @HiveField(3)
  year,
}
