import 'dart:async';
import 'dart:convert';

import 'package:betterhome/data/server_config.dart';
import 'package:betterhome/data/server_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _server = ServerConfig.parse('https://home.example.com');
const _discovery =
    'https://home.example.com/auth/realms/betterhome/.well-known/openid-configuration';

Future<bool> _probe(http.Client client) => isBetterHomeServer(
  _server ?? (throw StateError('bad test address')),
  client,
  timeout: const Duration(milliseconds: 200),
);

void main() {
  test('the server that names the expected issuer is a BetterHome server', () {
    final client = MockClient((request) async {
      expect(request.url.toString(), _discovery);
      return http.Response(
        jsonEncode({'issuer': _server?.issuer}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    expect(_probe(client), completion(isTrue));
  });

  test('another issuer is not accepted', () {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'issuer': 'https://other.example.com/realms/x'}),
        200,
      ),
    );

    expect(_probe(client), completion(isFalse));
  });

  test('an error status, a page that is not JSON, or no object is refused', () {
    for (final response in [
      http.Response('nope', 404),
      http.Response('<html>login</html>', 200),
      http.Response('[1, 2]', 200),
    ]) {
      expect(_probe(MockClient((_) async => response)), completion(isFalse));
    }
  });

  test('no connection and no answer both mean unreachable', () {
    final refused = MockClient(
      (_) async => throw http.ClientException('connection refused'),
    );
    final silent = MockClient((_) => Completer<http.Response>().future);

    expect(_probe(refused), completion(isFalse));
    expect(_probe(silent), completion(isFalse));
  });
}
