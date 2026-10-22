/// The address of a BetterHome server and the URLs derived from it, following the layout of ADR 0029:
/// Keycloak under `/auth`, every service under `/api/<name>`.
class ServerConfig {
  const ServerConfig._(this.base);

  /// The address without a trailing slash, for example `https://home.example.com`.
  final Uri base;

  /// Hosts where plain HTTP is accepted, for development (the Android emulator reaches the host as
  /// 10.0.2.2). Everything else must be HTTPS.
  static const _localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

  /// Reads what a person typed: a bare host name means HTTPS. Returns null when it is not a usable
  /// server address (no host, a scheme other than HTTPS, credentials, a query or a fragment).
  static ServerConfig? parse(String input) {
    var text = input.trim();
    if (text.isEmpty) {
      return null;
    }
    if (!text.contains('://')) {
      text = 'https://$text';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    final secure = uri.scheme == 'https';
    final local = uri.scheme == 'http' && _localHosts.contains(uri.host);
    if (!secure && !local) {
      return null;
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      return null;
    }
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return ServerConfig._(uri.replace(path: path));
  }

  /// `host` or `host:port`, for showing which server the app talks to.
  String get host => base.hasPort ? '${base.host}:${base.port}' : base.host;

  String get _root => base.toString();

  String get issuer => '$_root/auth/realms/betterhome';
  String get householdsUrl => '$_root/api/households';
  String get tasksUrl => '$_root/api/tasks';
  String get scoringUrl => '$_root/api/scoring';
  String get listsUrl => '$_root/api/lists';
  String get notificationsUrl => '$_root/api/notifications';

  @override
  bool operator ==(Object other) => other is ServerConfig && other.base == base;

  @override
  int get hashCode => base.hashCode;

  @override
  String toString() => _root;
}
