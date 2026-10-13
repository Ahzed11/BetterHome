package com.betterhome.households.service;

import com.betterhome.common.Clock;
import com.betterhome.households.api.InternalDtos.InternalMemberResponse;
import com.betterhome.households.api.InternalDtos.InternalSettingsResponse;
import com.betterhome.households.domain.AppUser;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Membership;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Household facts for other BetterHome services. Callers are service accounts, not household
 * members, so nothing here is checked against the current user.
 */
@ApplicationScoped
public class InternalHouseholdService {

    private final MembershipGuard membershipGuard;
    private final Clock clock;

    @Inject
    public InternalHouseholdService(MembershipGuard membershipGuard, Clock clock) {
        this.membershipGuard = membershipGuard;
        this.clock = clock;
    }

    /** Active members in stable joining order, with away resolved at the current instant. */
    public List<InternalMemberResponse> listMembers(UUID householdId) {
        membershipGuard.requireActiveHousehold(householdId);
        Instant now = clock.now();
        return Membership.listActiveForHousehold(householdId).stream()
                .map(
                        membership ->
                                new InternalMemberResponse(
                                        membership.userId,
                                        authSubjectOf(membership),
                                        membership.role,
                                        membership.isAway(now),
                                        membership.joinedAt))
                .toList();
    }

    public InternalSettingsResponse settings(UUID householdId) {
        return InternalSettingsResponse.from(membershipGuard.requireActiveHousehold(householdId));
    }

    private static UUID authSubjectOf(Membership membership) {
        return AppUser.<AppUser>findByIdOptional(membership.userId)
                .map(user -> user.authSubject)
                .orElseThrow(() -> new HouseholdException.NotFound("Member profile not found"));
    }
}
