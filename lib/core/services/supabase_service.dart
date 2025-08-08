import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/constants/app_config.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final Logger _logger = Logger();
  final SessionManager _sessionManager = Get.find<SessionManager>();

  // This is the reusable Edge Function handler
  // Add this to the callEdgeFunction method parameters
  Future<SupabaseApiResponse<dynamic>> callEdgeFunction(
    String functionName, {
    required Map<String, dynamic> body,
    bool requireAuth = true,
    bool isFormData = false,
    Map<String, dynamic>? queryParams,
    bool isRetryAfterRefresh = false, // Flag to prevent infinite recursion
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
        // Standard JSON request using Supabase SDK
        // If we have query parameters, we need to build the URL manually
        if (queryParams != null && queryParams.isNotEmpty) {
          final baseUrl =
              '${AppConfig.acslSupabaseURL}/functions/v1/$functionName';
          final uri = Uri.parse(baseUrl).replace(
              queryParameters: queryParams.map(
            (key, value) => MapEntry(key, value.toString()),
          ));

          final response = await http.post(
            uri,
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          );

          if (response.statusCode == 200) {
            return SupabaseApiResponse.success(json.decode(response.body));
          } else if (response.statusCode == 401 && !isRetryAfterRefresh) {
            // Try refresh once
            final refreshed = await _refreshToken();
            if (refreshed) {
              return await callEdgeFunction(
                functionName,
                body: body,
                requireAuth: requireAuth,
                isFormData: isFormData,
                queryParams: queryParams,
                isRetryAfterRefresh: true,
              );
            } else {
              return SupabaseApiResponse.error(
                'Session expired. Please login again.',
                code: 401,
              );
            }
          } else {
            _logger.e('Function [$functionName] failed: ${response.body}');
            return SupabaseApiResponse.error(
              'Error: ${response.body}',
              code: response.statusCode,
            );
          }
        } else {
          // Use the standard Supabase SDK for requests without query parameters
          final response = await _client.functions.invoke(
            functionName,
            body: body,
            headers: headers,
          );

          if (response.status == 200) {
            return SupabaseApiResponse.success(response.data);
          } else if (response.status == 401 && !isRetryAfterRefresh) {
            // Try refresh once
            final refreshed = await _refreshToken();
            if (refreshed) {
              return await callEdgeFunction(
                functionName,
                body: body,
                requireAuth: requireAuth,
                isFormData: isFormData,
                isRetryAfterRefresh: true,
              );
            } else {
              return SupabaseApiResponse.error(
                'Session expired. Please login again.',
                code: 401,
              );
            }
          } else {
            _logger.e('Function [$functionName] failed: ${response.data}');
            return SupabaseApiResponse.error(
              'Error: ${response.data}',
              code: response.status,
            );
          }
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
            isRetryAfterRefresh: true,
          );
        } else {
          return SupabaseApiResponse.error(
            'Session expired. Please login again.',
            code: 401,
          );
        }
      } else {
        return SupabaseApiResponse.error(
          'Function error: ${e.details?['message'] ?? e.reasonPhrase ?? 'Unknown error'}',
          code: e.status,
        );
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

  Future<SupabaseApiResponse<List<Map<String, dynamic>>>> selectWhere({
    required String table,
    String? column,
    dynamic value,
  }) async {
    try {
      var query = Supabase.instance.client.from(table).select();

      if (column != null && value != null) {
        query = query.eq(column, value);
      }

      final response = await query;
      _logger.d(response);
      _logger.d(query);

      return SupabaseApiResponse.success(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      return SupabaseApiResponse.error('Select failed: ${e.toString()}');
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

    // Use Get.offAllNamed to ensure proper navigation stack clearing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute != '/login') {
        Get.offAllNamed('/login');
      }
    });
  }
}
