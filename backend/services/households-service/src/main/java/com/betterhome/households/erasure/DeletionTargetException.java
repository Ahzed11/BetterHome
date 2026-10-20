package com.betterhome.households.erasure;

/** A target could not be told about a deleted account right now; the deletion is retried. */
public class DeletionTargetException extends RuntimeException {

    public DeletionTargetException(String message) {
        super(message);
    }
}
