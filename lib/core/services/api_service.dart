// ignore_for_file: prefer_interpolation_to_compose_strings, avoid_print, prefer_const_constructors, unused_import, no_leading_underscores_for_local_identifiers, unused_local_variable, depend_on_referenced_packages, unused_field, unnecessary_null_comparison

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http/intercepted_client.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/interceptor/api_interceptor.dart';
import 'package:stove_transaction/core/model/base_api_response_model.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/shared/components/bottom_sheet/get_x_bottom_sheet.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class ApiService {
  final http.Client _httpClient = http.Client();
  static const int _timeoutDuration = 35;
  Logger logger = Logger();
  static final client = InterceptedClient.build(
    interceptors: [AuthorizationInterceptor()],
    retryPolicy: ExpiredTokenRetryPolicy(),
  );

  static final unAuthorizedClient = InterceptedClient.build(
    interceptors: [AuthorizationInterceptor()],
  );

  Future<BaseApiResponse<dynamic>> Function()? retryApiCall;

  Future<BaseApiResponse> checkTokenAndCallApi(
    String? sourceType,
    Future<BaseApiResponse> Function() apiCall,
  ) async {
    retryApiCall = apiCall;
    if (sourceType == 'login' || sourceType == 'register') {
      return apiCall();
    } else {
      ExpiredTokenRetryPolicy retryPolicy = ExpiredTokenRetryPolicy();
      bool isTokenExpired = await retryPolicy.getIsTokenExpired();
      if (isTokenExpired) {
        bool callRefresh =
            await retryPolicy.tokenAuthController.refreshToken(Get.context!);
        if (callRefresh) {
          return apiCall();
        } else {
          return BaseApiResponse(
            code: -1,
            message: 'Token refresh failed',
            body: null,
          );
        }
      } else {}
      return apiCall();
    }
  }

  Map<String, String>? userAuthorizationJson({bool isUnAuthorized = false}) {
    final SessionManager _sessionManager = Get.find<SessionManager>();
    String _token = _sessionManager.token.toString();
    logger.w(_token);
    return isUnAuthorized
        ? {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          }
        : {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          };
  }

  Future<BaseApiResponse> get(
    String url, {
    Map<String, dynamic>? queryParams,
    String? sourceType,
  }) async {
    return checkTokenAndCallApi(sourceType, () async {
      final _headers = userAuthorizationJson(
        isUnAuthorized: sourceType == 'login' || sourceType == 'register',
      );
      // logger.i(_headers);
      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri.parse(url);
        final queryParameters = queryParams.map((key, value) {
          if (value is bool) return MapEntry(key, value.toString());
          return MapEntry(key, value);
        });
        url = uri.replace(queryParameters: queryParameters).toString();
      }
      logger.w(url);
      return executeRequest(
        () => (sourceType == "login" || sourceType == "register")
            ? unAuthorizedClient.get(Uri.parse(url), headers: _headers)
            : client.get(Uri.parse(url), headers: _headers),
      );
    });
  }

  Future<BaseApiResponse> post(
    String url, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    String? sourceType,
  }) async {
    return checkTokenAndCallApi(sourceType, () async {
      final headers = userAuthorizationJson(
        isUnAuthorized: sourceType == 'login' || sourceType == 'register',
      );

      if (queryParams != null) {
        url += '?' + Uri(queryParameters: queryParams).query;
      }

      String jsonBody = body != null ? jsonEncode(body) : '';
      // String jsonBody = jsonEncode(theBody);

      // String jsonBody2 = body != null ? jsonDecode(body) : '';
      logger.d(body);
      logger.w(url);
      return executeRequest(
        () => (sourceType == "login" || sourceType == "register")
            ? unAuthorizedClient.post(
                Uri.parse(url),
                headers: headers,
                body: jsonBody,
              )
            : client.post(
                Uri.parse(url),
                headers: headers,
                body: jsonBody,
              ),
      );
    });
  }

  Future<BaseApiResponse> put(
    String url,
    dynamic body, // Accepts int, String, or Map
  ) async {
    return checkTokenAndCallApi(null, () async {
      final _headers = userAuthorizationJson();

      // Determine how to encode the body
      String jsonBody;
      if (body is Map) {
        jsonBody = jsonEncode(body); // JSON object
      } else {
        jsonBody = body.toString(); // Raw integer or string
      }

      print('PUT $url');
      print('Body: $jsonBody');

      return executeRequest(
        () => client.put(
          Uri.parse(url),
          headers: _headers,
          body: jsonBody,
        ),
      );
    });
  }

  Future<BaseApiResponse> delete(String url) async {
    return checkTokenAndCallApi(null, () async {
      final _headers = userAuthorizationJson();
      final response = await client
          .delete(Uri.parse(url), headers: _headers)
          .timeout(Duration(seconds: _timeoutDuration));
      return _handleResponse(response);
    });
  }

  Future<BaseApiResponse> sendFile(
    String url,
    File file,
    String fileType,
  ) async {
    return checkTokenAndCallApi(null, () async {
      final headers = userAuthorizationJson();

      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(headers!)
        ..files.add(await http.MultipartFile.fromPath('file', file.path))
        ..fields['fileType'] = fileType;

      final response = await request.send();
      return _handleResponse(await http.Response.fromStream(response));
    });
  }

  Future<BaseApiResponse> executeRequest(
    Future<http.Response> Function() requestMethod,
  ) async {
    const _timeoutDuration = 25;
    try {
      final response = await requestMethod().timeout(
        Duration(seconds: _timeoutDuration),
        onTimeout: () => throw TimeoutException('The connection timed out.'),
      );
      logger.d(response.body);
      // logger.d(response.headers);
      return _handleResponse(response);
    } on TimeoutException catch (_) {
      // isLoadingRetry.value = false;
      infoBottomSheet(
        title: 'Unstable Connection',
        message: 'Timeout occurred. Please Retry',
        buttonTitle: 'Retry',
        onTaps: () {
          // isLoadingRetry.value = true;
          retryApiCall?.call();
          Navigator.of(Get.context!).pop();
        },
      );
      return BaseApiResponse(
        code: -1,
        message: 'Timeout occurred',
        body: null,
        showSheetAlert: false,
      );
    } on SocketException catch (_) {
      showInfoToast(
        title: 'Information',
        message: 'Please check your internet and retry',
      );
      return BaseApiResponse(
        code: -1,
        message: 'SocketException occurred',
        body: null,
      );
    } on FormatException catch (_) {
      logger.d(_);
      return BaseApiResponse(
        code: -1,
        message: 'FormatException occurred',
        body: null,
      );
    } catch (e) {
      showErrorToast(title: 'Error', message: 'An unexpected error occurred');
      logger.d(e);
      return BaseApiResponse(
        code: -1,
        message: 'Unexpected error occurred ',
        body: null,
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    try {
      final decodedBody = json.decode(response.body);
      // logger.w(decodedBody);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BaseApiResponse(
          code: response.statusCode,
          message: decodedBody['message'] ?? '',
          body: decodedBody['data'],
          success: decodedBody['isSuccessful'] ?? true,
        );
      } else if (response.statusCode == 400) {
        String errorMessage = 'An error occurred';
        if (decodedBody.containsKey('description')) {
          final description = decodedBody['description'];
          final reasonMatch = RegExp(r'Reason:\s*(.*)').firstMatch(description);
          if (reasonMatch != null) {
            errorMessage = reasonMatch.group(1) ?? errorMessage;
          } else {
            errorMessage = description;
          }
        }
        return BaseApiResponse(
          code: response.statusCode,
          message: errorMessage,
          body: decodedBody['data'],
          success: false,
        );
      } else {
        showErrorToast(
            title: 'Error',
            message: decodedBody['message'] ?? 'An error occurred');
        return BaseApiResponse(
          code: response.statusCode,
          message: decodedBody['message'] ?? decodedBody['errors'] ?? '',
          body: decodedBody['data'],
          success: decodedBody['isSuccessful'] ?? false,
        );
      }
    } catch (e) {
      if (json.decode(response.body).containsKey('errors')) {
        final errors = json.decode(response.body)['errors'];
        if (errors is Map) {
          final errorsString = errors.values.join('\n');
          showErrorToast(
              title: 'Error',
              message: errorsString ?? 'Unexpected error occurred');
        }
      }
      return BaseApiResponse(
        code: response.statusCode,
        message: 'Unexpected error occurred',
        body: null,
        success: false,
      );
    }
  }
}
