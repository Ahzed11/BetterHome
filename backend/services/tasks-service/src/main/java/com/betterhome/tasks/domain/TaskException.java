package com.betterhome.tasks.domain;

public abstract class TaskException extends RuntimeException {

    private final String code;

    protected TaskException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String code() {
        return code;
    }

    public static final class NotFound extends TaskException {
        public NotFound(String message) {
            super("not_found", message);
        }
    }

    public static final class Forbidden extends TaskException {
        public Forbidden(String message) {
            super("forbidden", message);
        }
    }

    public static final class Conflict extends TaskException {
        public Conflict(String message) {
            super("conflict", message);
        }
    }

    public static final class BadRequest extends TaskException {
        public BadRequest(String message) {
            super("bad_request", message);
        }
    }

    public static final class Unauthorized extends TaskException {
        public Unauthorized(String message) {
            super("unauthorized", message);
        }
    }

    public static final class ServiceUnavailable extends TaskException {
        public ServiceUnavailable(String message) {
            super("service_unavailable", message);
        }
    }
}
