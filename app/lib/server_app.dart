import 'package:betterhome/app.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/server_config.dart';
import 'package:betterhome/data/server_probe.dart';
import 'package:betterhome/server_stack.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/server_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The app when the server is chosen at run time (T-0115, ADR 0029): the first launch asks for its
/// address and remembers it; "Change server" on the sign-in screen forgets it again. Builds the real
/// stack for the remembered server and hands it to [BetterHomeApp].
class ServerApp extends StatefulWidget {
  const ServerApp({
    super.key,
    required this.preferences,
    required this.buildStack,
    this.client,
    this.initialLocale,
  });

  final SharedPreferences preferences;
  final ServerStack Function(ServerConfig server) buildStack;

  /// The HTTP client that checks an address; a real one unless a test provides its own.
  final http.Client? client;
  final Locale? initialLocale;

  @override
  State<ServerApp> createState() => _ServerAppState();

  /// Where the address is remembered.
  static const preferenceKey = 'server_url';
}

class _ServerAppState extends State<ServerApp> {
  late final http.Client _client = widget.client ?? http.Client();
  ServerConfig? _server;
  ServerStack? _stack;
  bool _demo = false;

  @override
  void initState() {
    super.initState();
    final stored = widget.preferences.getString(ServerApp.preferenceKey);
    final server = stored == null ? null : ServerConfig.parse(stored);
    if (server != null) {
      _server = server;
      _stack = widget.buildStack(server);
    }
  }

  @override
  void dispose() {
    if (widget.client == null) {
      _client.close();
    }
    super.dispose();
  }

  Future<void> _save(ServerConfig server) async {
    await widget.preferences.setString(
      ServerApp.preferenceKey,
      server.toString(),
    );
    setState(() {
      _server = server;
      _stack = widget.buildStack(server);
    });
  }

  Future<void> _forget() async {
    await widget.preferences.remove(ServerApp.preferenceKey);
    setState(() {
      _server = null;
      _stack = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stack = _stack;
    final server = _server;
    if (_demo) {
      return BetterHomeApp(
        key: const ValueKey('demo'),
        session: AppSession(
          repository: FakeHouseholdsRepository(),
          preferences: widget.preferences,
        ),
        initialLocale: widget.initialLocale,
      );
    }
    if (stack != null && server != null) {
      return BetterHomeApp(
        key: ValueKey(server),
        session: stack.session,
        auth: stack.auth,
        serverHost: server.host,
        onChangeServer: _forget,
        initialLocale: widget.initialLocale,
      );
    }
    return buildAppMaterial(
      locale: widget.initialLocale,
      home: ServerSetupScreen(
        check: (server) => isBetterHomeServer(server, _client),
        onSaved: _save,
        onDemo: () => setState(() => _demo = true),
      ),
    );
  }
}
