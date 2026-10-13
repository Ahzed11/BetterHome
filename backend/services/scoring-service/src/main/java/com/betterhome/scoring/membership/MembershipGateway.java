package com.betterhome.scoring.membership;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Boundary to the households service for membership checks. Scoring never reads the households
 * database directly.
 */
public interface MembershipGateway {

    record MemberView(
            UUID userId, UUID authSubject, boolean admin, boolean away, long membershipOrder) {}

    Optional<MemberView> findByAuthSubject(UUID householdId, UUID authSubject);

    List<MemberView> listActiveMembers(UUID householdId);
}
