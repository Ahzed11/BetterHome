package com.betterhome.scoring.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Entity
@Table(name = "point_transaction")
public class PointTransaction extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(name = "user_id", nullable = false)
    public UUID userId;

    @Column(name = "task_id")
    public UUID taskId;

    @Column(name = "completion_no")
    public Integer completionNo;

    @Column(name = "reversion_id")
    public UUID reversionId;

    @Column(nullable = false)
    public int points;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public PointReason reason;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    public static List<PointTransaction> listForHouseholdInRange(
            UUID householdId, Instant fromInclusive, Instant toExclusive) {
        if (fromInclusive == null && toExclusive == null) {
            return list("householdId = ?1 order by createdAt asc", householdId);
        }
        if (fromInclusive == null) {
            return list(
                    "householdId = ?1 and createdAt < ?2 order by createdAt asc",
                    householdId,
                    toExclusive);
        }
        if (toExclusive == null) {
            return list(
                    "householdId = ?1 and createdAt >= ?2 order by createdAt asc",
                    householdId,
                    fromInclusive);
        }
        return list(
                "householdId = ?1 and createdAt >= ?2 and createdAt < ?3 order by createdAt asc",
                householdId,
                fromInclusive,
                toExclusive);
    }

    public static Optional<PointTransaction> findAward(UUID taskId, int completionNo) {
        return find("taskId = ?1 and completionNo = ?2", taskId, completionNo)
                .firstResultOptional();
    }

    /**
     * Inserts an award unless one already exists for the same task completion. Atomic in the
     * database, so concurrent retries cannot both insert.
     */
    public static boolean insertAwardIfAbsent(PointTransaction row) {
        int inserted =
                getEntityManager()
                        .createNativeQuery(
                                "insert into point_transaction (id, household_id, user_id,"
                                        + " task_id, completion_no, points, reason, created_at)"
                                        + " values (:id, :h, :u, :t, :c, :p, :r, :at)"
                                        + " on conflict (task_id, completion_no)"
                                        + " where completion_no is not null do nothing")
                        .setParameter("id", row.id)
                        .setParameter("h", row.householdId)
                        .setParameter("u", row.userId)
                        .setParameter("t", row.taskId)
                        .setParameter("c", row.completionNo)
                        .setParameter("p", row.points)
                        .setParameter("r", row.reason.name())
                        .setParameter("at", row.createdAt)
                        .executeUpdate();
        return inserted == 1;
    }

    public static int sumForUser(UUID householdId, UUID userId) {
        Long sum =
                getEntityManager()
                        .createQuery(
                                "select coalesce(sum(p.points), 0) from PointTransaction p"
                                        + " where p.householdId = :h and p.userId = :u",
                                Long.class)
                        .setParameter("h", householdId)
                        .setParameter("u", userId)
                        .getSingleResult();
        return sum.intValue();
    }

    public static int sumAwardedForTask(UUID householdId, UUID taskId) {
        Long sum =
                getEntityManager()
                        .createQuery(
                                "select coalesce(sum(p.points), 0) from PointTransaction p"
                                        + " where p.householdId = :h and p.taskId = :t",
                                Long.class)
                        .setParameter("h", householdId)
                        .setParameter("t", taskId)
                        .getSingleResult();
        return sum.intValue();
    }

    /** Hands every ledger row of {@code user} to {@code replacement}; returns how many. */
    public static int replaceUser(UUID user, UUID replacement) {
        return update("userId = ?1 where userId = ?2", replacement, user);
    }
}
