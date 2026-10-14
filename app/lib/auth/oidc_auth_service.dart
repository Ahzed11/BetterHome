import 'package:betterhome/auth/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

/// Keycloak sign-in with the authorization code flow and PKCE, on Android and on the web.
/// The manager refreshes the access token before it expires.
class OidcAuthService implements AuthService {
  OidcAuthService({
    required Uri issuer,
    required String clientId,
    required Uri redirectUri,
    required Uri postLogoutRedirectUri,
    http.Client? httpClient,
  }) : _manager = OidcUserManager.lazy(
         discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(issuer),
         clientCredentials: OidcClientAuthentication.none(clientId: clientId),
         store: OidcDefaultStore(),
         httpClient: httpClient,
         settings: OidcUserManagerSettings(
           scope: const ['openid', 'profile', 'email'],
           redirectUri: redirectUri,
           postLogoutRedirectUri: postLogoutRedirectUri,
         ),
       );

  /// The redirect pages and URIs of this app, for the platform it runs on.
  /// Web serves `web/redirect.html`; Android uses the scheme of its application id
  /// (`oidcRedirectScheme` in `android/app/build.gradle.kts`).
  factory OidcAuthService.forPlatform({
    required Uri issuer,
    required String clientId,
    http.Client? httpClient,
  }) {
    final redirect = kIsWeb
        ? Uri.base.resolve('redirect.html')
        : Uri.parse('com.betterhome.betterhome:/oauth2redirect');
    return OidcAuthService(
      issuer: issuer,
      clientId: clientId,
      redirectUri: redirect,
      postLogoutRedirectUri: redirect,
      httpClient: httpClient,
    );
  }

  final OidcUserManager _manager;

  @override
  Future<AuthUser?> restore() async {
    await _manager.init();
    return _toAuthUser(_manager.currentUser);
  }

  @override
  Future<AuthUser?> signIn() async {
    try {
      return _toAuthUser(await _manager.loginAuthorizationCodeFlow());
    } on OidcException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> signOut() => _manager.logout();

  @override
  String accessToken() => _manager.currentUser?.token.accessToken ?? '';

  AuthUser? _toAuthUser(OidcUser? user) {
    if (user == null) {
      return null;
    }
    return authUserFromClaims(user.claims.toJson());
  }
}
