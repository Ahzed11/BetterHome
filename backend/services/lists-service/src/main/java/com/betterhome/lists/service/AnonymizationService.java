package com.betterhome.lists.service;

import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ChecklistItem;
import com.betterhome.lists.domain.ListException;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import java.util.UUID;

/**
 * Account deletion (spec §9): replaces a deleted user's id in every column that records who did
 * something with {@link #ANONYMOUS}. The columns are NOT NULL or tied to a timestamp by a CHECK, so
 * a fixed id stands in for the person and the history (who-did-what-when, minus the who) stays
 * intact.
 */
@ApplicationScoped
public class AnonymizationService {

    /** The id that replaces every deleted user; it never belongs to a real user. */
    public static final UUID ANONYMOUS = new UUID(0L, 0L);

    /** Rows changed per column. All zero when the user has no history here, or already left. */
    public record Result(
            int listsCreated, int itemsCreated, int itemsCompleted, int itemsDeleted) {}

    /** Idempotent: a second call for the same user finds nothing left to change. */
    @Transactional
    public Result anonymize(UUID userId) {
        if (ANONYMOUS.equals(userId)) {
            throw new ListException.BadRequest("Not a user id");
        }
        return new Result(
                Checklist.replaceCreator(userId, ANONYMOUS),
                ChecklistItem.replaceCreator(userId, ANONYMOUS),
                ChecklistItem.replaceCompleter(userId, ANONYMOUS),
                ChecklistItem.replaceDeletedBy(userId, ANONYMOUS));
    }
}
