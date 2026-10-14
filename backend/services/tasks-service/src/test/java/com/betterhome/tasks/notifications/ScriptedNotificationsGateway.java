package com.betterhome.tasks.notifications;

import com.betterhome.common.NotificationEvent;
import com.betterhome.common.NotificationsGateway;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedDeque;
import java.util.concurrent.TimeUnit;

/**
 * In-process notifications-service that stands in for {@link HttpNotificationsGateway} in Quarkus
 * tests. A test scripts how the next calls end, and reads what was delivered.
 */
@Alternative
@Priority(1)
@ApplicationScoped
public class ScriptedNotificationsGateway implements NotificationsGateway {

    private record Outcome(RuntimeException failure, boolean recordFirst) {}

    private final List<NotificationEvent> delivered =
            Collections.synchronizedList(new ArrayList<>());
    private final ConcurrentLinkedDeque<Outcome> script = new ConcurrentLinkedDeque<>();
    private volatile long latencyMillis;

    /** The next call fails with {@code failure} before the event is stored. */
    public void failNext(RuntimeException failure) {
        script.add(new Outcome(failure, false));
    }

    /**
     * The next call stores the event and then fails, as when the answer is lost on the way back.
     */
    public void failNextAfterStoring(RuntimeException failure) {
        script.add(new Outcome(failure, true));
    }

    /** Every call takes this long, so concurrent relays overlap. */
    public void setLatencyMillis(long millis) {
        this.latencyMillis = millis;
    }

    public List<NotificationEvent> delivered() {
        synchronized (delivered) {
            return List.copyOf(delivered);
        }
    }

    public void reset() {
        delivered.clear();
        script.clear();
        latencyMillis = 0;
    }

    @Override
    public void deliver(NotificationEvent event) {
        pause();
        Outcome outcome = script.poll();
        if (outcome == null) {
            delivered.add(event);
            return;
        }
        if (outcome.recordFirst()) {
            delivered.add(event);
        }
        throw outcome.failure();
    }

    private void pause() {
        if (latencyMillis > 0) {
            try {
                TimeUnit.MILLISECONDS.sleep(latencyMillis);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("Interrupted while simulating latency", e);
            }
        }
    }
}
