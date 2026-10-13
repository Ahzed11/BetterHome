package com.betterhome.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import java.security.Principal;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class OidcAuthVerifierTest {

    private static final UUID SUBJECT = UUID.fromString("0b1c2d3e-4f50-4162-8394-a5b6c7d8e9f0");

    private static SecurityIdentity identityNamed(String name) {
        Principal principal = () -> name;
        return QuarkusSecurityIdentity.builder().setPrincipal(principal).build();
    }

    @Test
    void validUuidPrincipalIsReturnedAsAuthSubject() {
        OidcAuthVerifier verifier = new OidcAuthVerifier(identityNamed(SUBJECT.toString()));

        assertEquals(Optional.of(SUBJECT), verifier.currentAuthSubject());
    }

    @Test
    void anonymousIdentityHasNoAuthSubject() {
        SecurityIdentity anonymous = QuarkusSecurityIdentity.builder().setAnonymous(true).build();

        assertTrue(new OidcAuthVerifier(anonymous).currentAuthSubject().isEmpty());
    }

    @Test
    void missingIdentityHasNoAuthSubject() {
        assertTrue(new OidcAuthVerifier(null).currentAuthSubject().isEmpty());
    }

    @Test
    void nullPrincipalNameHasNoAuthSubject() {
        assertTrue(new OidcAuthVerifier(identityNamed(null)).currentAuthSubject().isEmpty());
    }

    @Test
    void blankPrincipalNameHasNoAuthSubject() {
        assertTrue(new OidcAuthVerifier(identityNamed("  ")).currentAuthSubject().isEmpty());
    }

    @Test
    void nonUuidPrincipalNameSuchAsPreferredUsernameHasNoAuthSubject() {
        assertTrue(new OidcAuthVerifier(identityNamed("alice")).currentAuthSubject().isEmpty());
    }
}
