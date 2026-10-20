package com.betterhome.households;

import com.betterhome.households.erasure.ListsAnonymizeClient;
import com.betterhome.households.erasure.NotificationsAnonymizeClient;
import com.betterhome.households.erasure.ScoringAnonymizeClient;
import com.betterhome.households.erasure.TasksAnonymizeClient;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Singleton;
import java.util.List;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/**
 * Stands in for the anonymize endpoints of the other four services, one recorder each. Produced
 * rather than implemented, because a class implementing two of these interfaces would be taken for
 * a server resource declaring the same route twice. Selected in the test configuration.
 */
@Singleton
public class RecordingAnonymizeClients {

    public final RecordingAnonymizeClient tasks = new RecordingAnonymizeClient();
    public final RecordingAnonymizeClient scoring = new RecordingAnonymizeClient();
    public final RecordingAnonymizeClient lists = new RecordingAnonymizeClient();
    public final RecordingAnonymizeClient notifications = new RecordingAnonymizeClient();

    public List<RecordingAnonymizeClient> all() {
        return List.of(tasks, scoring, lists, notifications);
    }

    public void reset() {
        all().forEach(RecordingAnonymizeClient::reset);
    }

    @Produces
    @Alternative
    @ApplicationScoped
    @RestClient
    TasksAnonymizeClient tasksClient() {
        return tasks::anonymize;
    }

    @Produces
    @Alternative
    @ApplicationScoped
    @RestClient
    ScoringAnonymizeClient scoringClient() {
        return scoring::anonymize;
    }

    @Produces
    @Alternative
    @ApplicationScoped
    @RestClient
    ListsAnonymizeClient listsClient() {
        return lists::anonymize;
    }

    @Produces
    @Alternative
    @ApplicationScoped
    @RestClient
    NotificationsAnonymizeClient notificationsClient() {
        return notifications::anonymize;
    }
}
