package com.betterhome.notifications.domain;

public abstract class NotificationException extends RuntimeException {

    private final String code;

    protected NotificationException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String code() {
        return code;
    }

    public static final class Unauthorized extends NotificationException {
        public Unauthorized(String message) {
            super("unauthorized", message);
        }
    }

    public static final class Forbidden extends NotificationException {
        public Forbidden(String message) {
            super("forbidden", message);
        }
    }

    public static final class NotFound extends NotificationException {
        public NotFound(String message) {
            super("not_found", message);
        }
    }

    public static final class BadRequest extends NotificationException {
        public BadRequest(String message) {
            super("bad_request", message);
        }
    }

    public static final class ServiceUnavailable extends NotificationException {
        public ServiceUnavailable(String message) {
            super("service_unavailable", message);
        }
    }
}
