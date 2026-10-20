package com.betterhome.notifications.service;

import com.betterhome.notifications.domain.Notification;
import com.betterhome.notifications.domain.NotificationPreference;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import java.util.UUID;

/**
 * Account deletion (spec §9). Unlike the other services this one keeps no history worth
 * anonymizing: a notification is a message to one person (its title, body and payload name tasks
 * and household members) and a preference is that person's own choice. Both are deleted.
 */
@ApplicationScoped
public class AnonymizationService {

    /** Rows deleted per kind. Both zero when the user has nothing here, or already left. */
    public record Result(long notificationsDeleted, long preferencesDeleted) {}

    /** Idempotent: a second call for the same user finds nothing left to delete. */
    @Transactional
    public Result anonymize(UUID userId) {
        return new Result(
                Notification.deleteForUser(userId), NotificationPreference.deleteForUser(userId));
    }
}
