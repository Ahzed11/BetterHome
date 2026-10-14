package com.betterhome.tasks.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * An event to tell notifications-service about, written in the transaction of the change that
 * caused it. The relay ({@code OutboxRelay}) delivers it at least once.
 */
@Entity
@Table(name = "notification_outbox")
public class NotificationOutbox extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(name = "user_id", nullable = false)
    public UUID userId;

    @Column(nullable = false)
    public String type;

    /** JSON object of short strings, the payload of the event. */
    @Column(name = "payload_json", nullable = false)
    public String payloadJson;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    /** Set once notifications-service accepted the event. */
    @Column(name = "processed_at")
    public Instant processedAt;

    @Column(nullable = false)
    public int attempts;

    /** The row is not tried before this instant (backoff after a failure). */
    @Column(name = "available_at", nullable = false)
    public Instant availableAt;

    /** Set when the event is refused for good; the row is never tried again. */
    @Column(name = "failed_at")
    public Instant failedAt;
}
