class AiApiResult {
  final bool success;
  final dynamic data;
  final String? errorMessage;

  const AiApiResult({required this.success, this.data, this.errorMessage});

  factory AiApiResult.success(dynamic data) {
    return AiApiResult(success: true, data: data);
  }

  factory AiApiResult.failure(String message) {
    return AiApiResult(success: false, errorMessage: message);
  }
}
