import 'package:hive_ce/hive.dart';
import 'package:paperless_api/config/hive/hive_type_ids.dart';

part 'query_type.g.dart';

@HiveType(typeId: PaperlessApiHiveTypeIds.queryType)
enum QueryType {
  @HiveField(0)
  title('title__icontains'),
  @HiveField(1)
  titleAndContent('title_content'),
  @HiveField(2)
  extended('query'),
  @HiveField(3)
  asn('asn');

  final String queryParam;
  const QueryType(this.queryParam);

  String queryParamForApiVersion(int apiVersion) {
    if (apiVersion >= 10) {
      return switch (this) {
        QueryType.title => 'title_search',
        QueryType.titleAndContent => 'text',
        QueryType.extended => 'query',
        QueryType.asn => 'asn',
      };
    }
    return queryParam;
  }
}
