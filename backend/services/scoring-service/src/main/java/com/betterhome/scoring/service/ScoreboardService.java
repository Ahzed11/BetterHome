package com.betterhome.scoring.service;

import com.betterhome.common.Clock;
import com.betterhome.scoring.domain.MonthlyRecap;
import com.betterhome.scoring.domain.MonthlyRecapCelebration;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ScorePeriod;
import com.betterhome.scoring.domain.ScoringException;
import com.betterhome.scoring.membership.MembershipGateway;
import com.betterhome.scoring.membership.MembershipGateway.MemberView;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
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

    public record Winner(String yearMonth, UUID winnerUserId, int winnerPoints, int totalPoints) {}

    private final CallerService callerService;
    private final MembershipGateway membershipGateway;
    private final Clock clock;

    @Inject
    public ScoreboardService(
            CallerService callerService, MembershipGateway membershipGateway, Clock clock) {
        this.callerService = callerService;
        this.membershipGateway = membershipGateway;
        this.clock = clock;
    }

    public Scoreboard scoreboard(UUID householdId, ScorePeriod period, String yearMonth) {
        callerService.requireMember(householdId);
        Range range = resolveRange(period, yearMonth);
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
                period,
                range.yearMonthLabel(),
                range.from(),
                range.to(),
                totalPositive,
                ranked,
                podium);
    }

    public List<Winner> winners(UUID householdId) {
        callerService.requireMember(householdId);
        return MonthlyRecap.listForHousehold(householdId).stream()
                .map(r -> new Winner(r.yearMonth, r.winnerUserId, r.winnerPoints, r.totalPoints))
                .toList();
    }

    /** Persist (or refresh) the monthly recap for a closed month from the ledger. */
    @Transactional
    public MonthlyRecap closeMonth(UUID householdId, String yearMonth) {
        callerService.requireAdmin(householdId);
        YearMonth ym = parseYearMonth(yearMonth);
        Instant from = ym.atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC);
        Instant to = ym.plusMonths(1).atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC);
        List<PointTransaction> rows =
                PointTransaction.listForHouseholdInRange(householdId, from, to);
        Map<UUID, Integer> sums = new HashMap<>();
        for (PointTransaction row : rows) {
            sums.merge(row.userId, row.points, Integer::sum);
        }
        UUID winner = null;
        int winnerPoints = 0;
        int total = 0;
        for (Map.Entry<UUID, Integer> e : sums.entrySet()) {
            int score = Math.max(0, e.getValue());
            total += score;
            if (score > winnerPoints) {
                winnerPoints = score;
                winner = e.getKey();
            }
        }
        Instant now = clock.now();
        MonthlyRecap recap =
                MonthlyRecap.findByHouseholdAndMonth(householdId, ym.toString())
                        .orElseGet(
                                () -> {
                                    MonthlyRecap created = new MonthlyRecap();
                                    created.id = UUID.randomUUID();
                                    created.householdId = householdId;
                                    created.yearMonth = ym.toString();
                                    created.createdAt = now;
                                    return created;
                                });
        recap.winnerUserId = winner;
        recap.winnerPoints = winnerPoints;
        recap.totalPoints = total;
        if (!MonthlyRecap.getEntityManager().contains(recap)) {
            recap.persist();
        }
        return recap;
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

    private Range resolveRange(ScorePeriod period, String yearMonth) {
        Instant now = clock.now();
        LocalDate today = LocalDate.ofInstant(now, ZoneOffset.UTC);
        return switch (period) {
            case all -> new Range(null, null, null);
            case week -> {
                LocalDate monday =
                        today.with(TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY));
                Instant from = monday.atStartOfDay().toInstant(ZoneOffset.UTC);
                yield new Range(from, null, null);
            }
            case year -> {
                Instant from =
                        LocalDate.of(today.getYear(), 1, 1)
                                .atStartOfDay()
                                .toInstant(ZoneOffset.UTC);
                yield new Range(from, null, String.valueOf(today.getYear()));
            }
            case month -> {
                YearMonth ym =
                        yearMonth == null || yearMonth.isBlank()
                                ? YearMonth.from(today)
                                : parseYearMonth(yearMonth);
                Instant from = ym.atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC);
                Instant to = ym.plusMonths(1).atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC);
                // current month is open-ended up to "now" semantics via to exclusive next month
                yield new Range(from, to, ym.toString());
            }
        };
    }

    private static YearMonth parseYearMonth(String value) {
        try {
            return YearMonth.parse(value);
        } catch (Exception e) {
            throw new ScoringException.BadRequest("yearMonth must be YYYY-MM");
        }
    }

    private record Range(Instant from, Instant to, String yearMonthLabel) {}
}
