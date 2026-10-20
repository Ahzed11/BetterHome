package com.betterhome.households.erasure;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.UUID;

/** Removes the user's login (credentials, email, names) from the identity provider. */
@ApplicationScoped
public class IdentityDeletionTarget implements DeletionTarget {

    private final IdentityAdmin identityAdmin;

    @Inject
    public IdentityDeletionTarget(IdentityAdmin identityAdmin) {
        this.identityAdmin = identityAdmin;
    }

    @Override
    public String name() {
        return "identity";
    }

    @Override
    public void erase(UUID userId, UUID authSubject) {
        identityAdmin.deleteUser(authSubject);
    }
}
