package com.betterhome.households.service;

import com.betterhome.common.Clock;
import com.betterhome.households.domain.AppUser;
import com.betterhome.households.domain.Household;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class HouseholdService {

    private final CurrentUserService currentUserService;
    private final MembershipGuard membershipGuard;
    private final Clock clock;

    @Inject
    public HouseholdService(
            CurrentUserService currentUserService, MembershipGuard membershipGuard, Clock clock) {
        this.currentUserService = currentUserService;
        this.membershipGuard = membershipGuard;
        this.clock = clock;
    }

    @Transactional
    public Household create(String name, String timezone) {
        AppUser creator = currentUserService.requireCurrentUser();
        Instant now = clock.now();
        if (name == null || name.isBlank()) {
            throw new HouseholdException.BadRequest("name is required");
        }
        if (timezone == null || timezone.isBlank()) {
            throw new HouseholdException.BadRequest("timezone is required");
        }

        Household household = new Household();
        household.id = UUID.randomUUID();
        household.name = name.trim();
        household.timezone = timezone.trim();
        household.reminderDaysBefore = 0;
        household.reminderTime = LocalTime.of(8, 0);
        household.createdBy = creator.id;
        household.createdAt = now;
        household.updatedAt = now;
        household.persist();

        Membership membership = new Membership();
        membership.id = UUID.randomUUID();
        membership.userId = creator.id;
        membership.householdId = household.id;
        membership.role = MembershipRole.admin;
        membership.joinedAt = now;
        membership.persist();

        return household;
    }

    public List<Household> listMine() {
        AppUser user = currentUserService.requireCurrentUser();
        return Membership.listActiveForUser(user.id).stream()
                .map(m -> Household.findActiveById(m.householdId))
                .flatMap(java.util.Optional::stream)
                .toList();
    }

    public Household get(UUID householdId) {
        AppUser user = currentUserService.requireCurrentUser();
        membershipGuard.requireActiveMember(householdId, user.id);
        return membershipGuard.requireActiveHousehold(householdId);
    }

    @Transactional
    public Household update(
            UUID householdId,
            String name,
            String timezone,
            Integer reminderDaysBefore,
            LocalTime reminderTime) {
        AppUser user = currentUserService.requireCurrentUser();
        membershipGuard.requireAdmin(householdId, user.id);
        Household household = membershipGuard.requireActiveHousehold(householdId);
        if (name != null) {
            if (name.isBlank()) {
                throw new HouseholdException.BadRequest("name must not be blank");
            }
            household.name = name.trim();
        }
        if (timezone != null) {
            if (timezone.isBlank()) {
                throw new HouseholdException.BadRequest("timezone must not be blank");
            }
            household.timezone = timezone.trim();
        }
        if (reminderDaysBefore != null) {
            if (reminderDaysBefore < 0) {
                throw new HouseholdException.BadRequest("reminderDaysBefore must be >= 0");
            }
            household.reminderDaysBefore = reminderDaysBefore;
        }
        if (reminderTime != null) {
            household.reminderTime = reminderTime;
        }
        household.updatedAt = clock.now();
        return household;
    }

    @Transactional
    public void delete(UUID householdId) {
        AppUser user = currentUserService.requireCurrentUser();
        membershipGuard.requireAdmin(householdId, user.id);
        Household household = membershipGuard.requireActiveHousehold(householdId);
        Instant now = clock.now();
        household.deletedAt = now;
        household.updatedAt = now;
        for (Membership membership : Membership.listActiveForHousehold(householdId)) {
            membership.leftAt = now;
        }
    }
}
