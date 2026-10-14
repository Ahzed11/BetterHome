package com.betterhome.common;

/**
 * Boundary to the ingest endpoint of notifications-service. Each producing service relays its
 * outbox through it, so delivery is at least once and notifications-service stores each idempotency
 * key once.
 */
public interface NotificationsGateway {

    /**
     * Hands the event over. Returns normally when notifications-service accepted it, including when
     * it had stored the key before or the recipient switched the type off.
     *
     * @throws NotificationDeliveryException.Unavailable when the event may be sent again later
     * @throws NotificationDeliveryException.Rejected when the event itself is refused and sending
     *     it again cannot succeed
     */
    void deliver(NotificationEvent event);
}
