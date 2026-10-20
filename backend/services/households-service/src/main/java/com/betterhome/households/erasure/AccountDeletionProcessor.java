package com.betterhome.households.erasure;

import com.betterhome.common.Clock;
import com.betterhome.common.RelayBackoff;
import com.betterhome.households.domain.AccountDeletion;
import com.betterhome.households.domain.AccountDeletionStep;
import com.betterhome.households.domain.AppUser;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Instance;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.jboss.logging.Logger;

/**
 * Tells every {@link DeletionTarget} about deleted accounts until each has confirmed. A deletion is
 * claimed with {@code FOR UPDATE SKIP LOCKED} in its own transaction, so replicas never work on the
 * same one. Targets are independent: one being down does not hold back the others, and what already
 * confirmed is not called again. A failed run is retried with the outbox backoff, without limit,
 * because a deletion that never finishes leaves personal data behind.
 */
@ApplicationScoped
public class AccountDeletionProcessor {

    private static final Logger LOG = Logger.getLogger(AccountDeletionProcessor.class);

    /** After this many failed runs the log line is an error, so someone looks at it. */
    private static final int ALERT_AFTER_ATTEMPTS = 10;

    private final Clock clock;
    private final EntityManager entityManager;
    private final Instance<DeletionTarget> targets;

    @Inject
    public AccountDeletionProcessor(
            Clock clock, EntityManager entityManager, Instance<DeletionTarget> targets) {
        this.clock = clock;
        this.entityManager = entityManager;
        this.targets = targets;
    }

    /** Works on up to {@code limit} due deletions and returns how many it ran. */
    public int processDue(int limit) {
        int ran = 0;
        while (ran < limit
                && Boolean.TRUE.equals(
                        QuarkusTransaction.requiringNew().call(() -> runOne(Claim.anyDue())))) {
            ran++;
        }
        return ran;
    }

    /**
     * Works on this user's deletion now if it is due and no other replica holds it.
     *
     * @return true when the deletion is complete afterwards
     */
    public boolean process(UUID userId) {
        QuarkusTransaction.requiringNew().call(() -> runOne(Claim.of(userId)));
        return QuarkusTransaction.requiringNew()
                .call(() -> AccountDeletion.<AccountDeletion>findById(userId).completedAt != null);
    }

    private record Claim(String sql, UUID userId) {

        static Claim anyDue() {
            return new Claim(
                    """
                    SELECT user_id FROM account_deletion
                    WHERE completed_at IS NULL AND available_at <= :now
                    ORDER BY requested_at
                    LIMIT 1
                    FOR UPDATE SKIP LOCKED
                    """,
                    null);
        }

        static Claim of(UUID userId) {
            return new Claim(
                    """
                    SELECT user_id FROM account_deletion
                    WHERE completed_at IS NULL AND available_at <= :now AND user_id = :user
                    FOR UPDATE SKIP LOCKED
                    """,
                    userId);
        }
    }

    private boolean runOne(Claim claim) {
        Instant now = clock.now();
        var query =
                entityManager
                        .createNativeQuery(claim.sql())
                        .setParameter("now", Timestamp.from(now));
        if (claim.userId() != null) {
            query.setParameter("user", claim.userId());
        }
        List<?> claimed = query.getResultList();
        if (claimed.isEmpty()) {
            return false;
        }
        Object raw = claimed.getFirst();
        UUID userId = raw instanceof UUID uuid ? uuid : UUID.fromString(raw.toString());
        run(AccountDeletion.findById(userId), now);
        return true;
    }

    private void run(AccountDeletion deletion, Instant now) {
        AppUser user = AppUser.findById(deletion.userId);
        Set<String> done = AccountDeletionStep.doneTargets(deletion.userId);
        boolean allDone = true;
        for (DeletionTarget target : targets) {
            if (done.contains(target.name())) {
                continue;
            }
            try {
                target.erase(user.id, user.authSubject);
                AccountDeletionStep.done(user.id, target.name(), now).persist();
            } catch (DeletionTargetException e) {
                allDone = false;
                LOG.warnf(
                        "Account deletion of user %s: %s, will retry (attempt %d)",
                        user.id, e.getMessage(), deletion.attempts + 1);
            }
        }
        if (allDone) {
            deletion.completedAt = now;
            return;
        }
        deletion.attempts++;
        deletion.availableAt = now.plus(RelayBackoff.delay(deletion.attempts));
        if (deletion.attempts >= ALERT_AFTER_ATTEMPTS) {
            LOG.errorf(
                    "Account deletion of user %s still incomplete after %d attempts",
                    user.id, deletion.attempts);
        }
    }
}
