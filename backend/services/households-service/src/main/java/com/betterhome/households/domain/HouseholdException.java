package com.betterhome.households.domain;

public abstract class HouseholdException extends RuntimeException {

    private final String code;

    protected HouseholdException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String code() {
        return code;
    }

    public static final class NotFound extends HouseholdException {
        public NotFound(String message) {
            super("not_found", message);
        }
    }

    public static final class Forbidden extends HouseholdException {
        public Forbidden(String message) {
            super("forbidden", message);
        }
    }

    public static final class Conflict extends HouseholdException {
        public Conflict(String message) {
            super("conflict", message);
        }
    }

    public static final class BadRequest extends HouseholdException {
        public BadRequest(String message) {
            super("bad_request", message);
        }
    }

    public static final class Unauthorized extends HouseholdException {
        public Unauthorized(String message) {
            super("unauthorized", message);
        }
    }

    public static final class ServiceUnavailable extends HouseholdException {
        public ServiceUnavailable(String message) {
            super("service_unavailable", message);
        }
    }
}
