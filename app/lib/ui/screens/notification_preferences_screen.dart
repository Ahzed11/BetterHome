import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/notification_labels.dart';
import 'package:betterhome/ui/widgets/add_field.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/app_toast.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:betterhome/ui/widgets/toggle_row.dart';
import 'package:flutter/material.dart';

/// One switch per notification type and channel (spec section 5: users toggle each type).
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  late Future<List<NotificationPreference>> _future;
  Map<(NotificationType, NotificationChannel), bool> _enabled = {};
  bool _pushRegistered = false;

  /// What the server accepts as a Gotify application token (the contract's pattern).
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9._~-]+$');

  NotificationsRepository get _repository =>
      widget.session.notificationsRepository;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repository.preferences().then((list) async {
      _enabled = {for (final p in list) (p.type, p.channel): p.enabled};
      _pushRegistered = await _repository.hasPushTarget();
      return list;
    });
  }

  Future<void> _set(
    NotificationType type,
    NotificationChannel channel,
    bool enabled,
  ) async {
    await runGuarded(context, () async {
      final saved = await _repository.setPreference(
        type,
        channel,
        enabled: enabled,
      );
      if (mounted) {
        setState(() => _enabled[(type, channel)] = saved.enabled);
      }
    });
  }

  Future<void> _registerPush(String token) async {
    if (!_tokenPattern.hasMatch(token)) {
      showAppToast(
        context,
        message: AppLocalizations.of(context).pushTokenInvalid,
        error: true,
      );
      return;
    }
    await runGuarded(context, () async {
      await _repository.registerPushTarget(token);
      if (mounted) {
        setState(() => _pushRegistered = true);
      }
    });
  }

  Future<void> _removePush() async {
    await runGuarded(context, () async {
      await _repository.removePushTarget();
      if (mounted) {
        setState(() => _pushRegistered = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<List<NotificationPreference>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: Text(l10n.loading));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.errorGeneric),
                  TextButton(
                    onPressed: () => setState(_reload),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceLg - AppTokens.spaceXs,
              0,
              AppTokens.spaceLg - AppTokens.spaceXs,
              AppTokens.spaceLg,
            ),
            children: [
              ScreenHeader(title: l10n.notificationSettings),
              const SizedBox(height: AppTokens.spaceMd),
              SectionLabel(l10n.pushSection),
              const SizedBox(height: AppTokens.spaceSm),
              _PushCard(
                l10n: l10n,
                registered: _pushRegistered,
                onRegister: _registerPush,
                onRemove: _removePush,
              ),
              for (final type in NotificationType.values) ...[
                const SizedBox(height: AppTokens.spaceMd),
                _TypeCard(
                  l10n: l10n,
                  type: type,
                  enabled: _enabled,
                  onChanged: _set,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.l10n,
    required this.type,
    required this.enabled,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final NotificationType type;
  final Map<(NotificationType, NotificationChannel), bool> enabled;
  final Future<void> Function(NotificationType, NotificationChannel, bool)
  onChanged;

  @override
  Widget build(BuildContext context) {
    final typeLabel = notificationTypeLabel(l10n, type);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceMd,
              AppTokens.spaceSm,
              AppTokens.spaceMd,
              0,
            ),
            child: Text(
              typeLabel,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final channel in NotificationChannel.values)
            ToggleRow(
              label: notificationChannelLabel(l10n, channel),
              semanticLabel:
                  '$typeLabel, ${notificationChannelLabel(l10n, channel)}',
              value: enabled[(type, channel)] ?? true,
              onChanged: (value) => onChanged(type, channel, value),
            ),
        ],
      ),
    );
  }
}

/// Where the user pastes the application token of their own Gotify app (ADR 0027).
class _PushCard extends StatelessWidget {
  const _PushCard({
    required this.l10n,
    required this.registered,
    required this.onRegister,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final bool registered;
  final ValueChanged<String> onRegister;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              registered ? l10n.pushOn : l10n.pushOff,
              style: AppTypography.body,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            AddField(
              label: l10n.pushTokenLabel,
              hint: l10n.pushTokenHint,
              buttonLabel: l10n.pushSave,
              onSubmitted: onRegister,
            ),
            if (registered)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: onRemove,
                  child: Text(l10n.pushRemove),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
