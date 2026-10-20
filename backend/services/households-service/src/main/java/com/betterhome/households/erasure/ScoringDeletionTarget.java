package com.betterhome.households.erasure;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.UUID;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/** Tells scoring-service to anonymize the deleted user's data. */
@ApplicationScoped
public class ScoringDeletionTarget extends ServiceDeletionTarget {

    private final ScoringAnonymizeClient client;

    @Inject
    public ScoringDeletionTarget(@RestClient ScoringAnonymizeClient client) {
        this.client = client;
    }

    @Override
    public String name() {
        return "scoring";
    }

    @Override
    protected void anonymize(UUID userId) {
        client.anonymize(userId);
    }
}
