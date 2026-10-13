package com.betterhome.tasks.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "notification_outbox")
public class NotificationOutbox extends PanacheEntityBase {

    @Id
    public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(name = "user_id", nullable = false)
    public UUID userId;

    @Column(nullable = false)
    public String type;

    @Column(nullable = false)
    public String title;

    @Column(nullable = false)
    public String body;

    @Column(name = "payload_json", nullable = false)
    public String payloadJson;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "processed_at")
    public Instant processedAt;

    public static List<NotificationOutbox> listPending(int limit) {
        return find("processedAt is null order by createdAt").page(0, limit).list();
    }
}
