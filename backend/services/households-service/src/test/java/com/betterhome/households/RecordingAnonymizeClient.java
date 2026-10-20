package com.betterhome.households;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;

/** Records the anonymize calls households makes to one service and can make them fail. */
public class RecordingAnonymizeClient {

    private final List<UUID> calls = new CopyOnWriteArrayList<>();
    private volatile RuntimeException failure;

    public void anonymize(UUID userId) {
        calls.add(userId);
        if (failure != null) {
            throw failure;
        }
    }

    public List<UUID> calls() {
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
