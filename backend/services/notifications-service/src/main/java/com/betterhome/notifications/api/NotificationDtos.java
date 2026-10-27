package com.betterhome.notifications.api;

import com.betterhome.notifications.domain.Channel;
import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationType;
import com.betterhome.notifications.service.AnonymizationService;
import com.betterhome.notifications.service.IngestService;
import com.betterhome.notifications.service.PreferenceService;
import com.betterhome.notifications.service.PushTargetService;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

public final class NotificationDtos {

    private NotificationDtos() {}

    public record NotificationResponse(
            @Schema(required = true) UUID id,
            @Schema(required = true) UUID householdId,
            @Schema(required = true) NotificationType type,
            @Schema(required = true) Channel channel,
            @Schema(required = true) String title,
            @Schema(required = true) String body,
            @Schema(required = true) Map<String, String> payload,
            @Schema(required = true) Instant createdAt,
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

    public record ReadAllResponse(@Schema(required = true) int updated) {}

    /** Rows deleted per kind by an account deletion; both zero when nothing was left. */
    public record NotificationsAnonymizationResponse(
            @Schema(required = true) long notificationsDeleted,
            @Schema(required = true) long preferencesDeleted) {

        public static NotificationsAnonymizationResponse from(AnonymizationService.Result result) {
            return new NotificationsAnonymizationResponse(
                    result.notificationsDeleted(), result.preferencesDeleted());
        }
    }

    public record PreferenceResponse(
            @Schema(required = true) NotificationType type,
            @Schema(required = true) Channel channel,
            @Schema(required = true) boolean enabled) {

        public static PreferenceResponse from(PreferenceService.Preference preference) {
            return new PreferenceResponse(
                    preference.type(), preference.channel(), preference.enabled());
        }
    }

    public record UpdatePreferenceRequest(@NotNull Boolean enabled) {}

    /** A Gotify application token. Characters are limited so it cannot break a header. */
    public record RegisterPushTargetRequest(
            @NotBlank @Size(max = 128) @Pattern(regexp = "[A-Za-z0-9._~-]*") String token) {}

    /** Says that a target exists and since when; the token is never returned. */
    public record PushTargetResponse(@Schema(required = true) Instant registeredAt) {

        public static PushTargetResponse from(PushTargetService.Registration registration) {
            return new PushTargetResponse(registration.registeredAt());
        }
    }

    /** An event from another service. {@code type} is validated against the spec §5 list. */
    public record IngestRequest(
            @NotBlank @Size(max = 200) String idempotencyKey,
            @NotNull UUID householdId,
            @NotNull UUID userId,
            @NotBlank String type,
            Map<String, String> payload,
            @Size(max = 8) String localeHint) {}

    public record IngestResponse(
            @Schema(required = true) IngestService.Outcome outcome,
            NotificationResponse notification) {}
}
