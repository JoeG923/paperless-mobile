part of 'user_repository.dart';

class UserRepositoryState with EquatableMixin {
  final Map<int, UserModel> users;
  const UserRepositoryState({this.users = const {}});

  UserRepositoryState copyWith({Map<int, UserModel>? users}) {
    return UserRepositoryState(users: users ?? this.users);
  }

  @override
  List<Object?> get props => [users];
}
