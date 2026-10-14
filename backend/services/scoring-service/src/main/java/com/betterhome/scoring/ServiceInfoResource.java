package com.betterhome.scoring;

import com.betterhome.common.AuthVerifier;
import com.betterhome.common.Clock;
import com.betterhome.scoring.api.ErrorResponse;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/v1/meta")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "meta")
@APIResponse(responseCode = "401", description = "Not authenticated")
@APIResponse(
        responseCode = "403",
        description = "Not allowed to do this",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
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

    @APIResponse(
            responseCode = "200",
            description = "OK",
            content = @Content(schema = @Schema(implementation = ServiceInfo.class)))
    @Operation(
            operationId = "getScoringServiceInfo",
            summary = "Service name, server time and caller subject")
    @GET
    @RolesAllowed({"member", "admin"})
    public ServiceInfo info() {
        Optional<UUID> subject = authVerifier.currentAuthSubject();
        Instant now = clock.now();
        return new ServiceInfo(serviceName, now.toString(), subject.map(UUID::toString).orElse(""));
    }

    /** Who answered, when, and which subject the caller authenticated as (empty if unknown). */
    public record ServiceInfo(String service, String now, String authSubject) {}
}
