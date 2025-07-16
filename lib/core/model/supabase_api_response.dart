class SupabaseApiResponse<T> {
  final int? code;
  final String message;
  final bool success;
  final T? data;

  SupabaseApiResponse({
    this.code,
    required this.message,
    this.data,
    this.success = false,
  });

  factory SupabaseApiResponse.success(T data, {int? code = 200}) {
    return SupabaseApiResponse(
      code: code,
      message: 'Success',
      data: data,
      success: true,
    );
  }

  factory SupabaseApiResponse.error(String message, {int? code}) {
    return SupabaseApiResponse(
      code: code,
      message: message,
      data: null,
      success: false,
    );
  }
}
