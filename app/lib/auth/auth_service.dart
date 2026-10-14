/// The signed-in user, as far as the identity provider tells us.
class AuthUser {
  const AuthUser({
    required this.subject,
    required this.email,
    this.givenName,
    this.familyName,
  });

  final String subject;
  final String email;
  final String? givenName;
  final String? familyName;
}

/// Why signing in did not complete.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The identity provider boundary (Keycloak, behind OIDC). Repositories read [accessToken] on
/// every call, so a refreshed token is used without rebuilding them.
abstract class AuthService {
  /// Starts the service and returns the user of a session left by an earlier run, if any.
  Future<AuthUser?> restore();

  /// Runs the interactive sign-in. Returns null when the user closed the sign-in without finishing.
  Future<AuthUser?> signIn();

  Future<void> signOut();

  /// The current access token, or an empty string when nobody is signed in.
  String accessToken();
}

/// Reads the user from OIDC claims; throws [AuthException] when the identity provider omits one
/// the backend needs.
AuthUser authUserFromClaims(Map<String, Object?> claims) {
  final subject = claims['sub'];
  final email = claims['email'];
  if (subject is! String || email is! String) {
    throw const AuthException('The identity provider sent no subject or email');
  }
  final given = claims['given_name'];
  final family = claims['family_name'];
  return AuthUser(
    subject: subject,
    email: email,
    givenName: given is String ? given : null,
    familyName: family is String ? family : null,
  );
}
