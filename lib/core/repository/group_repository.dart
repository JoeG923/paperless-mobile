import 'package:equatable/equatable.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/persistent_repository.dart';
import 'package:paperless_mobile/features/logging/data/logger.dart';

part 'group_repository_state.dart';

class GroupRepository extends PersistentRepository<GroupRepositoryState> {
  final PaperlessGroupsApi _groupsApi;

  GroupRepository(this._groupsApi) : super(const GroupRepositoryState());

  Future<void> initialize() async {
    await findAll();
  }

  Future<Iterable<GroupModel>> findAll() async {
    try {
      final groups = await _groupsApi.findAll();
      emit(state.copyWith(groups: {for (var g in groups) g.id: g}));
      return groups;
    } on PaperlessApiException catch (e) {
      logger.fw(
        "Failed to fetch groups: ${e.code}",
        className: 'GroupRepository',
        methodName: 'findAll',
      );
      return [];
    }
  }
}
