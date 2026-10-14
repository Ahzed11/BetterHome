package com.betterhome.tasks.notifications;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.core.MediaType;
import java.util.Map;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/** REST boundary to the event ingest of notifications-service (service role only, ADR 0017). */
@RegisterRestClient(configKey = "notifications")
@Path("/v1/internal/notifications")
@Consumes(MediaType.APPLICATION_JSON)
public interface NotificationsClient {

    record IngestRequest(
            String idempotencyKey,
            UUID householdId,
            UUID userId,
            String type,
            Map<String, String> payload) {}

    @POST
    void ingest(@HeaderParam("Authorization") String authorization, IngestRequest request);
}
