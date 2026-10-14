package com.betterhome.scoring.membership;

import java.time.ZoneId;
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

    /**
     * The household's timezone, in which scoreboard periods and months are cut. UTC when
     * households-service does not know the household or holds no valid zone.
     */
    ZoneId householdZone(UUID householdId);
}
