package com.betterhome.notifications.service;

import com.betterhome.common.Clock;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationException;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * The caller's own inbox. Every query is scoped to the user id, so other users' rows never match.
 */
@ApplicationScoped
public class InboxService {

    public static final int DEFAULT_LIMIT = 50;
    public static final int MAX_LIMIT = 100;

    private final Clock clock;

    @Inject
    public InboxService(Clock clock) {
        this.clock = clock;
    }

    /** Newest first; {@code before} is the id of the last notification of the previous page. */
    @Transactional
    public List<Notification> list(
            UUID userId,
            Optional<UUID> householdId,
            boolean unreadOnly,
            Optional<UUID> before,
            int limit) {
        if (limit < 1 || limit > MAX_LIMIT) {
            throw new NotificationException.BadRequest("limit must be between 1 and " + MAX_LIMIT);
        }
        Optional<Notification> cursor =
                before.map(
                        id ->
                                Notification.findOwned(id, userId)
                                        .orElseThrow(
                                                () ->
                                                        new NotificationException.BadRequest(
                                                                "Unknown cursor")));
        return Notification.inbox(userId, householdId, unreadOnly, cursor, limit);
    }

    /** Marks one notification read; the first read time is kept on repeated calls. */
    @Transactional
    public Notification markRead(UUID userId, UUID notificationId) {
        Notification notification =
                Notification.findOwned(notificationId, userId)
                        .orElseThrow(
                                () -> new NotificationException.NotFound("Notification not found"));
        if (notification.readAt == null) {
            notification.readAt = now();
        }
        return notification;
    }

    @Transactional
    public int markAllRead(UUID userId, Optional<UUID> householdId) {
        return Notification.markAllRead(userId, householdId, now());
    }

    /**
     * The database keeps microseconds; truncating here makes what we answer equal what we store.
     */
    private Instant now() {
        return clock.now().truncatedTo(ChronoUnit.MICROS);
    }
}
