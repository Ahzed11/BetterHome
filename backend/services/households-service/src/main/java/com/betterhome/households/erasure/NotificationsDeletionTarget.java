package com.betterhome.households.erasure;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/** Tells notifications-service to delete the deleted user's data. */
@ApplicationScoped
public class NotificationsDeletionTarget extends ServiceDeletionTarget {

    private final NotificationsAnonymizeClient client;

    @Inject
    public NotificationsDeletionTarget(@RestClient NotificationsAnonymizeClient client) {
        this.client = client;
    }

    @Override
    public String name() {
        return "notifications";
    }

    @Override
    protected void anonymize(UUID userId) {
        client.anonymize(userId);
    }
}
