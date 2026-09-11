class SupabaseApiResponse<T> {
  final int? code;
  final String message;
  final bool success;
  final T? data;

  /// Response headers, lower-cased, when the caller asked for them.
  ///
  /// Empty for every existing call site. Needed by callers that revalidate a
  /// cache, which read `etag` here and send it back as `If-None-Match`.
  final Map<String, String> headers;

  SupabaseApiResponse({
    this.code,
    required this.message,
    this.data,
    this.success = false,
    this.headers = const {},
  });

  factory SupabaseApiResponse.success(
    T data, {
    int? code = 200,
    Map<String, String> headers = const {},
  }) {
    return SupabaseApiResponse(
      code: code,
      message: 'Success',
      data: data,
      success: true,
      headers: headers,
    );
  }

  /// A 304 Not Modified: the caller's cached copy is still current.
  ///
  /// Success with no body — distinguished from a normal success by [code], so a
  /// caller can keep what it already has instead of treating it as a failure.
  factory SupabaseApiResponse.notModified({
    Map<String, String> headers = const {},
  }) {
    return SupabaseApiResponse(
      code: 304,
      message: 'Not modified',
      data: null,
      success: true,
      headers: headers,
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
