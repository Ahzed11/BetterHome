# 0020 — The app signs in to Keycloak with the `oidc` package on Android and web

## Context

The app must authenticate through Keycloak (OIDC, authorization code flow with PKCE) on Android and on the web (AGENTS §3, spec §2). `flutter_appauth`, named in the first plan, has no web support (T-0069), so web would have needed a second mechanism.

## Decision

- **One library for both platforms:** `oidc` with `oidc_default_store` (OpenID Certified relying party, PKCE, silent refresh-token rotation, Android and web). Approved by the product owner on 2026-10-14. It brings platform plugins as transitive dependencies; no other auth library is added.
- **A seam at the identity-provider boundary:** `AuthService` (`restore`, `signIn`, `signOut`, `accessToken`) with `OidcAuthService` as the only code that imports `oidc`. Widget tests use a fake; the repositories read `accessToken()` on every call (a `String Function()` given to the generated client's bearer auth), so a refreshed token is used without rebuilding anything.
- **Profile sync only on first sign-in:** after sign-in the app calls `GET /v1/me`, and only on 404 `PUT /v1/me` with the token's `email`, `given_name`, `family_name` and the device language. A later sign-in never overwrites what the user saved, because `PUT /v1/me` upserts.
- **Redirects:** Android `com.betterhome.betterhome:/oauth2redirect` (scheme of the application id, set as the `oidcRedirectScheme` manifest placeholder); web `redirect.html` at the app origin (copied from the package, re-copy it when upgrading `oidc`). Keycloak accepts a wildcard only at the end of a redirect URI, so the realm lists the fixed web origin `http://localhost:8090` (the e2e web port; run `flutter run -d chrome --web-port 8090`) instead of `http://localhost:*`, and `webOrigins` is no longer `*`.
- **Web e2e signs in for real:** `app/test_driver/web_sign_in.dart` drives headless Chrome with WebDriver (`webdriver` dev dependency, already used inside `flutter_driver`) through Keycloak's login page, because `integration_test` cannot reach another origin. `tooling/e2e.sh` runs it before the repository journey, which still uses a token fetched by the script.

## Consequences

- On web, `oidc_default_store` keeps the tokens in browser storage (`localStorage`), where any injected script can read them. The library's tested path is accepted for now; whether to keep tokens in memory instead (a re-login on reload) is open, see T-0072.
- Android sign-in compiles and registers its redirect (debug APK built, merged manifest checked) but was not run on a device: the emulator crashes on the development VM (T-0045). On an emulator, Keycloak advertises `localhost:8180`, so `adb reverse tcp:8180 tcp:8180` is needed.
- Each new e2e journey after sign-in still needs either a WebDriver step or the injected token; extending the WebDriver journey is part of T-0021.
