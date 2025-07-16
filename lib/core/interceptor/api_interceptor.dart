// ignore_for_file: avoid_print, unnecessary_null_comparison, overridden_fields

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:intl/intl.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/login/controller/login_controller.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

/// Authorization Interceptor
class AuthorizationInterceptor implements InterceptorContract {
  @override
  Future<RequestData> interceptRequest({required RequestData data}) async {
    try {
      final SessionManager _sessionManager = Get.find<SessionManager>();
      var token = _sessionManager.token.toString();

      if (token.isNotEmpty) {
        data.headers['authorization'] = 'Bearer $token';
        data.headers['content-type'] = 'application/json';
      }
    } catch (e) {
      print('Error in interceptRequest: $e');
    }
    return data;
  }

  @override
  Future<ResponseData> interceptResponse({required ResponseData data}) async {
    return data;
  }
}

/// Retry Policy for Token Expiration Handling
class ExpiredTokenRetryPolicy extends RetryPolicy {
  final LoginController tokenAuthController = Get.put(LoginController());

  @override
  int maxRetryAttempts = 1;

  DateTime parseDate(String dateString) {
    try {
      dateString = dateString.split('.')[0].replaceAll(' ', 'T');
      return DateFormat("yyyy-MM-ddTHH:mm:ss", 'en_US').parseUtc(dateString);
    } catch (e) {
      print("Error parsing date: $e");
      return DateTime.now();
    }
  }

  Future<bool> getIsTokenExpired() async {
    final SessionManager _sessionManager = Get.find<SessionManager>();
    var expiresIn = _sessionManager.getSupabaseSession()?.expiresIn ?? 0;

    if (expiresIn == null) {
      print("Error: tokenExpiration is null");
      return true;
    }

    String created = _sessionManager.timeLoggedIn ?? '';

    if (created.isEmpty) {
      print("Error: loginTimeCreated is empty");
      return true;
    }

    DateTime createdTime = parseDate(created);
    DateTime expirationTime = createdTime.add(Duration(seconds: expiresIn));
    DateTime currentTime = DateTime.now();

    if (currentTime.isAfter(expirationTime) ||
        currentTime.isAtSameMomentAs(expirationTime)) {
      return true;
    } else {
      Duration remainingTime = expirationTime.difference(currentTime);
      print(
        'Time left: ${remainingTime.inHours}h '
        '${remainingTime.inMinutes % 60}m '
        '${remainingTime.inSeconds % 60}s',
      );
      return false;
    }
  }

  @override
  Future<bool> shouldAttemptRetryOnResponse(ResponseData response) async {
    if (response.statusCode == 401) {
      Get.offAllNamed(AppRoutes.LOGIN);
      return false;
    } else if (response.statusCode == 403) {
      showInfoToast(title: 'ACSL Monitoring App', message: 'Permission Denied');
      return false;
    }
    return false;
  }
}
