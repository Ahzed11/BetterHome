import 'package:betterhome/data/models.dart';
import 'package:betterhome_api/api.dart' as api;
import 'package:http/http.dart' as http;

/// Builds a client for one service of the generated API. The bearer token is sent on every call.
api.ApiClient buildApiClient({
  required String baseUrl,
  required String accessToken,
  http.Client? client,
}) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final auth = api.HttpBearerAuth()..accessToken = accessToken;
  final apiClient = api.ApiClient(basePath: base, authentication: auth);
  if (client != null) {
    apiClient.client = client;
  }
  return apiClient;
}

/// Runs a generated call and turns its failures and empty answers into [ApiException].
Future<T> call<T>(Future<T?> Function() request) async {
  final T? result;
  try {
    result = await request();
  } on api.ApiException catch (e) {
    throw ApiException(e.message ?? 'HTTP ${e.code}', statusCode: e.code);
  }
  if (result == null) {
    throw ApiException('Empty response');
  }
  return result;
}

/// Like [call], for operations without a body in the answer.
Future<void> callVoid(Future<void> Function() request) async {
  try {
    await request();
  } on api.ApiException catch (e) {
    throw ApiException(e.message ?? 'HTTP ${e.code}', statusCode: e.code);
  }
}

/// The contract marks no response field as required, so the app checks the ones it needs.
T need<T>(T? value, String field) {
  if (value == null) {
    throw ApiException('Missing field in response: $field');
  }
  return value;
}
