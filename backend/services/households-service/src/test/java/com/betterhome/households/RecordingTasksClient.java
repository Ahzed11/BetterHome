package com.betterhome.households;

import com.betterhome.households.service.TasksClient;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/** Stands in for the tasks-service HTTP boundary and records what households asked it to do. */
@Alternative
@Priority(1)
@ApplicationScoped
@RestClient
public class RecordingTasksClient implements TasksClient {

    public record Call(String authorization, UUID householdId, UUID userId) {}

    private final List<Call> calls = new CopyOnWriteArrayList<>();
    private volatile RuntimeException failure;

    @Override
    public void dismissAway(String authorization, UUID householdId, UUID userId) {
        calls.add(new Call(authorization, householdId, userId));
        if (failure != null) {
            throw failure;
        }
    }

    public List<Call> calls() {
        return List.copyOf(calls);
    }

    public void failWith(RuntimeException failure) {
        this.failure = failure;
    }

    public void reset() {
        calls.clear();
        failure = null;
    }
}
