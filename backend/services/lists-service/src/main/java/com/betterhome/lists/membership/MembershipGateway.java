package com.betterhome.lists.membership;

import java.util.Optional;
import java.util.UUID;

/**
 * Boundary to the households service for membership and role checks. Lists never read the
 * households database directly.
 */
public interface MembershipGateway {

    record MemberView(UUID userId, UUID authSubject, boolean admin) {}

    /**
     * Finds the active member of a household by Keycloak subject.
     *
     * @return the member, or empty for strangers, members who left and unknown households
     * @throws com.betterhome.lists.domain.ListException.ServiceUnavailable when households-service
     *     cannot answer
     */
    Optional<MemberView> findByAuthSubject(UUID householdId, UUID authSubject);
}
