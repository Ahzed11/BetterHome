package com.betterhome.households;

import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.UUID;
import java.util.function.Supplier;

@ApplicationScoped
public class SecurityTestSupport {

    @Inject
    CurrentIdentityAssociation identityAssociation;

    public <T> T asUser(UUID authSubject, Supplier<T> action) {
        SecurityIdentity previous = identityAssociation.getIdentity();
        QuarkusSecurityIdentity identity =
                QuarkusSecurityIdentity.builder()
                        .setPrincipal(() -> authSubject.toString())
                        .addRole("member")
                        .build();
        identityAssociation.setIdentity(identity);
        try {
            return action.get();
        } finally {
            if (previous != null) {
                identityAssociation.setIdentity(previous);
            } else {
                identityAssociation.setIdentity(
                        QuarkusSecurityIdentity.builder().setAnonymous(true).build());
            }
        }
    }

    public void asUser(UUID authSubject, Runnable action) {
        asUser(
                authSubject,
                () -> {
                    action.run();
                    return null;
                });
    }
}
