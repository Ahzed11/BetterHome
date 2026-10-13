package com.betterhome.tasks.service;

import com.betterhome.common.Clock;
import com.betterhome.common.PushSender;
import com.betterhome.tasks.domain.NotificationOutbox;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class OutboxService {

    private final Clock clock;
    private final PushSender pushSender;

    @Inject
    public OutboxService(Clock clock, PushSender pushSender) {
        this.clock = clock;
        this.pushSender = pushSender;
    }

    @Transactional
    public void enqueue(
            UUID householdId, UUID userId, String type, String title, String body, String payloadJson) {
        NotificationOutbox row = new NotificationOutbox();
        row.id = UUID.randomUUID();
        row.householdId = householdId;
        row.userId = userId;
        row.type = type;
        row.title = title;
        row.body = body;
        row.payloadJson = payloadJson == null ? "{}" : payloadJson;
        row.createdAt = clock.now();
        row.persist();
    }

    @Transactional
    public int drain(int limit) {
        List<NotificationOutbox> pending = NotificationOutbox.listPending(limit);
        int count = 0;
        for (NotificationOutbox row : pending) {
            pushSender.send(
                    new PushSender.PushMessage(
                            row.userId.toString(),
                            row.type,
                            row.title,
                            row.body,
                            row.payloadJson));
            row.processedAt = clock.now();
            count++;
        }
        return count;
    }
}
