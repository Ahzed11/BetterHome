package com.betterhome.common;

import io.quarkus.security.identity.SecurityIdentity;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.Optional;
import java.util.UUID;

@ApplicationScoped
public class OidcAuthVerifier implements AuthVerifier {

    private final SecurityIdentity securityIdentity;

    @Inject
    public OidcAuthVerifier(SecurityIdentity securityIdentity) {
        this.securityIdentity = securityIdentity;
    }

    @Override
    public Optional<UUID> currentAuthSubject() {
        if (securityIdentity == null || securityIdentity.isAnonymous()) {
            return Optional.empty();
        }
        String name = securityIdentity.getPrincipal().getName();
        if (name == null || name.isBlank()) {
            return Optional.empty();
        }
        try {
            return Optional.of(UUID.fromString(name));
        } catch (IllegalArgumentException ex) {
            return Optional.empty();
        }
    }
}
