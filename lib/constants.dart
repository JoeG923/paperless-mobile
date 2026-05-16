import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Globally accessible variables which are definitely initialized after main().
late final PackageInfo packageInfo;
late final AndroidDeviceInfo? androidInfo;
late final IosDeviceInfo? iosInfo;

const defaultRequestApiVersion = 9;
const latestSupportedApiVersion = 10;

/// Selects the request API version for the server version advertised by
/// paperless-ngx. v2 servers currently advertise API 9; v3 servers advertise
/// API 10. Future server versions are capped at the latest client-supported
/// version until the client implements newer behavior explicitly.
int selectedApiVersionForServer(int serverApiVersion) {
  if (serverApiVersion <= defaultRequestApiVersion) {
    return serverApiVersion;
  }
  if (serverApiVersion > latestSupportedApiVersion) {
    return latestSupportedApiVersion;
  }
  return serverApiVersion;
}
