package com.betterhome.scoring.domain;

public abstract class ScoringException extends RuntimeException {

    private final String code;

    protected ScoringException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String code() {
        return code;
    }

    public static final class NotFound extends ScoringException {
        public NotFound(String message) {
            super("not_found", message);
        }
    }

    public static final class Forbidden extends ScoringException {
        public Forbidden(String message) {
            super("forbidden", message);
        }
    }

    public static final class Conflict extends ScoringException {
        public Conflict(String message) {
            super("conflict", message);
        }
    }

    public static final class BadRequest extends ScoringException {
        public BadRequest(String message) {
            super("bad_request", message);
        }
    }

    public static final class Unauthorized extends ScoringException {
        public Unauthorized(String message) {
            super("unauthorized", message);
        }
    }
}
