import 'package:betterhome/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('authUserFromClaims', () {
    test('reads the Keycloak claims', () {
      final user = authUserFromClaims({
        'sub': '8f4f4d36-6c02-4c63-9b1a-7a0f9d4c2a11',
        'email': 'ada@example.com',
        'given_name': 'Ada',
        'family_name': 'Lovelace',
      });

      expect(user.subject, '8f4f4d36-6c02-4c63-9b1a-7a0f9d4c2a11');
      expect(user.email, 'ada@example.com');
      expect(user.givenName, 'Ada');
      expect(user.familyName, 'Lovelace');
    });

    test('names are optional', () {
      final user = authUserFromClaims({'sub': 's', 'email': 'a@example.com'});

      expect(user.givenName, isNull);
      expect(user.familyName, isNull);
    });

    test('a missing or non-text subject or email is refused', () {
      for (final claims in <Map<String, Object?>>[
        {'email': 'a@example.com'},
        {'sub': 's'},
        {'sub': 5, 'email': 'a@example.com'},
        {'sub': 's', 'email': null},
      ]) {
        expect(
          () => authUserFromClaims(claims),
          throwsA(isA<AuthException>()),
          reason: '$claims',
        );
      }
    });

    test('a name that is not text is ignored', () {
      final user = authUserFromClaims({
        'sub': 's',
        'email': 'a@example.com',
        'given_name': 7,
      });

      expect(user.givenName, isNull);
    });
  });
}
