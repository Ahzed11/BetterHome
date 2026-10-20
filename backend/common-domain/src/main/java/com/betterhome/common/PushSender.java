package com.betterhome.common;

/**
 * Seam for delivering push notifications through Gotify (ADR 0027). Implementations are fed by each
 * service's transactional outbox.
 */
public interface PushSender {

    void send(PushMessage message);

    record PushMessage(String userId, String type, String title, String body, String payloadJson) {}
}
