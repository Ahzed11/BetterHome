package com.betterhome.tasks.membership;

import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Boundary to the households service for membership and eligibility checks. Tasks never read the
 * households database directly.
 */
public interface MembershipGateway {

    record MemberView(
            UUID userId, UUID authSubject, boolean admin, boolean away, long membershipOrder) {}

    record HouseholdSettings(String timezone, int reminderDaysBefore, LocalTime reminderTime) {}

    Optional<MemberView> findByAuthSubject(UUID householdId, UUID authSubject);

    /** Active, not-away members in stable membership order (for round robin). */
    List<UUID> listEligibleAssigneeIds(UUID householdId);

    /** Active members including those marked away (for nobody_available assignee fallback). */
    List<UUID> listActiveMemberIds(UUID householdId);

    HouseholdSettings householdSettings(UUID householdId);
}
