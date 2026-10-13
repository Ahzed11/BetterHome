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
@Table(name = "invitation")
public class Invitation extends PanacheEntityBase {

    @Id
    public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(nullable = false)
    public String email;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public MembershipRole role;

    @Column(nullable = false, unique = true)
    public String token;

    @Column(name = "expires_at", nullable = false)
    public Instant expiresAt;

    @Column(name = "accepted_at")
    public Instant acceptedAt;

    @Column(name = "created_by", nullable = false)
    public UUID createdBy;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    public boolean isPending(Instant now) {
        return acceptedAt == null && expiresAt.isAfter(now);
    }

    public static Optional<Invitation> findByToken(String token) {
        return find("token", token).firstResultOptional();
    }

    public static List<Invitation> listPendingForHousehold(UUID householdId, Instant now) {
        return list(
                "householdId = ?1 and acceptedAt is null and expiresAt > ?2 order by createdAt",
                householdId,
                now);
    }
}
