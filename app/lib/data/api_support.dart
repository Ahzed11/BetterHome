import 'package:betterhome/data/models.dart';
import 'package:betterhome_api/api.dart' as api;
import 'package:http/http.dart' as http;

/// Builds a client for one service of the generated API. The bearer token comes from
/// [accessToken], read on every call, so a refreshed token is used without rebuilding it.
api.ApiClient buildApiClient({
  required String baseUrl,
  required String Function() accessToken,
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

/// Runs a generated call and turns its failures and empty answers into [ApiException]. The
/// generated models require the fields the contract marks as required: an answer without one
/// fails their parsing (an assertion in debug builds, a type error in release builds).
Future<T> call<T>(Future<T?> Function() request) async {
  final T? result;
  try {
    result = await request();
  } on api.ApiException catch (e) {
    throw ApiException(e.message ?? 'HTTP ${e.code}', statusCode: e.code);
  } on AssertionError catch (e) {
    throw ApiException('Unexpected response: ${e.message}');
  } on TypeError catch (e) {
    throw ApiException('Unexpected response: $e');
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
