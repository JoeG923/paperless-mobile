import 'package:paperless_api/src/models/group_model.dart';

abstract class PaperlessGroupsApi {
  Future<Iterable<GroupModel>> findAll();
  Future<GroupModel> find(int id);
}
