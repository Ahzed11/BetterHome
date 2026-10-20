package com.betterhome.households.erasure;

import java.util.UUID;

/**
 * Boundary to the identity provider's administration (Keycloak Admin REST API today). Keeps the
 * deletion flow independent of the provider, like {@code AuthVerifier} does for token checks.
 */
public interface IdentityAdmin {

    /**
     * Deletes the account with this subject, credentials and personal attributes included. Returns
     * normally when the account is gone, including when it never existed or was already deleted.
     *
     * @throws DeletionTargetException when the provider could not be reached or refused
     */
    void deleteUser(UUID authSubject);
}
