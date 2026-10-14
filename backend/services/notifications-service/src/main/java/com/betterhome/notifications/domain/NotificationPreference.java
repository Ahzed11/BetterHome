package com.betterhome.notifications.domain;

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

/** A stored choice. No row means the default, which is enabled. */
@Entity
@Table(name = "notification_preference")
public class NotificationPreference extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "user_id", nullable = false)
    public UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public NotificationType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public Channel channel;

    @Column(nullable = false)
    public boolean enabled;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    public static Optional<NotificationPreference> findChoice(
            UUID userId, NotificationType type, Channel channel) {
        return find("userId = ?1 and type = ?2 and channel = ?3", userId, type, channel)
                .firstResultOptional();
    }

    public static List<NotificationPreference> forUser(UUID userId) {
        return list("userId", userId);
    }
}
