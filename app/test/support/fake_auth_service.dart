import 'package:betterhome/auth/auth_service.dart';

/// Stands in for the identity provider: a test decides who signs in and what goes wrong.
class FakeAuthService implements AuthService {
  FakeAuthService({this.restored, this.signsIn, this.failure});

  /// The user of a session left by an earlier run.
  AuthUser? restored;

  /// The user the interactive sign-in returns; null means the user closed it.
  AuthUser? signsIn;

  /// When set, [signIn] throws it.
  AuthException? failure;

  int signInCalls = 0;
  int signOutCalls = 0;
  String? _token;

  @override
  Future<AuthUser?> restore() async {
    _token = restored == null ? null : 'restored-token';
    return restored;
  }

  @override
  Future<AuthUser?> signIn() async {
    signInCalls++;
    final problem = failure;
    if (problem != null) {
      throw problem;
    }
    _token = signsIn == null ? null : 'fresh-token';
    return signsIn;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _token = null;
  }

  @override
  String accessToken() => _token ?? '';
}
