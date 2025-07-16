import 'dart:convert';

BaseApiResponse baseApiResponseFromJson(String str, Function fromJson) =>
    BaseApiResponse.fromJson(json.decode(str), fromJson);

String baseApiResponseToJson(BaseApiResponse data) =>
    json.encode(data.toJson());

class BaseApiResponse<T> {
  final int? code;
  final String message;
  final bool? success;
  final bool showSheetAlert;
  final T? body;

  BaseApiResponse({
    this.code,
    required this.message,
    this.body,
    this.success,
    this.showSheetAlert = true,
  });

  factory BaseApiResponse.fromJson(
    Map<String, dynamic> json,
    Function fromJson,
  ) {
    return BaseApiResponse(
      code: json['code'] as int,
      message: json['message'] as String,
      success: json['success'] as bool,
      showSheetAlert: json['showSheetAlert'] as bool,
      body: fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'success': success,
      'showSheetAlert': showSheetAlert,
      'data': body,
    };
  }

  factory BaseApiResponse.fromError(String message, {int? code}) {
    return BaseApiResponse(
      code: code,
      message: message,
      success: false,
      showSheetAlert: true,
      body: null,
    );
  }
}
