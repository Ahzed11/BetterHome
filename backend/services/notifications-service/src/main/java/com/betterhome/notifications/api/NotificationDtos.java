package com.betterhome.notifications.api;

import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationType;
import com.betterhome.notifications.service.IngestService;
import com.betterhome.notifications.service.PreferenceService;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public final class NotificationDtos {

    private NotificationDtos() {}

    public record NotificationResponse(
            UUID id,
            UUID householdId,
            NotificationType type,
            Channel channel,
            String title,
            String body,
            Map<String, String> payload,
            Instant createdAt,
            Instant readAt) {

        public static NotificationResponse from(Notification notification) {
            return new NotificationResponse(
                    notification.id,
                    notification.householdId,
                    notification.type,
                    notification.channel,
                    notification.title,
                    notification.body,
                    notification.payload,
                    notification.createdAt,
                    notification.readAt);
        }
    }

    public record ReadAllResponse(int updated) {}

    public record PreferenceResponse(NotificationType type, Channel channel, boolean enabled) {

        public static PreferenceResponse from(PreferenceService.Preference preference) {
            return new PreferenceResponse(
                    preference.type(), preference.channel(), preference.enabled());
        }
    }

    public record UpdatePreferenceRequest(@NotNull Boolean enabled) {}

    /** An event from another service. {@code type} is validated against the spec §5 list. */
    public record IngestRequest(
            @NotBlank @Size(max = 200) String idempotencyKey,
            @NotNull UUID householdId,
            @NotNull UUID userId,
            @NotBlank String type,
            Map<String, String> payload,
            @Size(max = 8) String localeHint) {}

    public record IngestResponse(
            IngestService.Outcome outcome, NotificationResponse notification) {}
}
