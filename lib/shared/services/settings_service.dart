// ignore_for_file: camel_case_types

import 'package:stove_transaction/core/services/api_service.dart';

class SettingsService {
  final ApiService apiService;
  SettingsService(this.apiService);

  // Future<BaseApiResponse> logout() async {
  //   return apiService.get('${AppConfig.blukardApiBaseURL}auth/logout');
  // }
}
