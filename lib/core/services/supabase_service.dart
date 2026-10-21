import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/constants/app_config.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/router/app_navigator.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final Logger _logger = Logger();
  final SessionManager _sessionManager = Get.find<SessionManager>();

  // This is the reusable Edge Function handler
  // Add this to the callEdgeFunction method parameters
  /// Turns an error reply into a response, keeping the body's `message`,
  /// `code` and `transactionId`.
  @visibleForTesting
  static SupabaseApiResponse<T> errorFromBody<T>(String body, int status) {
    String errorMsg = 'Something went wrong. Please try again.';
    String? errorCode;
    String? errorTxn;
    try {
      final parsed = json.decode(body);
      if (parsed is Map) {
        errorMsg = parsed['message']?.toString() ??
            parsed['error']?.toString() ??
            errorMsg;
        errorCode = parsed['code']?.toString();
        errorTxn = parsed['transactionId']?.toString();
      }
    } catch (_) {}
    return SupabaseApiResponse.error(errorMsg,
        code: status, errorCode: errorCode, errorTransactionId: errorTxn);
  }

  Future<SupabaseApiResponse<dynamic>> callEdgeFunction(
    String functionName, {
    required Map<String, dynamic> body,
    bool requireAuth = true,
    bool isFormData = false,
    Map<String, dynamic>? queryParams,
    String method = 'POST',
    bool isRetryAfterRefresh = false,
    Map<String, String>? extraHeaders,
    bool returnHeaders = false,
  }) async {
    try {
      var session = _client.auth.currentSession;

      // If no current session but we have a saved session, try to restore it
      if (requireAuth && session == null) {
        final savedSession = _sessionManager.getSupabaseSession();
        if (savedSession != null && _sessionManager.isSessionValid()) {
          session = savedSession;
        }
      }
      _logger.d(session?.accessToken);

      // Ensure user is logged in if required
      if (requireAuth && session?.accessToken == null) {
        return SupabaseApiResponse.error(
          'Authentication required. Please login.',
          code: 401,
        );
      }

      // Prepare headers
      Map<String, String> headers = {};
      if (requireAuth && session?.accessToken != null) {
        headers['Authorization'] = 'Bearer ${session!.accessToken}';
      }

      if (isFormData) {
        // Handle form-data requests
        return _callEdgeFunctionWithFormData(
          functionName,
          body: body,
          headers: headers,
          queryParams: queryParams,
        );
      } else {
        // Build URL — always use http package so we can control the HTTP method
        final baseUrl =
            '${AppConfig.acslSupabaseURL}/functions/v1/$functionName';
        var uri = Uri.parse(baseUrl);
        if (queryParams != null && queryParams.isNotEmpty) {
          uri = uri.replace(
            queryParameters: queryParams.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          );
        }

        final reqHeaders = {
          ...headers,
          'Content-Type': 'application/json',
          // Conditional-request headers (If-None-Match) ride here. Added last
          // so a caller can override, never so it can drop the Authorization.
          ...?extraHeaders,
        };

        http.Response response;
        final upperMethod = method.toUpperCase();
        if (upperMethod == 'GET') {
          response = await http.get(uri, headers: reqHeaders);
        } else if (upperMethod == 'DELETE') {
          response = await http.delete(uri, headers: reqHeaders);
        } else if (upperMethod == 'PUT') {
          response = await http.put(uri,
              headers: reqHeaders, body: json.encode(body));
        } else if (upperMethod == 'PATCH') {
          response = await http.patch(uri,
              headers: reqHeaders, body: json.encode(body));
        } else {
          response = await http.post(uri,
              headers: reqHeaders, body: json.encode(body));
        }

        final respHeaders = returnHeaders
            ? response.headers.map((k, v) => MapEntry(k.toLowerCase(), v))
            : const <String, String>{};

        if (response.statusCode == 200) {
          return SupabaseApiResponse.success(
            json.decode(response.body),
            headers: respHeaders,
          );
        } else if (response.statusCode == 304) {
          // Not an error: the caller sent If-None-Match and its cached copy is
          // still current. Without this branch a 304 would fall through to the
          // error path below and a good cache would look like a failed fetch.
          return SupabaseApiResponse.notModified(headers: respHeaders);
        } else if (response.statusCode == 401 && requireAuth && !isRetryAfterRefresh) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            return await callEdgeFunction(
              functionName,
              body: body,
              requireAuth: requireAuth,
              isFormData: isFormData,
              queryParams: queryParams,
              method: method,
              isRetryAfterRefresh: true,
              extraHeaders: extraHeaders,
              returnHeaders: returnHeaders,
            );
          } else {
            return SupabaseApiResponse.error(
              'Session expired. Please login again.',
              code: 401,
            );
          }
        } else {
          _logger.e('Function [$functionName] failed: ${response.body}');
          return errorFromBody(response.body, response.statusCode);
        }
      }
    } on FunctionException catch (e) {
      _logger.e('FunctionException: $e');

      // Check if it's a 401 unauthorized error
      if (e.status == 401 && !isRetryAfterRefresh) {
        // Try refresh once
        final refreshed = await _refreshToken();
        if (refreshed) {
          return await callEdgeFunction(
            functionName,
            body: body,
            requireAuth: requireAuth,
            isFormData: isFormData,
            queryParams: queryParams,
            method: method,
            isRetryAfterRefresh: true,
          );
        } else {
          return SupabaseApiResponse.error(
            'Session expired. Please login again.',
            code: 401,
          );
        }
      } else {
        String errorMsg = e.reasonPhrase ?? 'Unknown error';
        final details = e.details;
        if (details is Map) {
          errorMsg = details['message']?.toString() ?? errorMsg;
        } else if (details is String && details.isNotEmpty) {
          try {
            final parsed = json.decode(details) as Map?;
            errorMsg = parsed?['message']?.toString() ?? errorMsg;
          } catch (_) {
            errorMsg = details;
          }
        }
        return SupabaseApiResponse.error('Function error: $errorMsg', code: e.status);
      }
    } on TimeoutException {
      return SupabaseApiResponse.error('Request timed out. Try again.');
    } on SocketException {
      return SupabaseApiResponse.error('Check your internet connection.');
    } catch (e) {
      _logger.e('Unexpected error: $e');
      return SupabaseApiResponse.error('Unexpected error occurred.');
    }
  }

  // Also update the _callEdgeFunctionWithFormData method to support query parameters
  Future<SupabaseApiResponse<dynamic>> _callEdgeFunctionWithFormData(
    String functionName, {
    required Map<String, dynamic> body,
    required Map<String, String> headers,
    Map<String, dynamic>? queryParams,
  }) async {
    _logger.e('UPLOAD BEGAN');
    try {
      String baseUrl =
          '${AppConfig.acslSupabaseURL}/functions/v1/$functionName';
      Uri uri = Uri.parse(baseUrl);

      // Add query parameters if provided
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(
            queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value.toString()),
        ));
      }

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll(headers);

      // Add form fields and files
      for (var entry in body.entries) {
        if (entry.value is File) {
          final file = entry.value as File;
          final fileName = file.path.split('/').last;
          final contentType = _getContentType(fileName);

          request.files.add(
            await http.MultipartFile.fromPath(
              entry.key,
              file.path,
              contentType: contentType,
            ),
          );
        } else if (entry.value is List &&
            entry.value.isNotEmpty &&
            entry.value.first is File) {
          // Handle list of files
          for (var file in entry.value) {
            final fileName = file.path.split('/').last;
            final contentType = _getContentType(fileName);

            request.files.add(
              await http.MultipartFile.fromPath(
                '${entry.key}[]',
                file.path,
                contentType: contentType,
              ),
            );
          }
        } else {
          // Add regular form fields
          request.fields[entry.key] = entry.value.toString();
        }
      }

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      _logger.e('UPLOAD FILE RESPONSE BODY: ${response.body}');
      _logger.e('UPLOAD FILE RESPONSE CODE: ${response.statusCode}');
      _logger.e('UPLOAD FILE RESPONSE HEADERS: ${response.headers}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return SupabaseApiResponse.success(responseData);
      } else {
        _logger.e('Form data request failed: ${response.body}');
        return SupabaseApiResponse.error(
          'Error: ${response.body}',
          code: response.statusCode,
        );
      }
    } catch (e) {
      _logger.e('Form data request error: $e');
      return SupabaseApiResponse.error('Error processing form data: $e');
    }
  }

  // Helper to determine content type from file extension
  MediaType _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  /// Optionally expose auth session if needed
  Session? get currentSession => _client.auth.currentSession;

  /// Refresh token manually
  Future<bool> _refreshToken() async {
    try {
      _logger.d('Attempting to refresh token...');

      // First try to get the session from Supabase client
      var currentSession = _client.auth.currentSession;

      // If no current session, try to restore from storage
      if (currentSession == null) {
        _logger.d('No current session, trying to restore from storage...');
        final savedSession = _sessionManager.getSupabaseSession();

        if (savedSession?.refreshToken != null) {
          _logger.d('Found saved session with refresh token');
          currentSession = savedSession;
        } else {
          _logger.e('No refresh token available in storage');
          _handleRefreshFailure();
          return false;
        }
      }

      if (currentSession?.refreshToken == null) {
        _logger.e('No refresh token available');
        _handleRefreshFailure();
        return false;
      }

      // Validate refresh token before attempting refresh
      if (currentSession!.refreshToken!.isEmpty) {
        _logger.e('Refresh token is empty');
        _handleRefreshFailure();
        return false;
      }

      _logger.d('Refreshing session with refresh token...');
      final result =
          await _client.auth.refreshSession(currentSession.refreshToken!);

      if (result.session != null && result.session!.accessToken.isNotEmpty) {
        _logger.d('Token refresh successful');

        // Update session manager with new session
        _sessionManager.saveSupabaseSession(result.session);

        // Update token in session manager for compatibility
        _sessionManager.setToken(result.session!.accessToken);

        _logger.d('Session data updated in storage');
        return true;
      } else {
        _logger.e('Token refresh failed: No valid session returned');
        _handleRefreshFailure();
        return false;
      }
    } catch (e) {
      _logger.e('Token refresh failed: $e');

      // Handle specific refresh token errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('refresh_token_not_found') ||
          errorString.contains('invalid refresh token') ||
          errorString.contains('refresh token not found') ||
          errorString.contains('session_not_found')) {
        _logger
            .e('Invalid or expired refresh token, forcing re-authentication');
        _handleRefreshFailure();
      }

      return false;
    }
  }

  /// Handle refresh token failure by clearing session and redirecting to login
  void _handleRefreshFailure() {
    _logger.d(
        'Handling refresh failure - clearing session and redirecting to login');
    _sessionManager.logout();

    // Redirect to login on the next frame. The router redirect also guards
    // unauthenticated access, so this is belt-and-suspenders.
    WidgetsBinding.instance.addPostFrameCallback((_) => goLogin());
  }
}
