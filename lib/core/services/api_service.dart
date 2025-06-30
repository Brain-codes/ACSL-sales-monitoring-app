import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stove_transaction/core/model/base_api_response_model.dart';

class ApiService {
  static const String baseUrl =
      'https://your-api-base-url.com'; // TODO: Replace with your actual base URL

  static Future<BaseApiResponse<T>> get<T>(String endpoint,
      {Map<String, String>? headers, Function? fromJsonT}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 10));
      return _handleResponse<T>(response, fromJsonT);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  static Future<BaseApiResponse<T>> post<T>(String endpoint,
      {Map<String, dynamic>? body,
      Map<String, String>? headers,
      Function? fromJsonT}) async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/$endpoint'),
              headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return _handleResponse<T>(response, fromJsonT);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  static Future<BaseApiResponse<T>> put<T>(String endpoint,
      {Map<String, dynamic>? body,
      Map<String, String>? headers,
      Function? fromJsonT}) async {
    try {
      final response = await http
          .put(Uri.parse('$baseUrl/$endpoint'),
              headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return _handleResponse<T>(response, fromJsonT);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  static Future<BaseApiResponse<T>> delete<T>(String endpoint,
      {Map<String, String>? headers, Function? fromJsonT}) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 10));
      return _handleResponse<T>(response, fromJsonT);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  static BaseApiResponse<T> _handleResponse<T>(
      http.Response response, Function? fromJsonT) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      return BaseApiResponse<T>.fromJson(jsonResponse,
          (data) => fromJsonT != null ? fromJsonT(data) : data as T);
    } else {
      return BaseApiResponse<T>.fromError(
          'Request failed with status: ${response.statusCode}',
          code: response.statusCode);
    }
  }

  static BaseApiResponse<T> _handleError<T>(dynamic error) {
    if (error is http.ClientException) {
      return BaseApiResponse<T>.fromError('Network error: ${error.message}');
    } else if (error is FormatException) {
      return BaseApiResponse<T>.fromError(
          'Invalid response format: ${error.message}');
    } else if (error is Exception) {
      return BaseApiResponse<T>.fromError(
          'An unexpected error occurred: ${error.toString()}');
    } else {
      return BaseApiResponse<T>.fromError('Unknown error occurred.');
    }
  }
}
