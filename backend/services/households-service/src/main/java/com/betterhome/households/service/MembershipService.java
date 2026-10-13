package com.betterhome.households.service;

import com.betterhome.common.Clock;
import com.betterhome.households.domain.AppUser;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class MembershipService {

    private final CurrentUserService currentUserService;
    private final MembershipGuard membershipGuard;
    private final Clock clock;
    private final AwayTaskDismissal awayTaskDismissal;

    @Inject
    public MembershipService(
            CurrentUserService currentUserService,
            MembershipGuard membershipGuard,
            Clock clock,
            AwayTaskDismissal awayTaskDismissal) {
        this.currentUserService = currentUserService;
        this.membershipGuard = membershipGuard;
        this.clock = clock;
        this.awayTaskDismissal = awayTaskDismissal;
    }

    public List<Membership> list(UUID householdId) {
        AppUser user = currentUserService.requireCurrentUser();
        membershipGuard.requireActiveMember(householdId, user.id);
        return Membership.listActiveForHousehold(householdId);
    }

    @Transactional
    public Membership changeRole(UUID householdId, UUID targetUserId, MembershipRole newRole) {
        AppUser actor = currentUserService.requireCurrentUser();
        membershipGuard.requireAdmin(householdId, actor.id);
        Membership target = membershipGuard.requireActiveMember(householdId, targetUserId);
        if (target.role == MembershipRole.admin
                && newRole == MembershipRole.member
                && Membership.countActiveAdmins(householdId) <= 1) {
            throw new HouseholdException.Conflict(
                    "Cannot demote the last admin; promote another member or delete the household");
        }
        target.role = newRole;
        return target;
    }

    @Transactional
    public void leave(UUID householdId) {
        AppUser user = currentUserService.requireCurrentUser();
        Membership membership = membershipGuard.requireActiveMember(householdId, user.id);
        if (membership.role == MembershipRole.admin
                && Membership.countActiveAdmins(householdId) <= 1) {
            throw new HouseholdException.Conflict(
                    "Last admin must promote someone else or delete the household before leaving");
        }
        membership.leftAt = clock.now();
        clearAwayFields(membership);
    }

    @Transactional
    public Membership setAway(
            UUID householdId, UUID targetUserId, Instant awayFrom, Instant awayUntil) {
        AppUser actor = currentUserService.requireCurrentUser();
        membershipGuard.requireAdmin(householdId, actor.id);
        Membership target = membershipGuard.requireActiveMember(householdId, targetUserId);
        Instant from = awayFrom == null ? clock.now() : awayFrom;
        if (awayUntil != null && awayUntil.isBefore(from)) {
            throw new HouseholdException.BadRequest("awayUntil must be >= awayFrom");
        }
        target.awayFrom = from;
        target.awayUntil = awayUntil;
        target.awaySetBy = actor.id;
        if (!from.isAfter(clock.now())) {
            awayTaskDismissal.dismissOpenTasks(householdId, targetUserId);
        }
        return target;
    }

    @Transactional
    public Membership clearAway(UUID householdId, UUID targetUserId) {
        AppUser actor = currentUserService.requireCurrentUser();
        membershipGuard.requireAdmin(householdId, actor.id);
        Membership target = membershipGuard.requireActiveMember(householdId, targetUserId);
        clearAwayFields(target);
        return target;
    }

    private static void clearAwayFields(Membership membership) {
        membership.awayFrom = null;
        membership.awayUntil = null;
        membership.awaySetBy = null;
    }
}
