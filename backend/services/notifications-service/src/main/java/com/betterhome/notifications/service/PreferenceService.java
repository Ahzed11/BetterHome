package com.betterhome.notifications.service;

import com.betterhome.common.Clock;
import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.NotificationException;
import com.betterhome.notifications.domain.NotificationPreference;
import com.betterhome.notifications.domain.NotificationType;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Per user choices of spec §5, one per type and channel. Everything is enabled until the user says
 * otherwise, so a missing row never has to be created up front.
 */
@ApplicationScoped
public class PreferenceService {

    /** One cell of the preference grid. */
    public record Preference(NotificationType type, Channel channel, boolean enabled) {}

    private final Clock clock;

    @Inject
    public PreferenceService(Clock clock) {
        this.clock = clock;
    }

    /** The channels this user still wants this type on. Empty means no notification at all. */
    @Transactional
    public List<Channel> enabledChannels(UUID userId, NotificationType type) {
        Map<Channel, Boolean> chosen = new HashMap<>();
        for (NotificationPreference row : NotificationPreference.forUser(userId)) {
            if (row.type == type) {
                chosen.put(row.channel, row.enabled);
            }
        }
        List<Channel> enabled = new ArrayList<>();
        for (Channel channel : Channel.values()) {
            if (chosen.getOrDefault(channel, true)) {
                enabled.add(channel);
            }
        }
        return enabled;
    }

    /** Every type and channel with the user's choice, defaults filled in. */
    @Transactional
    public List<Preference> list(UUID userId) {
        Map<String, Boolean> chosen = new HashMap<>();
        for (NotificationPreference row : NotificationPreference.forUser(userId)) {
            chosen.put(row.type.name() + "/" + row.channel.name(), row.enabled);
        }
        List<Preference> grid = new ArrayList<>();
        for (NotificationType type : NotificationType.values()) {
            for (Channel channel : Channel.values()) {
                grid.add(
                        new Preference(
                                type,
                                channel,
                                chosen.getOrDefault(type.name() + "/" + channel.name(), true)));
            }
        }
        return grid;
    }

    @Transactional
    public Preference set(UUID userId, String typeName, String channelName, boolean enabled) {
        NotificationType type =
                NotificationType.parse(typeName)
                        .orElseThrow(
                                () ->
                                        new NotificationException.BadRequest(
                                                "Unknown notification type"));
        Channel channel =
                Channel.parse(channelName)
                        .orElseThrow(() -> new NotificationException.BadRequest("Unknown channel"));
        NotificationPreference row =
                NotificationPreference.findChoice(userId, type, channel)
                        .orElseGet(() -> newRow(userId, type, channel));
        row.enabled = enabled;
        row.updatedAt = clock.now();
        row.persist();
        return new Preference(type, channel, enabled);
    }

    private static NotificationPreference newRow(
            UUID userId, NotificationType type, Channel channel) {
        NotificationPreference row = new NotificationPreference();
        row.id = UUID.randomUUID();
        row.userId = userId;
        row.type = type;
        row.channel = channel;
        return row;
    }
}
