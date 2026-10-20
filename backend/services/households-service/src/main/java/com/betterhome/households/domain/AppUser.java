package com.betterhome.households.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

@Entity
@Table(name = "app_user")
public class AppUser extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "auth_subject", nullable = false, unique = true)
    public UUID authSubject;

    @Column(nullable = false)
    public String email;

    @Column(name = "given_name", nullable = false)
    public String givenName;

    @Column(name = "family_name", nullable = false)
    public String familyName;

    @Column(nullable = false)
    public String language;

    @Column(nullable = false)
    public String timezone;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    @Column(name = "deleted_at")
    public Instant deletedAt;

    public static Optional<AppUser> findByAuthSubject(UUID authSubject) {
        return find("authSubject = ?1 and deletedAt is null", authSubject).firstResultOptional();
    }

    public static Optional<AppUser> findActiveByEmail(String email) {
        return find("lower(email) = ?1 and deletedAt is null", email.toLowerCase(Locale.ROOT))
                .firstResultOptional();
    }

    public static Optional<AppUser> findActiveById(UUID id) {
        return find("id = ?1 and deletedAt is null", id).firstResultOptional();
    }

    /** The profile of a subject whose account was deleted, if there is one. */
    public static Optional<AppUser> findDeletedByAuthSubject(UUID authSubject) {
        return find("authSubject = ?1 and deletedAt is not null", authSubject)
                .firstResultOptional();
    }

    /**
     * Strips everything personal from the profile and marks it deleted. The row stays because
     * memberships, households and invitations point at it; the subject stays so a token that
     * outlives the deletion cannot register the same subject again.
     */
    public void anonymize(Instant now) {
        email = "deleted-" + id + "@deleted.invalid";
        givenName = "";
        familyName = "";
        language = "en";
        timezone = "UTC";
        updatedAt = now;
        deletedAt = now;
    }
}
