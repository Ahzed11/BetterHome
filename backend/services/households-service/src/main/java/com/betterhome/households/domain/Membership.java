package com.betterhome.households.domain;

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
@Table(name = "membership")
public class Membership extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "user_id", nullable = false)
    public UUID userId;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public MembershipRole role;

    @Column(name = "joined_at", nullable = false)
    public Instant joinedAt;

    @Column(name = "left_at")
    public Instant leftAt;

    @Column(name = "away_from")
    public Instant awayFrom;

    @Column(name = "away_until")
    public Instant awayUntil;

    @Column(name = "away_set_by")
    public UUID awaySetBy;

    public boolean isActive() {
        return leftAt == null;
    }

    public boolean isAway(Instant now) {
        if (awayFrom == null) {
            return false;
        }
        if (now.isBefore(awayFrom)) {
            return false;
        }
        return awayUntil == null || !now.isAfter(awayUntil);
    }

    public static Optional<Membership> findActive(UUID householdId, UUID userId) {
        return find("householdId = ?1 and userId = ?2 and leftAt is null", householdId, userId)
                .firstResultOptional();
    }

    public static List<Membership> listActiveForHousehold(UUID householdId) {
        return list("householdId = ?1 and leftAt is null order by joinedAt", householdId);
    }

    public static List<Membership> listActiveForUser(UUID userId) {
        return list("userId = ?1 and leftAt is null order by joinedAt", userId);
    }

    public static long countActiveAdmins(UUID householdId) {
        return count(
                "householdId = ?1 and leftAt is null and role = ?2",
                householdId,
                MembershipRole.admin);
    }
}
