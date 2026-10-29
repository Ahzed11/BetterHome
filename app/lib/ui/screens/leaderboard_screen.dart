import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
import 'package:betterhome/state/reads.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/member_labels.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/member_avatar.dart';
import 'package:betterhome/ui/widgets/podium.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:betterhome/ui/widgets/segmented_tabs.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/month_recap_dialog.dart';
import 'package:betterhome/ui/widgets/screen_skeletons.dart';
import 'package:betterhome/ui/widgets/pull_to_refresh.dart';
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
  ScorePeriod _period = defaultScorePeriod;
  late final CachedRead<List<Membership>> _members;
  late final CachedRead<Household> _household;
  late CachedRead<Scores> _board;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    final householdId = widget.householdId;
    // The members and the household are shared with the other screens: one request each,
    // whoever asks first, started together with the board.
    _members = CachedRead.of(
      session.readCache,
      session.membersRead(householdId),
      onChange: _changed,
    );
    _household = CachedRead.of(
      session.readCache,
      session.householdRead(householdId),
      onChange: _changed,
    );
    _board = _open();
    _showUnseenRecap();
  }

  @override
  void dispose() {
    _board.dispose();
    _members.dispose();
    _household.dispose();
    super.dispose();
  }

  /// What the screen draws, once the board, the winners and the members are all known.
  _BoardData? get _data => switch ((_board.state, _members.state)) {
    (
      ReadLoaded<Scores>(data: final scores),
      ReadLoaded<List<Membership>>(data: final members),
    ) =>
      _BoardData(
        board: scores.board,
        winners: scores.winners,
        members: members,
      ),
    _ => null,
  };

  /// Pull to refresh: every read this screen shows. A request already running is joined.
  Future<bool> _pull() async {
    final answers = await Future.wait([
      _board.refresh(),
      _members.refresh(),
      _household.refresh(),
    ]);
    return answers.every((arrived) => arrived);
  }

  bool get _failed =>
      _board.state is ReadFailed<Scores> ||
      _members.state is ReadFailed<List<Membership>>;

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  /// The read of the board of the current period, which has an entry of its own in the cache.
  CachedRead<Scores> _open() => CachedRead.of(
    widget.session.readCache,
    widget.session.leaderboardRead(widget.householdId, _period),
    onChange: _changed,
  );

  /// Shows the recap of the newest month the user has not seen yet, once: it is recorded as seen
  /// before it is shown, so it never comes back. It is decided on a fresh answer only: an old
  /// one may still list as unseen a month whose recap was shown since.
  Future<void> _showUnseenRecap() async {
    final board = _board;
    final answers = await Future.wait([board.refresh(), _members.refresh()]);
    if (!answers.first) {
      return; // The screen already shows the error, or the old answer.
    }
    final data = _data;
    if (data == null) {
      return;
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
      body: PullToRefresh(
        onRefresh: _pull,
        child: ListView(
          physics: pullablePhysics,
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          children: [
            ScreenHeader(
              eyebrow: switch (_household.state) {
                ReadLoaded<Household>(:final data) => data.name,
                _ => null,
              },
              title: l10n.leaderboardTitle,
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
                  _board.dispose();
                  _board = _open();
                });
              },
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Builder(
              builder: (context) {
                final data = _data;
                if (data == null) {
                  return _failed
                      ? Center(child: Text(l10n.errorGeneric))
                      : const LeaderboardSkeleton();
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
                              label: _labelFor(
                                l10n,
                                entry.userId,
                                data.members,
                              ),
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
      ),
    );
  }
}

/// What the screen draws: the scores of a period with the members they are about.
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
