package com.betterhome.common;

/** Why an event did not reach notifications-service. */
public abstract sealed class NotificationDeliveryException extends RuntimeException {

    private NotificationDeliveryException(String message) {
        super(message);
    }

    /** The service, the network or the token endpoint failed; the event is worth retrying. */
    public static final class Unavailable extends NotificationDeliveryException {
        public Unavailable(String message) {
            super(message);
        }
    }

    /** The service refused the event itself (a client error); retrying cannot help. */
    public static final class Rejected extends NotificationDeliveryException {
        public Rejected(String message) {
            super(message);
        }
    }
}
