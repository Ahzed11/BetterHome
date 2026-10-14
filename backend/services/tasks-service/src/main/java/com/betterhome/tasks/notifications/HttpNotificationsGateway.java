package com.betterhome.tasks.notifications;

import com.betterhome.common.NotificationDeliveryException;
import com.betterhome.common.NotificationEvent;
import com.betterhome.common.NotificationsGateway;
import io.quarkus.oidc.client.OidcClientException;
import io.quarkus.oidc.client.Tokens;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/**
 * Sends events to notifications-service with this service's own client-credentials token. A client
 * error other than an authorization one means the event itself is refused; anything else is worth
 * trying again.
 */
@ApplicationScoped
public class HttpNotificationsGateway implements NotificationsGateway {

    private final NotificationsClient client;
    private final Tokens tokens;

    @Inject
    public HttpNotificationsGateway(@RestClient NotificationsClient client, Tokens tokens) {
        this.client = client;
        this.tokens = tokens;
    }

    @Override
    public void deliver(NotificationEvent event) {
        try {
            client.ingest(
                    "Bearer " + tokens.getAccessToken(),
                    new NotificationsClient.IngestRequest(
                            event.idempotencyKey(),
                            event.householdId(),
                            event.userId(),
                            event.type(),
                            event.payload()));
        } catch (WebApplicationException e) {
            int status = e.getResponse().getStatus();
            if (isRefusal(status)) {
                throw new NotificationDeliveryException.Rejected(
                        "notifications-service refused the event with " + status);
            }
            throw new NotificationDeliveryException.Unavailable(
                    "notifications-service answered " + status);
        } catch (ProcessingException | OidcClientException e) {
            throw new NotificationDeliveryException.Unavailable(
                    "notifications-service is unreachable");
        }
    }

    /** A 4xx about the event; 401 and 403 are about this service's token and can be fixed. */
    private static boolean isRefusal(int status) {
        return status >= 400 && status < 500 && status != 401 && status != 403 && status != 429;
    }
}
