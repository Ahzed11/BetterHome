import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/month_recap_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.session,
    required this.householdId,
  });

  final AppSession session;
  final String householdId;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  ScorePeriod _period = ScorePeriod.month;
  late Future<_BoardData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
    _showUnseenRecap();
  }

  /// Shows the recap of the newest month the user has not seen yet, once: it is recorded as seen
  /// before it is shown, so it never comes back.
  Future<void> _showUnseenRecap() async {
    final _BoardData data;
    try {
      data = await _future;
    } on Exception catch (_) {
      return; // The screen already shows the error.
    }
    final unseen = data.winners.where((w) => !w.celebrated).firstOrNull;
    if (unseen == null || !mounted) {
      return;
    }
    final recorded = await runGuarded(
      context,
      () => widget.session.scoringRepository.markRecapCelebrated(
        widget.householdId,
        unseen.yearMonth,
      ),
    );
    if (!recorded || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final month = _monthName(context, unseen.yearMonth);
    final winner = unseen.winnerUserId;
    final String message;
    if (winner == null || unseen.winnerPoints <= 0) {
      message = l10n.recapNobody(month);
    } else if (winner == widget.session.profile?.id) {
      message = l10n.recapWinnerYou(month, unseen.winnerPoints);
    } else {
      message = l10n.recapWinnerOther(
        _labelFor(l10n, winner, data.members),
        month,
        unseen.winnerPoints,
      );
    }
    await showDialog<void>(
      context: context,
      builder: (_) => MonthRecapDialog(
        title: l10n.recapTitle(month),
        message: message,
        detail: unseen.totalPoints > 0
            ? l10n.recapTotal(unseen.totalPoints)
            : null,
        closeLabel: l10n.recapClose,
      ),
    );
  }

  /// "September 2026" in the user's language, from `YYYY-MM`.
  String _monthName(BuildContext context, String yearMonth) {
    final parts = yearMonth.split('-');
    final date = DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.yMMMM(
      Localizations.localeOf(context).toString(),
    ).format(date);
  }

  void _reload() {
    _future = () async {
      final scoring = widget.session.scoringRepository;
      if (scoring is FakeScoringRepository) {
        final members = await widget.session.repository.listMembers(
          widget.householdId,
        );
        scoring.setMembers(members.map((m) => m.userId).toList());
        scoring.seedDemoIfEmpty(widget.householdId);
      }
      final board = await widget.session.scoringRepository.getScoreboard(
        widget.householdId,
        period: _period,
      );
      final winners = await widget.session.scoringRepository.listWinners(
        widget.householdId,
      );
      final members = await widget.session.repository.listMembers(
        widget.householdId,
      );
      return _BoardData(board: board, winners: winners, members: members);
    }();
  }

  String _labelFor(
    AppLocalizations l10n,
    String userId,
    List<Membership> members,
  ) {
    final match = members.where((m) => m.userId == userId);
    if (match.isEmpty) {
      return userId;
    }
    final member = match.first;
    if (member.userId == widget.session.profile?.id) {
      return l10n.you;
    }
    return userId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaderboardTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            child: SegmentedButton<ScorePeriod>(
              segments: [
                ButtonSegment(
                  value: ScorePeriod.week,
                  label: Text(l10n.periodWeek),
                ),
                ButtonSegment(
                  value: ScorePeriod.month,
                  label: Text(l10n.periodMonth),
                ),
                ButtonSegment(
                  value: ScorePeriod.year,
                  label: Text(l10n.periodYear),
                ),
                ButtonSegment(
                  value: ScorePeriod.all,
                  label: Text(l10n.periodAll),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (value) {
                setState(() {
                  _period = value.first;
                  _reload();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<_BoardData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(child: Text(l10n.loading));
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(child: Text(l10n.errorGeneric));
                }
                final data = snapshot.data!;
                final board = data.board;
                return ListView(
                  padding: const EdgeInsets.all(AppTokens.spaceMd),
                  children: [
                    Text(
                      l10n.podiumTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    if (board.podium.isEmpty)
                      Text(l10n.leaderboardEmpty)
                    else
                      ...board.podium.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTokens.brand.withValues(
                              alpha: 0.15,
                            ),
                            child: Text('${entry.rank}'),
                          ),
                          title: Text(
                            _labelFor(l10n, entry.userId, data.members),
                          ),
                          trailing: Text(l10n.pointsLabel(entry.points)),
                        ),
                      ),
                    const SizedBox(height: AppTokens.spaceLg),
                    Text(
                      l10n.effortBarTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    if (board.totalPoints == 0)
                      Text(l10n.leaderboardEmpty)
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        child: SizedBox(
                          height: 16,
                          child: Row(
                            children: board.entries
                                .where((e) => e.points > 0)
                                .map((e) {
                                  final colors = [
                                    AppTokens.brand,
                                    const Color(0xFF5BA89F),
                                    const Color(0xFF8FCFC7),
                                    const Color(0xFFB8E0DB),
                                  ];
                                  final color =
                                      colors[(e.rank - 1) % colors.length];
                                  return Expanded(
                                    flex: (e.effortShare * 1000).round().clamp(
                                      1,
                                      1000,
                                    ),
                                    child: ColoredBox(color: color),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppTokens.spaceSm),
                    ...board.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${_labelFor(l10n, e.userId, data.members)} · '
                          '${(e.effortShare * 100).round()}%',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceLg),
                    Text(
                      l10n.hallOfWinners,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    if (data.winners.isEmpty)
                      Text(l10n.noWinnersYet)
                    else
                      ...data.winners.map(
                        (w) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(w.yearMonth),
                          subtitle: Text(
                            w.winnerUserId == null
                                ? l10n.leaderboardEmpty
                                : _labelFor(
                                    l10n,
                                    w.winnerUserId!,
                                    data.members,
                                  ),
                          ),
                          trailing: Text(l10n.pointsLabel(w.winnerPoints)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardData {
  const _BoardData({
    required this.board,
    required this.winners,
    required this.members,
  });

  final Scoreboard board;
  final List<MonthlyWinner> winners;
  final List<Membership> members;
}
