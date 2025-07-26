import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/constants/app_config.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final Logger _logger = Logger();

  // This is the reusable Edge Function handler
  // Add this to the callEdgeFunction method parameters
  Future<SupabaseApiResponse<dynamic>> callEdgeFunction(
    String functionName, {
    required Map<String, dynamic> body,
    bool requireAuth = true,
    bool isFormData = false,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final session = _client.auth.currentSession;

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
          } else if (response.statusCode == 401) {
            // Try refresh once
            final refreshed = await _refreshToken();
            if (refreshed) {
              return await callEdgeFunction(
                functionName,
                body: body,
                requireAuth: requireAuth,
                isFormData: isFormData,
                queryParams: queryParams,
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
          } else if (response.status == 401) {
            // Try refresh once
            final refreshed = await _refreshToken();
            if (refreshed) {
              return await callEdgeFunction(
                functionName,
                body: body,
                requireAuth: requireAuth,
                isFormData: isFormData,
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
      final oldSession = _client.auth.currentSession;
      if (oldSession?.refreshToken == null) return false;

      final result = await _client.auth.refreshSession();
      _logger.d(result);
      return result.session != null;
    } catch (e) {
      _logger.e('Token refresh failed: $e');
      return false;
    }
  }
}
