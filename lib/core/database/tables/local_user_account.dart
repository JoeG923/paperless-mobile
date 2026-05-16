import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';

part 'local_user_account.g.dart';

@HiveType(typeId: HiveTypeIds.localUserAccount)
class LocalUserAccount extends HiveObject {
  @HiveField(0)
  final String serverUrl;

  @HiveField(3)
  final String id;

  @HiveField(4)
  final LocalUserSettings settings;

  @HiveField(7)
  UserModel paperlessUser;

  /// API version this client should request for the account.
  ///
  /// This may be lower than [serverApiVersion] when a newer server advertises
  /// an API version the app does not support yet.
  @HiveField(8, defaultValue: 2)
  int apiVersion;

  /// Raw API version last advertised by the server response header.
  @HiveField(9)
  int serverApiVersion;

  LocalUserAccount({
    required this.id,
    required this.serverUrl,
    required this.settings,
    required this.paperlessUser,
    required this.apiVersion,
    int? serverApiVersion,
  }) : serverApiVersion = serverApiVersion ?? apiVersion;

  bool get hasMultiUserSupport => apiVersion >= 3;
}
