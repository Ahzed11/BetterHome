package com.betterhome.common.oidc;

import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.UUID;

/**
 * Switches token validation on for a test class and signs tokens shaped like Keycloak's (the
 * subject is a UUID, the username is something else), so tests exercise the real principal mapping
 * instead of {@code @TestSecurity}.
 */
public class RealOidcTestResource implements QuarkusTestResourceLifecycleManager {

    private static final String ISSUER = "https://keycloak.test/realms/betterhome";
    private static final Base64.Encoder URL = Base64.getUrlEncoder().withoutPadding();

    private static volatile KeyPair keyPair;

    @Override
    public Map<String, String> start() {
        try {
            KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
            generator.initialize(2048);
            keyPair = generator.generateKeyPair();
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("Cannot generate a test signing key", e);
        }
        return Map.of(
                "quarkus.oidc.tenant-enabled",
                "true",
                "quarkus.oidc.discovery-enabled",
                "false",
                "quarkus.oidc.public-key",
                Base64.getEncoder().encodeToString(keyPair.getPublic().getEncoded()),
                "quarkus.oidc.token.issuer",
                ISSUER);
    }

    @Override
    public void stop() {
        keyPair = null;
    }

    /**
     * A signed access token for a member, shaped like Keycloak's: the subject differs from the
     * username and roles sit only under {@code realm_access.roles}.
     */
    public static String token(UUID subject, String preferredUsername) {
        Instant now = Instant.now();
        String header = "{\"alg\":\"RS256\",\"typ\":\"JWT\"}";
        String claims =
                "{\"iss\":\""
                        + ISSUER
                        + "\","
                        + "\"sub\":\""
                        + subject
                        + "\","
                        + "\"preferred_username\":\""
                        + preferredUsername
                        + "\","
                        + "\"iat\":"
                        + now.getEpochSecond()
                        + ","
                        + "\"exp\":"
                        + now.plusSeconds(300).getEpochSecond()
                        + ","
                        + "\"realm_access\":{\"roles\":[\"member\"]}}";
        String signingInput = encode(header) + "." + encode(claims);
        return signingInput + "." + URL.encodeToString(sign(signingInput));
    }

    private static String encode(String json) {
        return URL.encodeToString(json.getBytes(StandardCharsets.UTF_8));
    }

    private static byte[] sign(String input) {
        try {
            Signature signature = Signature.getInstance("SHA256withRSA");
            signature.initSign(keyPair.getPrivate());
            signature.update(input.getBytes(StandardCharsets.UTF_8));
            return signature.sign();
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("Cannot sign the test token", e);
        }
    }
}
