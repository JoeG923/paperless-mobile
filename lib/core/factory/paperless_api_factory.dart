import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';

abstract class PaperlessApiFactory {
  PaperlessDocumentsApi createDocumentsApi(
    Dio dio, {
    required int serverApiVersion,
  });
  PaperlessSavedViewsApi createSavedViewsApi(
    Dio dio, {
    required int apiVersion,
  });
  PaperlessLabelsApi createLabelsApi(Dio dio, {required int apiVersion});
  CustomFieldsApi createCustomFieldsApi(Dio dio, {required int apiVersion});
  PaperlessServerStatsApi createServerStatsApi(
    Dio dio, {
    required int apiVersion,
  });
  PaperlessTasksApi createTasksApi(Dio dio, {required int apiVersion});
  PaperlessAuthenticationApi createAuthenticationApi(Dio dio);
  PaperlessUserApi createUserApi(Dio dio, {required int apiVersion});
  PaperlessGroupsApi createGroupsApi(Dio dio, {required int apiVersion});
}
