import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';

/// The period the leaderboard opens on.
const defaultScorePeriod = ScorePeriod.month;

/// Where the signed-in user stands this week.
class WeekStanding {
  const WeekStanding({
    required this.points,
    required this.rank,
    required this.behind,
  });

  final int points;
  final int rank;
  final int behind;
}

/// The board and the winners of a period.
class Scores {
  const Scores({required this.board, required this.winners});

  final Scoreboard board;
  final List<MonthlyWinner> winners;
}

/// The reads the screens make, each described once: the screens open them, and the prefetch of
/// the other tabs fills them (`prefetch.dart`). The members and the household are shared by
/// every screen that shows them.
extension ScreenReads on AppSession {
  ReadSpec<List<Membership>> membersRead(String householdId) => ReadSpec(
    key: readKey('members', householdId: householdId),
    fetch: () => repository.listMembers(householdId),
  );

  ReadSpec<Household> householdRead(String householdId) => ReadSpec(
    key: readKey('household', householdId: householdId),
    fetch: () => repository.getHousehold(householdId),
  );

  ReadSpec<List<ChoreTask>> tasksRead(
    String householdId, {
    required bool mine,
  }) => ReadSpec(
    key: readKey('tasks', householdId: householdId, params: mine),
    fetch: () => tasksRepository.listTasks(householdId, mine: mine),
  );

  ReadSpec<WeekStanding> weekRead(String householdId) => ReadSpec(
    key: readKey('week', householdId: householdId),
    fetch: () async {
      final board = await scoringRepository.getScoreboard(
        householdId,
        period: ScorePeriod.week,
      );
      final me = profile?.id;
      final mine = board.entries.where((e) => e.userId == me).firstOrNull;
      final leader = board.entries.firstOrNull;
      return WeekStanding(
        points: mine?.points ?? 0,
        rank: mine?.rank ?? board.entries.length + 1,
        behind: leader == null ? 0 : leader.points - (mine?.points ?? 0),
      );
    },
  );

  ReadSpec<Scores> leaderboardRead(
    String householdId,
    ScorePeriod period,
  ) => ReadSpec(
    key: readKey('leaderboard', householdId: householdId, params: period),
    fetch: () async {
      final scoring = scoringRepository;
      if (scoring is FakeScoringRepository) {
        // The demo ledger needs the members first; a read already running is joined.
        final members = membersRead(householdId);
        await readCache.fill(members);
        if (readCache.entry<List<Membership>>(members.key).value
            case ReadLoaded<List<Membership>>(:final data)) {
          scoring.setMembers(data.map((m) => m.userId).toList());
        }
        scoring.seedDemoIfEmpty(householdId);
      }
      // The board and the winners do not depend on each other: asked together.
      // Future.wait rethrows the failed request itself (a record's `.wait` wraps it), which
      // is what the cache recognises as a failed read.
      final board = scoring.getScoreboard(householdId, period: period);
      final winners = scoring.listWinners(householdId);
      await Future.wait<Object>([board, winners]);
      return Scores(board: await board, winners: await winners);
    },
  );

  ReadSpec<List<Checklist>> listsRead(String householdId) => ReadSpec(
    key: readKey('lists', householdId: householdId),
    fetch: () => listsRepository.listLists(householdId),
  );

  ReadSpec<List<ChecklistItem>> itemsRead(String householdId, String listId) =>
      ReadSpec(
        key: readKey('items', householdId: householdId, params: listId),
        fetch: () => listsRepository.listItems(householdId, listId),
      );

  /// Whether anything in the inbox is unread: the dot of the bell.
  ReadSpec<bool> unreadRead() => ReadSpec(
    key: readKey('unread'),
    fetch: () async => (await notificationsRepository.list(
      limit: 1,
      unreadOnly: true,
    )).isNotEmpty,
  );
}
