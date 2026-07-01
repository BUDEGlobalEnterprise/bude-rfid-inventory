class ApiEnvelope<T> {
  final bool ok;
  final T? data;
  final String? message;
  final String? code;

  const ApiEnvelope({
    required this.ok,
    this.data,
    this.message,
    this.code,
  });

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) decode,
  ) {
    return ApiEnvelope<T>(
      ok: json['ok'] == true || json['success'] == true,
      data: json.containsKey('data') ? decode(json['data']) : null,
      message: json['message'] as String?,
      code: json['code'] as String?,
    );
  }
}
