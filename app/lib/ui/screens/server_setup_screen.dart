import 'package:betterhome/data/server_config.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

enum _Problem { invalid, unreachable }

/// Asks which server the app talks to: shown on first launch and after "Change server". The address
/// is checked (it must be a BetterHome server) before [onSaved] is called.
class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({
    super.key,
    required this.check,
    required this.onSaved,
    required this.onDemo,
    this.initial = '',
  });

  /// Whether the server answers as a BetterHome server.
  final Future<bool> Function(ServerConfig server) check;
  final void Function(ServerConfig server) onSaved;
  final VoidCallback onDemo;
  final String initial;

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  late final TextEditingController _address = TextEditingController(
    text: widget.initial,
  );
  bool _busy = false;
  _Problem? _problem;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final server = ServerConfig.parse(_address.text);
    if (server == null) {
      setState(() => _problem = _Problem.invalid);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final ok = await widget.check(server);
    if (!mounted) {
      return;
    }
    if (ok) {
      widget.onSaved(server);
    } else {
      setState(() {
        _busy = false;
        _problem = _Problem.unreachable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = switch (_problem) {
      _Problem.invalid => l10n.serverInvalid,
      _Problem.unreachable => l10n.serverUnreachable,
      null => null,
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              children: [
                const SizedBox(height: AppTokens.spaceLg),
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    l10n.serverSetupTitle,
                    style: AppTypography.display.copyWith(fontSize: 30),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  l10n.serverSetupBody,
                  style: AppTypography.bodyMuted.copyWith(fontSize: 15),
                ),
                const SizedBox(height: AppTokens.spaceLg),
                TextField(
                  controller: _address,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.serverAddress,
                    hintText: l10n.serverAddressHint,
                    errorText: error,
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceLg),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? l10n.serverChecking : l10n.continueLabel),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, AppTokens.minTapTarget),
                  ),
                  onPressed: _busy ? null : widget.onDemo,
                  child: Text(l10n.useDemoData),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
