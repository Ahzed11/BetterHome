package com.betterhome.scoring.service;

import com.betterhome.scoring.domain.MonthlyRecap;
import com.betterhome.scoring.domain.MonthlyRecapCelebration;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ScoringException;
import com.betterhome.scoring.domain.TaskReversion;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import java.util.UUID;

/**
 * Account deletion (spec §9): replaces a deleted user's id with {@link #ANONYMOUS} on the ledger,
 * the reversions and the monthly recaps. The ledger stays append-only: no row is added, removed or
 * given other points, so every household total is unchanged; only the person behind a row goes.
 * Which recaps the user had seen is not history and is deleted.
 */
@ApplicationScoped
public class AnonymizationService {

    /** The id that replaces every deleted user; it never belongs to a real user. */
    public static final UUID ANONYMOUS = new UUID(0L, 0L);

    /** Rows changed per kind. All zero when the user has no history here, or already left. */
    public record Result(
            int ledgerRows, int reversions, int recapsWon, long celebrationsForgotten) {}

    /** Idempotent: a second call for the same user finds nothing left to change. */
    @Transactional
    public Result anonymize(UUID userId) {
        if (ANONYMOUS.equals(userId)) {
            throw new ScoringException.BadRequest("Not a user id");
        }
        return new Result(
                PointTransaction.replaceUser(userId, ANONYMOUS),
                TaskReversion.replaceAdmin(userId, ANONYMOUS),
                MonthlyRecap.replaceWinner(userId, ANONYMOUS),
                MonthlyRecapCelebration.deleteForUser(userId));
    }
}
