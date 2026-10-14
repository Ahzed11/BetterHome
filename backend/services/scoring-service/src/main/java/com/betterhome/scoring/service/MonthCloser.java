package com.betterhome.scoring.service;

import com.betterhome.common.Clock;
import com.betterhome.scoring.domain.MonthCloseCursor;
import com.betterhome.scoring.domain.PeriodWindows;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ScoringException;
import com.betterhome.scoring.membership.MembershipGateway;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import org.jboss.logging.Logger;

/**
 * Closes each household's months by itself (spec §3.4: at the household's local month boundary). A
 * {@link MonthCloseCursor} per household says which month is next and when it ends. Households are
 * claimed with {@code FOR UPDATE SKIP LOCKED}, one per transaction, so replicas never close the
 * same household together and a failure leaves that household exactly as it was.
 */
@ApplicationScoped
public class MonthCloser {

    private static final Logger LOG = Logger.getLogger(MonthCloser.class);

    /** After a failed timezone lookup the household is tried again after this long. */
    static final Duration RETRY_AFTER = Duration.ofMinutes(1);

    private final Clock clock;
    private final MembershipGateway membershipGateway;
    private final MonthlyRecapService recapService;
    private final EntityManager entityManager;

    @Inject
    public MonthCloser(
            Clock clock,
            MembershipGateway membershipGateway,
            MonthlyRecapService recapService,
            EntityManager entityManager) {
        this.clock = clock;
        this.membershipGateway = membershipGateway;
        this.recapService = recapService;
        this.entityManager = entityManager;
    }

    /** Closes the months that ended in up to {@code limit} households; returns how many it took. */
    public int closeDue(int limit) {
        registerNewHouseholds(limit);
        int claimed = 0;
        while (claimed < limit
                && Boolean.TRUE.equals(QuarkusTransaction.requiringNew().call(this::closeOne))) {
            claimed++;
        }
        return claimed;
    }

    /** Gives every household that has ledger rows but no cursor yet one, at its first month. */
    private void registerNewHouseholds(int limit) {
        List<?> ids =
                QuarkusTransaction.requiringNew()
                        .call(
                                () ->
                                        entityManager
                                                .createNativeQuery(
                                                        """
                                                        SELECT DISTINCT pt.household_id
                                                        FROM point_transaction pt
                                                        WHERE NOT EXISTS (
                                                            SELECT 1 FROM month_close_cursor c
                                                            WHERE c.household_id = pt.household_id)
                                                        LIMIT :lim
                                                        """)
                                                .setParameter("lim", Math.max(limit, 1))
                                                .getResultList());
        for (Object rawId : ids) {
            UUID householdId =
                    rawId instanceof UUID uuid ? uuid : UUID.fromString(rawId.toString());
            QuarkusTransaction.requiringNew().run(() -> register(householdId));
        }
    }

    private void register(UUID householdId) {
        ZoneId zone;
        try {
            zone = membershipGateway.householdZone(householdId);
        } catch (ScoringException.ServiceUnavailable e) {
            LOG.warnf(
                    "Household %s not registered for month close yet: %s",
                    householdId, e.getMessage());
            return;
        }
        PointTransaction first =
                PointTransaction.find("householdId = ?1 order by createdAt asc", householdId)
                        .firstResult();
        if (first == null) {
            return;
        }
        YearMonth month = PeriodWindows.monthOf(first.createdAt, zone);
        Instant now = clock.now();
        entityManager
                .createNativeQuery(
                        """
                        INSERT INTO month_close_cursor
                            (household_id, next_month, next_close_at, updated_at)
                        VALUES (:id, :month, :closeAt, :now)
                        ON CONFLICT (household_id) DO NOTHING
                        """)
                .setParameter("id", householdId)
                .setParameter("month", month.toString())
                .setParameter("closeAt", Timestamp.from(PeriodWindows.endOfMonth(month, zone)))
                .setParameter("now", Timestamp.from(now))
                .executeUpdate();
    }

    /** Claims the oldest due household and closes its ended months; false when none is due. */
    private boolean closeOne() {
        Instant now = clock.now();
        List<?> ids =
                entityManager
                        .createNativeQuery(
                                """
                                SELECT household_id FROM month_close_cursor
                                WHERE next_close_at <= :now
                                ORDER BY next_close_at
                                FOR UPDATE SKIP LOCKED
                                LIMIT 1
                                """)
                        .setParameter("now", Timestamp.from(now))
                        .getResultList();
        if (ids.isEmpty()) {
            return false;
        }
        Object rawId = ids.getFirst();
        UUID householdId = rawId instanceof UUID uuid ? uuid : UUID.fromString(rawId.toString());
        MonthCloseCursor cursor = MonthCloseCursor.findById(householdId);
        ZoneId zone;
        try {
            zone = membershipGateway.householdZone(householdId);
        } catch (ScoringException.ServiceUnavailable e) {
            LOG.warnf("Month close of household %s postponed: %s", householdId, e.getMessage());
            cursor.nextCloseAt = now.plus(RETRY_AFTER);
            cursor.updatedAt = now;
            return true;
        }
        YearMonth month = YearMonth.parse(cursor.nextMonth);
        // The timezone may have changed since the cursor was set: close only months that have
        // really ended in the zone the household has now.
        while (!PeriodWindows.endOfMonth(month, zone).isAfter(now)) {
            recapService.recordIfAbsent(householdId, month, PeriodWindows.month(month, zone), now);
            month = month.plusMonths(1);
        }
        cursor.nextMonth = month.toString();
        cursor.nextCloseAt = PeriodWindows.endOfMonth(month, zone);
        cursor.updatedAt = now;
        return true;
    }
}
