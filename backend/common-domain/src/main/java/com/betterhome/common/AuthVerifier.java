package com.betterhome.common;

import java.util.Optional;
import java.util.UUID;

/**
 * Seam for resolving the authenticated caller's identity from the request security context.
 * Keycloak {@code sub} maps to our {@code auth_subject}; services look up their own {@code
 * USER.id}.
 */
public interface AuthVerifier {

    /**
     * @return Keycloak subject UUID when a valid bearer token is present
     */
    Optional<UUID> currentAuthSubject();
}
