package com.betterhome.households.erasure;

import java.util.UUID;

/**
 * One place that holds data about a user and must be told when the account is deleted: another
 * service, or the identity provider. Every implementation is idempotent, because a target that
 * confirmed but whose confirmation was lost is called again.
 */
public interface DeletionTarget {

    /** Stable name recorded once the target confirmed, for example {@code tasks}. */
    String name();

    /**
     * Removes or anonymizes the user. Returns normally when nothing about the user is left there,
     * including when there never was anything.
     *
     * @param userId the user's id in BetterHome tables
     * @param authSubject the user's subject in the identity provider
     * @throws DeletionTargetException when the target could not be told and should be tried again
     */
    void erase(UUID userId, UUID authSubject);
}
