import 'package:betterhome/data/server_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading an address', () {
    test('a bare host name means HTTPS', () {
      final server = ServerConfig.parse('home.example.com');

      expect(server.toString(), 'https://home.example.com');
      expect(server?.host, 'home.example.com');
    });

    test('spaces and trailing slashes are dropped', () {
      expect(
        ServerConfig.parse('  https://home.example.com//  ').toString(),
        'https://home.example.com',
      );
    });

    test('a port and a path are kept', () {
      final server = ServerConfig.parse('https://nas.example.ts.net:8443/bh/');

      expect(server.toString(), 'https://nas.example.ts.net:8443/bh');
      expect(server?.host, 'nas.example.ts.net:8443');
    });

    test('plain HTTP is accepted only for development hosts', () {
      expect(ServerConfig.parse('http://10.0.2.2:8081'), isNotNull);
      expect(ServerConfig.parse('http://localhost:8180'), isNotNull);
      expect(ServerConfig.parse('http://home.example.com'), isNull);
    });

    test('anything that is not a server address is refused', () {
      for (final input in [
        '',
        '   ',
        'ftp://home.example.com',
        'https://',
        'https://user:pass@home.example.com',
        'https://home.example.com/?x=1',
        'https://home.example.com/#top',
      ]) {
        expect(ServerConfig.parse(input), isNull, reason: input);
      }
    });
  });

  test('the URLs follow the layout of ADR 0029', () {
    final server = ServerConfig.parse('https://home.example.com');

    expect(server?.issuer, 'https://home.example.com/auth/realms/betterhome');
    expect(server?.householdsUrl, 'https://home.example.com/api/households');
    expect(server?.tasksUrl, 'https://home.example.com/api/tasks');
    expect(server?.scoringUrl, 'https://home.example.com/api/scoring');
    expect(server?.listsUrl, 'https://home.example.com/api/lists');
    expect(
      server?.notificationsUrl,
      'https://home.example.com/api/notifications',
    );
  });

  test('the URLs sit under the path of the address', () {
    final server = ServerConfig.parse('https://example.com/bh');

    expect(server?.issuer, 'https://example.com/bh/auth/realms/betterhome');
    expect(server?.tasksUrl, 'https://example.com/bh/api/tasks');
  });

  test('two spellings of one address are equal', () {
    expect(
      ServerConfig.parse('Home.Example.com/'),
      ServerConfig.parse('https://home.example.com'),
    );
  });
}
