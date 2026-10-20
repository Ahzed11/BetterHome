package com.betterhome.households.erasure;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/** Tells lists-service to anonymize the deleted user's data. */
@ApplicationScoped
public class ListsDeletionTarget extends ServiceDeletionTarget {

    private final ListsAnonymizeClient client;

    @Inject
    public ListsDeletionTarget(@RestClient ListsAnonymizeClient client) {
        this.client = client;
    }

    @Override
    public String name() {
        return "lists";
    }

    @Override
    protected void anonymize(UUID userId) {
        client.anonymize(userId);
    }
}
