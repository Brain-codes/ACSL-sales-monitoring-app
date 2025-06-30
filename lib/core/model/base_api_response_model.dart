class BaseApiResponse<T> {
  final int? code;
  final String message;
  final bool? isSuccessful;
  final bool showSheetAlert;
  final T? body;

  BaseApiResponse({
    this.code,
    required this.message,
    this.body,
    this.isSuccessful,
    this.showSheetAlert = true,
  });

  factory BaseApiResponse.fromJson(
      Map<String, dynamic> json, Function fromJson) {
    return BaseApiResponse(
      code: json['code'] as int,
      message: json['message'] as String,
      isSuccessful: json['isSuccessful'] as bool,
      showSheetAlert: json['showSheetAlert'] as bool,
      body: fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'isSuccessful': isSuccessful,
      'showSheetAlert': showSheetAlert,
      'data': body,
    };
  }

  factory BaseApiResponse.fromError(String message, {int? code}) {
    return BaseApiResponse(
      code: code,
      message: message,
      isSuccessful: false,
      showSheetAlert: true,
      body: null,
    );
  }
}
