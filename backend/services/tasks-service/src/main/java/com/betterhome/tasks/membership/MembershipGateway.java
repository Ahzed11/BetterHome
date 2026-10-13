package com.betterhome.tasks.membership;

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

    Optional<MemberView> findByAuthSubject(UUID householdId, UUID authSubject);

    /** Active, not-away members in stable membership order (for round robin). */
    List<UUID> listEligibleAssigneeIds(UUID householdId);
}
