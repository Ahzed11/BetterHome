package com.betterhome.households;

import com.betterhome.common.AuthVerifier;
import com.betterhome.common.Clock;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@Path("/v1/meta")
@Produces(MediaType.APPLICATION_JSON)
public class ServiceInfoResource {

    private final String serviceName;
    private final AuthVerifier authVerifier;
    private final Clock clock;

    @Inject
    public ServiceInfoResource(
            @ConfigProperty(name = "quarkus.application.name") String serviceName,
            AuthVerifier authVerifier,
            Clock clock) {
        this.serviceName = serviceName;
        this.authVerifier = authVerifier;
        this.clock = clock;
    }

    @GET
    @RolesAllowed({"member", "admin"})
    public Map<String, Object> info() {
        Optional<UUID> subject = authVerifier.currentAuthSubject();
        Instant now = clock.now();
        return Map.of(
                "service", serviceName,
                "now", now.toString(),
                "authSubject", subject.map(UUID::toString).orElse(""));
    }
}
