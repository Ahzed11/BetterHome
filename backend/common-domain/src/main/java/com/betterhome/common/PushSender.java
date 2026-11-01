package com.betterhome.common;

/**
 * Seam for delivering push notifications through Gotify (ADR 0027). Implementations are fed by each
 * service's transactional outbox.
 */
public interface PushSender {

    /** What became of one attempt to deliver a push. */
    enum Outcome {
        /** The push server took the message. */
        SENT,
        /** It can never be delivered (no server, no target, a refused token): do not try again. */
        UNDELIVERABLE,
        /** The server could not be reached or failed: worth trying again later. */
        RETRY
    }

    Outcome send(PushMessage message);

    record PushMessage(String userId, String type, String title, String body, String payloadJson) {}
}
