package com.betterhome.notifications.domain;

import java.util.Optional;

/** Delivery channels in use. Email can be added later with a migration of the CHECK constraints. */
public enum Channel {
    push,
    in_app;

    public static Optional<Channel> parse(String value) {
        for (Channel channel : values()) {
            if (channel.name().equals(value)) {
                return Optional.of(channel);
            }
        }
        return Optional.empty();
    }
}
