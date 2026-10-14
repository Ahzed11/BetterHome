package com.betterhome.scoring.service;

import com.betterhome.common.Clock;
import com.betterhome.scoring.domain.MonthlyRecap;
import com.betterhome.scoring.domain.MonthlyRecapCelebration;
import com.betterhome.scoring.domain.PeriodWindows;
import com.betterhome.scoring.domain.PeriodWindows.Window;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ScorePeriod;
import com.betterhome.scoring.domain.ScoringException;
import com.betterhome.scoring.membership.MembershipGateway;
import com.betterhome.scoring.membership.MembershipGateway.MemberView;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@ApplicationScoped
public class ScoreboardService {

    public record Entry(UUID userId, int points, double effortShare, int rank) {}

    public record Scoreboard(
            ScorePeriod period,
            String yearMonth,
            Instant from,
            Instant to,
            int totalPoints,
            List<Entry> entries,
            List<Entry> podium) {}

    public record Winner(
            String yearMonth,
            UUID winnerUserId,
            int winnerPoints,
            int totalPoints,
            boolean celebrated) {}

    private final CallerService callerService;
    private final MembershipGateway membershipGateway;
    private final MonthlyRecapService recapService;
    private final Clock clock;

    @Inject
    public ScoreboardService(
            CallerService callerService,
            MembershipGateway membershipGateway,
            MonthlyRecapService recapService,
            Clock clock) {
        this.callerService = callerService;
        this.membershipGateway = membershipGateway;
        this.recapService = recapService;
        this.clock = clock;
    }

    public Scoreboard scoreboard(UUID householdId, ScorePeriod period, String yearMonth) {
        callerService.requireMember(householdId);
        Window range =
                PeriodWindows.of(
                        period,
                        membershipGateway.householdZone(householdId),
                        clock.now(),
                        period == ScorePeriod.month ? parseOptionalMonth(yearMonth) : null);
        List<PointTransaction> rows =
                PointTransaction.listForHouseholdInRange(householdId, range.from(), range.to());
        Map<UUID, Integer> sums = new HashMap<>();
        for (PointTransaction row : rows) {
            sums.merge(row.userId, row.points, Integer::sum);
        }
        List<MemberView> members = membershipGateway.listActiveMembers(householdId);
        List<Entry> raw = new ArrayList<>();
        int totalPositive = 0;
        for (MemberView member : members) {
            int score = Math.max(0, sums.getOrDefault(member.userId(), 0));
            raw.add(new Entry(member.userId(), score, 0, 0));
            totalPositive += score;
        }
        raw.sort(Comparator.comparingInt(Entry::points).reversed().thenComparing(Entry::userId));

        List<Entry> ranked = new ArrayList<>();
        int rank = 0;
        int lastPoints = Integer.MIN_VALUE;
        for (int i = 0; i < raw.size(); i++) {
            Entry e = raw.get(i);
            if (e.points() != lastPoints) {
                rank = i + 1;
                lastPoints = e.points();
            }
            double share = totalPositive == 0 ? 0.0 : (double) e.points() / totalPositive;
            ranked.add(new Entry(e.userId(), e.points(), share, rank));
        }
        List<Entry> podium = ranked.stream().filter(e -> e.rank() <= 3).limit(3).toList();
        return new Scoreboard(
                period, range.label(), range.from(), range.to(), totalPositive, ranked, podium);
    }

    public List<Winner> winners(UUID householdId) {
        MemberView caller = callerService.requireMember(householdId);
        Set<UUID> seen = MonthlyRecapCelebration.recapIdsSeenBy(caller.userId());
        return MonthlyRecap.listForHousehold(householdId).stream()
                .map(
                        r ->
                                new Winner(
                                        r.yearMonth,
                                        r.winnerUserId,
                                        r.winnerPoints,
                                        r.totalPoints,
                                        seen.contains(r.id)))
                .toList();
    }

    /**
     * Persists (or refreshes) the recap of a month from the ledger, cutting the month at the
     * household's local midnight. The scheduled close does the same on its own once a month ends.
     */
    @Transactional
    public MonthlyRecap closeMonth(UUID householdId, String yearMonth) {
        callerService.requireAdmin(householdId);
        YearMonth month = parseYearMonth(yearMonth);
        Window window = PeriodWindows.month(month, membershipGateway.householdZone(householdId));
        return recapService.upsert(
                householdId, month, recapService.summarize(householdId, window), clock.now());
    }

    @Transactional
    public void markCelebrated(UUID householdId, String yearMonth) {
        MemberView caller = callerService.requireMember(householdId);
        MonthlyRecap recap =
                MonthlyRecap.findByHouseholdAndMonth(householdId, yearMonth)
                        .orElseThrow(() -> new ScoringException.NotFound("Recap not found"));
        if (MonthlyRecapCelebration.hasSeen(recap.id, caller.userId())) {
            return;
        }
        MonthlyRecapCelebration seen = new MonthlyRecapCelebration();
        seen.recapId = recap.id;
        seen.userId = caller.userId();
        seen.seenAt = clock.now();
        seen.persist();
    }

    private static YearMonth parseOptionalMonth(String value) {
        return value == null || value.isBlank() ? null : parseYearMonth(value);
    }

    private static YearMonth parseYearMonth(String value) {
        try {
            return YearMonth.parse(value);
        } catch (Exception e) {
            throw new ScoringException.BadRequest("yearMonth must be YYYY-MM");
        }
    }
}
