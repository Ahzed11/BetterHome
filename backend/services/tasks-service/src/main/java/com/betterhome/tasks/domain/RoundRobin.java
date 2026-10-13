package com.betterhome.tasks.domain;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** Pure round-robin selection among eligible member user IDs (stable order). */
public final class RoundRobin {

    private RoundRobin() {}

    /**
     * @param eligibleUserIds ordered eligible assignees (active, not away)
     * @param lastAssignedUserId rotation cursor; may be null
     * @return next assignee after the cursor, or empty if nobody eligible
     */
    public static Optional<UUID> next(List<UUID> eligibleUserIds, UUID lastAssignedUserId) {
        if (eligibleUserIds == null || eligibleUserIds.isEmpty()) {
            return Optional.empty();
        }
        if (lastAssignedUserId == null) {
            return Optional.of(eligibleUserIds.getFirst());
        }
        int index = eligibleUserIds.indexOf(lastAssignedUserId);
        if (index < 0) {
            return Optional.of(eligibleUserIds.getFirst());
        }
        int nextIndex = (index + 1) % eligibleUserIds.size();
        return Optional.of(eligibleUserIds.get(nextIndex));
    }
}
