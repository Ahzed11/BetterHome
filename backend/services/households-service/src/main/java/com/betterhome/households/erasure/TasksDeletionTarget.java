package com.betterhome.households.erasure;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/** Tells tasks-service to anonymize the deleted user's data. */
@ApplicationScoped
public class TasksDeletionTarget extends ServiceDeletionTarget {

    private final TasksAnonymizeClient client;

    @Inject
    public TasksDeletionTarget(@RestClient TasksAnonymizeClient client) {
        this.client = client;
    }

    @Override
    public String name() {
        return "tasks";
    }

    @Override
    protected void anonymize(UUID userId) {
        client.anonymize(userId);
    }
}
