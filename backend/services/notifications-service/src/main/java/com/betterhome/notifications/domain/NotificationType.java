package com.betterhome.notifications.domain;

import java.util.List;
import java.util.Optional;

/**
 * Notification types of spec §5. Each type lists the payload keys its message text needs, so a
 * producer cannot send an event that would render with a hole in it.
 */
public enum NotificationType {
    task_assigned("taskTitle"),
    task_reassigned("taskTitle"),
    due_reminder("taskTitle"),
    overdue("taskTitle"),
    dismissed("taskTitle"),
    superseded("taskTitle"),
    reverted("taskTitle"),
    marked_away(),
    invitation("householdName");

    private final List<String> requiredPayloadKeys;

    NotificationType(String... requiredPayloadKeys) {
        this.requiredPayloadKeys = List.of(requiredPayloadKeys);
    }

    public List<String> requiredPayloadKeys() {
        return requiredPayloadKeys;
    }

    public static Optional<NotificationType> parse(String value) {
        for (NotificationType type : values()) {
            if (type.name().equals(value)) {
                return Optional.of(type);
            }
        }
        return Optional.empty();
    }
}
