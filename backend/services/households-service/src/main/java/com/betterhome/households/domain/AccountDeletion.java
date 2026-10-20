package com.betterhome.households.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * What is left to do after a user deleted their account: tell every other system. It is written in
 * the transaction that anonymizes the profile and retried until each target has confirmed (see
 * {@code AccountDeletionProcessor}). It holds no personal data.
 */
@Entity
@Table(name = "account_deletion")
public class AccountDeletion extends PanacheEntityBase {

    @Id
    @Column(name = "user_id")
    public UUID userId;

    @Column(name = "requested_at", nullable = false)
    public Instant requestedAt;

    @Column(nullable = false)
    public int attempts;

    /** Not tried before this instant (backoff after a failure). */
    @Column(name = "available_at", nullable = false)
    public Instant availableAt;

    /** Set once every target confirmed. */
    @Column(name = "completed_at")
    public Instant completedAt;

    public static AccountDeletion request(UUID userId, Instant now) {
        AccountDeletion deletion = new AccountDeletion();
        deletion.userId = userId;
        deletion.requestedAt = now;
        deletion.availableAt = now;
        return deletion;
    }
}
