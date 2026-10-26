import 'dart:async';
import 'dart:convert';

import 'package:betterhome/data/server_config.dart';
import 'package:http/http.dart' as http;

/// Asks [server] for its OpenID discovery document and checks the issuer it names is the one the
/// app derived from the address. That proves the address is a BetterHome server (and catches a typo
/// or a proxy that rewrites the host) before the app is configured with it.
Future<bool> isBetterHomeServer(
  ServerConfig server,
  http.Client client, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    final response = await client
        .get(Uri.parse('${server.issuer}/.well-known/openid-configuration'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      return false;
    }
    final body = jsonDecode(response.body);
    return body is Map<String, Object?> && body['issuer'] == server.issuer;
  } on http.ClientException {
    return false;
  } on TimeoutException {
    return false;
  } on FormatException {
    return false;
  }
}
