part of 'group_repository.dart';

class GroupRepositoryState with EquatableMixin {
  final Map<int, GroupModel> groups;
  const GroupRepositoryState({this.groups = const {}});

  GroupRepositoryState copyWith({Map<int, GroupModel>? groups}) {
    return GroupRepositoryState(groups: groups ?? this.groups);
  }

  @override
  List<Object?> get props => [groups];
}
