import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/member_labels.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/member_avatar.dart';
import 'package:betterhome/ui/widgets/podium.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:betterhome/ui/widgets/segmented_tabs.dart';
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
      final household = await widget.session.repository.getHousehold(
        widget.householdId,
      );
      return _BoardData(
        board: board,
        winners: winners,
        members: members,
        household: household.name,
      );
    }();
  }

  String _labelFor(
    AppLocalizations l10n,
    String userId,
    List<Membership> members,
  ) {
    return memberLabel(
      l10n,
      members.where((m) => m.userId == userId).firstOrNull,
      widget.session.profile?.id,
    );
  }

  Color _colorFor(String userId, List<Membership> members) {
    final ordered = [...members]
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    final index = ordered.indexWhere((m) => m.userId == userId);
    return memberColor(index < 0 ? 0 : index);
  }

  Widget _heading(String text) => Semantics(
    container: true,
    header: true,
    child: Text(
      text,
      style: AppTypography.display.copyWith(fontSize: 17, height: 1.2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          FutureBuilder<_BoardData>(
            future: _future,
            builder: (context, snapshot) => ScreenHeader(
              eyebrow: snapshot.data?.household,
              title: l10n.leaderboardTitle,
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          SegmentedTabs<ScorePeriod>(
            labels: {
              ScorePeriod.week: l10n.periodWeek,
              ScorePeriod.month: l10n.periodMonth,
              ScorePeriod.year: l10n.periodYear,
              ScorePeriod.all: l10n.periodAll,
            },
            selected: _period,
            onSelected: (value) {
              setState(() {
                _period = value;
                _reload();
              });
            },
          ),
          const SizedBox(height: AppTokens.spaceMd),
          FutureBuilder<_BoardData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(child: Text(l10n.loading));
              }
              final data = snapshot.data;
              if (snapshot.hasError || data == null) {
                return Center(child: Text(l10n.errorGeneric));
              }
              final board = data.board;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (board.podium.isEmpty)
                    Text(l10n.leaderboardEmpty)
                  else
                    Podium(
                      emptyLabel: l10n.podiumRoom,
                      places: [
                        for (final entry in board.podium)
                          PodiumPlace(
                            rank: entry.rank,
                            label: _labelFor(l10n, entry.userId, data.members),
                            points: l10n.pointsLabel(entry.points),
                            color: _colorFor(entry.userId, data.members),
                          ),
                      ],
                    ),
                  const SizedBox(height: AppTokens.spaceMd),
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(child: _heading(l10n.effortBarTitle)),
                              Flexible(
                                child: Text(
                                  l10n.effortTogether(board.totalPoints),
                                  style: AppTypography.eyebrow.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTokens.spaceSm + 4),
                          if (board.totalPoints == 0)
                            Text(l10n.leaderboardEmpty)
                          else ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusPill,
                              ),
                              child: SizedBox(
                                key: const ValueKey('effort-bar'),
                                height: 14,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: 3,
                                  children: [
                                    for (final e in board.entries.where(
                                      (e) => e.points > 0,
                                    ))
                                      Expanded(
                                        flex: (e.effortShare * 1000)
                                            .round()
                                            .clamp(1, 1000),
                                        child: ColoredBox(
                                          color: _colorFor(
                                            e.userId,
                                            data.members,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTokens.spaceSm + 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: AppTokens.spaceXs,
                              children: [
                                for (final e in board.entries)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _colorFor(
                                            e.userId,
                                            data.members,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: const SizedBox.square(
                                          dimension: 10,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '${_labelFor(l10n, e.userId, data.members)} · '
                                          '${(e.effortShare * 100).round()}%',
                                          style: AppTypography.label,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                  _heading(l10n.hallOfWinners),
                  const SizedBox(height: AppTokens.spaceSm),
                  if (data.winners.isEmpty)
                    Text(l10n.noWinnersYet)
                  else
                    for (final w in data.winners) ...[
                      AppCard(
                        child: ListTile(
                          title: Text(
                            _monthName(context, w.yearMonth),
                            style: AppTypography.body,
                          ),
                          subtitle: Text(
                            w.winnerUserId == null
                                ? l10n.leaderboardEmpty
                                : _labelFor(
                                    l10n,
                                    w.winnerUserId!,
                                    data.members,
                                  ),
                          ),
                          trailing: Text(
                            l10n.pointsLabel(w.winnerPoints),
                            style: AppTypography.label.copyWith(
                              color: AppTokens.brand,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.spaceSm),
                    ],
                ],
              );
            },
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
    required this.household,
  });

  final String household;
  final Scoreboard board;
  final List<MonthlyWinner> winners;
  final List<Membership> members;
}
