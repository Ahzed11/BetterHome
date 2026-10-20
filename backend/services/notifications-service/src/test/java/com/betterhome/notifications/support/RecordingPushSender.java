package com.betterhome.notifications.support;

import com.betterhome.common.PushSender;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/** The push gateway boundary in tests: remembers what it was asked to send. */
@Alternative
@Priority(2)
@ApplicationScoped
public class RecordingPushSender implements PushSender {

    private final List<PushMessage> sent = new CopyOnWriteArrayList<>();

    @Override
    public void send(PushMessage message) {
        sent.add(message);
    }

    public List<PushMessage> sent() {
        return List.copyOf(sent);
    }

    public void clear() {
        sent.clear();
    }
}
