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
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

@Entity
@Table(name = "invitation")
public class Invitation extends PanacheEntityBase {

    @Id public UUID id;

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

    /** Drops the invitations to {@code email} that were never accepted; returns how many. */
    public static long deletePendingFor(String email) {
        return delete("lower(email) = ?1 and acceptedAt is null", email.toLowerCase(Locale.ROOT));
    }

    /** Blanks the address of the invitations to {@code email} that were accepted. */
    public static int forgetAcceptedFor(String email) {
        return update(
                "email = ?1 where lower(email) = ?2 and acceptedAt is not null",
                "deleted@deleted.invalid",
                email.toLowerCase(Locale.ROOT));
    }
}
