package com.betterhome.common;

import jakarta.enterprise.context.ApplicationScoped;
import java.util.logging.Logger;

/**
 * Default push sender that logs and drops messages. Replaced when the notifications gateway
 * is wired (Phase 4).
 */
@ApplicationScoped
public class NoOpPushSender implements PushSender {

    private static final Logger LOG = Logger.getLogger(NoOpPushSender.class.getName());

    @Override
    public void send(PushMessage message) {
        LOG.fine(() -> "Push suppressed (no-op): type=" + message.type() + " user=" + message.userId());
    }
}
