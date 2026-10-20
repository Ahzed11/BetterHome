package com.betterhome.notifications.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import io.quarkus.panache.common.Page;
import io.quarkus.panache.common.Sort;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "notification")
public class Notification extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(name = "user_id", nullable = false)
    public UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public NotificationType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public Channel channel;

    @Column(nullable = false)
    public String title;

    @Column(nullable = false)
    public String body;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(nullable = false)
    public Map<String, String> payload;

    @Column(name = "idempotency_key", nullable = false)
    public String idempotencyKey;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "read_at")
    public Instant readAt;

    /** A notification only if it belongs to this user; other users' rows look absent. */
    public static Optional<Notification> findOwned(UUID id, UUID userId) {
        return find("id = ?1 and userId = ?2", id, userId).firstResultOptional();
    }

    public static List<Notification> findByKey(String idempotencyKey) {
        return list("idempotencyKey = ?1 order by channel", idempotencyKey);
    }

    /** Newest first. {@code before} is the last item of the previous page, if any. */
    public static List<Notification> inbox(
            UUID userId,
            Optional<UUID> householdId,
            boolean unreadOnly,
            Optional<Notification> before,
            int limit) {
        StringBuilder query = new StringBuilder("userId = ?1 and channel = ?2");
        List<Object> params = new ArrayList<>(List.of(userId, Channel.in_app));
        householdId.ifPresent(
                id -> {
                    params.add(id);
                    query.append(" and householdId = ?").append(params.size());
                });
        if (unreadOnly) {
            query.append(" and readAt is null");
        }
        before.ifPresent(
                cursor -> {
                    params.add(cursor.createdAt);
                    int at = params.size();
                    params.add(cursor.id);
                    query.append(" and (createdAt < ?")
                            .append(at)
                            .append(" or (createdAt = ?")
                            .append(at)
                            .append(" and id < ?")
                            .append(at + 1)
                            .append("))");
                });
        Sort newestFirst = Sort.by("createdAt").descending().and("id").descending();
        return find(query.toString(), newestFirst, params.toArray())
                .page(Page.ofSize(limit))
                .list();
    }

    public static int markAllRead(UUID userId, Optional<UUID> householdId, Instant now) {
        if (householdId.isPresent()) {
            return update(
                    "readAt = ?1 where userId = ?2 and channel = ?3 and readAt is null"
                            + " and householdId = ?4",
                    now,
                    userId,
                    Channel.in_app,
                    householdId.get());
        }
        return update(
                "readAt = ?1 where userId = ?2 and channel = ?3 and readAt is null",
                now,
                userId,
                Channel.in_app);
    }

    /** Deletes everything addressed to {@code userId}, read or not; returns how many. */
    public static long deleteForUser(UUID userId) {
        return delete("userId", userId);
    }
}
