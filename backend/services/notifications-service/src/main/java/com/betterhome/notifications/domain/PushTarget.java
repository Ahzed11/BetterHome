package com.betterhome.notifications.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * Where a user's pushes go: the user's own Gotify application token (ADR 0027). The token is a
 * secret; it is never returned by the API and never logged.
 */
@Entity
@Table(name = "push_target")
public class PushTarget extends PanacheEntityBase {

    @Id
    @Column(name = "user_id")
    public UUID userId;

    @Column(nullable = false)
    public String token;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    public static Optional<PushTarget> forUser(UUID userId) {
        return findByIdOptional(userId);
    }
}
