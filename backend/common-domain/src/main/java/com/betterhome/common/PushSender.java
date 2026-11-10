package com.betterhome.common;

/**
 * Seam for delivering push notifications through Gotify (ADR 0027). Implementations are fed by each
 * service's transactional outbox.
 */
public interface PushSender {

    /** Tries once to deliver the message and says what became of it. */
    Outcome send(PushMessage message);

    /** What became of one attempt. Only {@link #UNAVAILABLE} is worth trying again. */
    enum Outcome {
        /** The gateway took the message. */
        DELIVERED,
        /** There was nothing to deliver to: no gateway configured, or the user has no target. */
        SKIPPED,
        /** The gateway refused the target or the message; trying again cannot help. */
        REFUSED,
        /** A timeout, a connection error or a server error; a later attempt may succeed. */
        UNAVAILABLE
    }

    record PushMessage(String userId, String type, String title, String body, String payloadJson) {}
}
