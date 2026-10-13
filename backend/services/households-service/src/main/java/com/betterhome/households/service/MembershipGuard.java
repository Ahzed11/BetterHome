package com.betterhome.households.service;

import com.betterhome.households.domain.Household;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.UUID;

@ApplicationScoped
public class MembershipGuard {

    public Household requireActiveHousehold(UUID householdId) {
        return Household.findActiveById(householdId)
                .orElseThrow(() -> new HouseholdException.NotFound("Household not found"));
    }

    public Membership requireActiveMember(UUID householdId, UUID userId) {
        requireActiveHousehold(householdId);
        return Membership.findActive(householdId, userId)
                .orElseThrow(
                        () -> new HouseholdException.Forbidden("Not an active household member"));
    }

    public Membership requireAdmin(UUID householdId, UUID userId) {
        Membership membership = requireActiveMember(householdId, userId);
        if (membership.role != MembershipRole.admin) {
            throw new HouseholdException.Forbidden("Admin role required");
        }
        return membership;
    }
}
