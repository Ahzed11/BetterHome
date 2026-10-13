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
}
