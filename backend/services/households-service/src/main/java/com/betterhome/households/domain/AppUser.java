package com.betterhome.households.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
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

    public static Optional<AppUser> findActiveById(UUID id) {
        return find("id = ?1 and deletedAt is null", id).firstResultOptional();
    }
}
