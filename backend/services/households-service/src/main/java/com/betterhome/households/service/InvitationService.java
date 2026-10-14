package com.betterhome.households.service;

import com.betterhome.common.Clock;
import com.betterhome.households.domain.AppUser;
import com.betterhome.households.domain.Household;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Invitation;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

@ApplicationScoped
public class InvitationService {

    static final Duration DEFAULT_TTL = Duration.ofDays(7);

    private final CurrentUserService currentUserService;
    private final MembershipGuard membershipGuard;
    private final Clock clock;
    private final OutboxService outboxService;

    @Inject
    public InvitationService(
            CurrentUserService currentUserService,
            MembershipGuard membershipGuard,
            Clock clock,
            OutboxService outboxService) {
        this.currentUserService = currentUserService;
        this.membershipGuard = membershipGuard;
        this.clock = clock;
        this.outboxService = outboxService;
    }

    @Transactional
    public Invitation create(UUID householdId, String email, MembershipRole role) {
        AppUser actor = currentUserService.requireCurrentUser();
        membershipGuard.requireAdmin(householdId, actor.id);
        membershipGuard.requireActiveHousehold(householdId);
        if (role == null) {
            throw new HouseholdException.BadRequest("role is required");
        }
        String normalizedEmail = normalizeEmail(email);
        Instant now = clock.now();

        Invitation invitation = new Invitation();
        invitation.id = UUID.randomUUID();
        invitation.householdId = householdId;
        invitation.email = normalizedEmail;
        invitation.role = role;
        invitation.token = UUID.randomUUID().toString();
        invitation.expiresAt = now.plus(DEFAULT_TTL);
        invitation.createdBy = actor.id;
        invitation.createdAt = now;
        invitation.persist();
        notifyInvitee(invitation);
        return invitation;
    }

    /**
     * Tells the invited person when they already have an account; others have no push to receive.
     */
    private void notifyInvitee(Invitation invitation) {
        AppUser.findActiveByEmail(invitation.email)
                .ifPresent(
                        invitee ->
                                outboxService.enqueue(
                                        invitation.householdId,
                                        invitee.id,
                                        "invitation",
                                        Map.of(
                                                "householdName",
                                                Household.<Household>findById(
                                                                invitation.householdId)
                                                        .name)));
    }

    public List<Invitation> listPending(UUID householdId) {
        AppUser actor = currentUserService.requireCurrentUser();
        membershipGuard.requireAdmin(householdId, actor.id);
        return Invitation.listPendingForHousehold(householdId, clock.now());
    }

    @Transactional
    public Membership accept(String token) {
        AppUser user = currentUserService.requireCurrentUser();
        Invitation invitation =
                Invitation.findByToken(token)
                        .orElseThrow(() -> new HouseholdException.NotFound("Invitation not found"));
        Instant now = clock.now();
        if (invitation.acceptedAt != null) {
            throw new HouseholdException.Conflict("Invitation already accepted");
        }
        if (!invitation.expiresAt.isAfter(now)) {
            throw new HouseholdException.Conflict("Invitation expired");
        }
        if (!invitation.email.equalsIgnoreCase(user.email)) {
            throw new HouseholdException.Forbidden(
                    "Invitation email does not match the authenticated user");
        }
        membershipGuard.requireActiveHousehold(invitation.householdId);
        if (Membership.findActive(invitation.householdId, user.id).isPresent()) {
            throw new HouseholdException.Conflict("Already an active member of this household");
        }

        Membership membership = new Membership();
        membership.id = UUID.randomUUID();
        membership.userId = user.id;
        membership.householdId = invitation.householdId;
        membership.role = invitation.role;
        membership.joinedAt = now;
        membership.persist();

        invitation.acceptedAt = now;
        return membership;
    }

    private static String normalizeEmail(String email) {
        if (email == null || email.isBlank()) {
            throw new HouseholdException.BadRequest("email is required");
        }
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
