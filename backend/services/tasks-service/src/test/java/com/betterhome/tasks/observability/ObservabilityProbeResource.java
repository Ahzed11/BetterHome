package com.betterhome.tasks.observability;

import com.betterhome.tasks.membership.FakeHouseholdsServer;
import com.betterhome.tasks.membership.HttpMembershipGateway;
import io.opentelemetry.api.trace.Span;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.util.Map;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.jboss.logging.Logger;
import org.jboss.logging.MDC;

/**
 * Test-only endpoint: handles one request the way production code does (log a line, then call
 * households-service through the real REST client) and reports the ids it saw.
 */
@Path("/observability-probe")
public class ObservabilityProbeResource {

    private static final Logger LOG = Logger.getLogger(ObservabilityProbeResource.class);

    @Inject HttpMembershipGateway gateway;

    @GET
    @Operation(hidden = true)
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, String> probe() {
        LOG.info("probe handled");
        gateway.householdSettings(UUID.fromString(FakeHouseholdsServer.HOUSEHOLD));
        return Map.of(
                "requestId", String.valueOf(MDC.get("requestId")),
                "traceId", Span.current().getSpanContext().getTraceId());
    }
}
