package com.betterhome.scoring.service;

import com.betterhome.scoring.domain.MonthlyRecap;
import com.betterhome.scoring.domain.PeriodWindows.Window;
import com.betterhome.scoring.domain.PointTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.time.YearMonth;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Turns the ledger of one month into its recap. The admin close and the scheduled close both use
 * it, so they agree on who won.
 */
@ApplicationScoped
public class MonthlyRecapService {

    /** The winner is null when nobody scored. */
    public record Summary(UUID winnerUserId, int winnerPoints, int totalPoints) {}

    /**
     * Sums each member's points in the window, as the scoreboard does (a member never counts below
     * zero). The winner has the most points; a tie goes to the lowest user id, which is also the
     * rank order of the scoreboard.
     */
    public Summary summarize(UUID householdId, Window window) {
        Map<UUID, Integer> sums = new HashMap<>();
        for (PointTransaction row :
                PointTransaction.listForHouseholdInRange(householdId, window.from(), window.to())) {
            sums.merge(row.userId, row.points, Integer::sum);
        }
        UUID winner = null;
        int winnerPoints = 0;
        int total = 0;
        for (Map.Entry<UUID, Integer> entry : sums.entrySet()) {
            int score = Math.max(0, entry.getValue());
            total += score;
            boolean better =
                    score > winnerPoints
                            || (score == winnerPoints
                                    && score > 0
                                    && winner != null
                                    && entry.getKey().compareTo(winner) < 0);
            if (better) {
                winnerPoints = score;
                winner = entry.getKey();
            }
        }
        return new Summary(winner, winnerPoints, total);
    }

    /** Creates the recap of a month, or refreshes it when it exists (the admin close). */
    public MonthlyRecap upsert(UUID householdId, YearMonth month, Summary summary, Instant now) {
        Optional<MonthlyRecap> existing =
                MonthlyRecap.findByHouseholdAndMonth(householdId, month.toString());
        MonthlyRecap recap = existing.orElseGet(MonthlyRecap::new);
        if (existing.isEmpty()) {
            recap.id = UUID.randomUUID();
            recap.householdId = householdId;
            recap.yearMonth = month.toString();
            recap.createdAt = now;
        }
        recap.winnerUserId = summary.winnerUserId();
        recap.winnerPoints = summary.winnerPoints();
        recap.totalPoints = summary.totalPoints();
        if (existing.isEmpty()) {
            recap.persist();
        }
        return recap;
    }

    /**
     * Records the recap of a month nobody has closed yet and leaves an existing one alone (an admin
     * may have closed it by hand). Months without any points get no recap.
     */
    public void recordIfAbsent(UUID householdId, YearMonth month, Window window, Instant now) {
        if (MonthlyRecap.findByHouseholdAndMonth(householdId, month.toString()).isPresent()) {
            return;
        }
        Summary summary = summarize(householdId, window);
        if (summary.totalPoints() > 0) {
            upsert(householdId, month, summary, now);
        }
    }
}
