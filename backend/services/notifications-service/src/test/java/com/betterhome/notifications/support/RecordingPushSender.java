package com.betterhome.notifications.support;

import com.betterhome.common.PushSender;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CopyOnWriteArrayList;

/** The push gateway boundary in tests: remembers what it was asked to send. */
@Alternative
@Priority(2)
@ApplicationScoped
public class RecordingPushSender implements PushSender {

    private final List<PushMessage> sent = new CopyOnWriteArrayList<>();
    private final Queue<Outcome> scripted = new ConcurrentLinkedQueue<>();

    /** The outcomes of the next calls, in order; once used up every call is {@code SENT}. */
    public void script(Outcome... outcomes) {
        scripted.clear();
        scripted.addAll(List.of(outcomes));
    }

    /** Every call, whatever its outcome. */
    @Override
    public Outcome send(PushMessage message) {
        sent.add(message);
        Outcome next = scripted.poll();
        return next == null ? Outcome.SENT : next;
    }

    public List<PushMessage> sent() {
        return List.copyOf(sent);
    }

    public void clear() {
        sent.clear();
        scripted.clear();
    }
}
