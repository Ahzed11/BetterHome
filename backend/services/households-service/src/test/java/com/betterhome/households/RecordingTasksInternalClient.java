package com.betterhome.households;

import com.betterhome.households.service.TasksInternalClient;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import org.eclipse.microprofile.rest.client.inject.RestClient;

/** Stands in for the service-account calls to tasks-service and records them. */
@Alternative
@Priority(1)
@ApplicationScoped
@RestClient
public class RecordingTasksInternalClient implements TasksInternalClient {

    public record Call(UUID householdId, UUID userId, UUID dismissedBy) {}

    private final List<Call> calls = new CopyOnWriteArrayList<>();
    private volatile RuntimeException failure;
    private volatile Runnable duringCall = () -> {};

    @Override
    public DismissedCount dismissAway(UUID householdId, UUID userId, UUID dismissedBy) {
        calls.add(new Call(householdId, userId, dismissedBy));
        duringCall.run();
        if (failure != null) {
            throw failure;
        }
        return new DismissedCount(1);
    }

    public List<Call> calls() {
        return List.copyOf(calls);
    }

    public void failWith(RuntimeException failure) {
        this.failure = failure;
    }

    public void duringCall(Runnable action) {
        this.duringCall = action;
    }

    public void reset() {
        calls.clear();
        failure = null;
        duringCall = () -> {};
    }
}
