package com.betterhome.households.service;

import com.betterhome.common.Clock;
import com.betterhome.households.domain.AccountDeletion;
import com.betterhome.households.domain.AppUser;
import com.betterhome.households.domain.Household;
import com.betterhome.households.domain.HouseholdException;
import com.betterhome.households.domain.Invitation;
import com.betterhome.households.domain.Membership;
import com.betterhome.households.domain.MembershipRole;
import com.betterhome.households.domain.NotificationOutbox;
import com.betterhome.households.erasure.AccountDeletionProcessor;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Account deletion (spec §9). The local part happens in one transaction: the last-admin rule is
 * checked, the user leaves every household, the profile is anonymized and the remaining work is
 * recorded. Telling the other services and the identity provider is then attempted at once and, for
 * whatever fails, retried by {@code AccountDeletionScheduler}.
 */
@ApplicationScoped
public class AccountDeletionService {

    private final CurrentUserService currentUserService;
    private final AccountDeletionProcessor processor;
    private final Clock clock;

    @Inject
    public AccountDeletionService(
            CurrentUserService currentUserService,
            AccountDeletionProcessor processor,
            Clock clock) {
        this.currentUserService = currentUserService;
        this.processor = processor;
        this.clock = clock;
    }

    /**
     * Deletes the caller's account. Asking again for an account already deleted only nudges the
     * pending work.
     *
     * @throws HouseholdException.Conflict when the caller is the only admin of a household that has
     *     other members
     */
    public void deleteMyAccount() {
        UUID subject = currentUserService.requireAuthSubject();
        UUID userId = QuarkusTransaction.requiringNew().call(() -> deleteLocally(subject));
        processor.process(userId);
    }

    private UUID deleteLocally(UUID subject) {
        Optional<AppUser> alreadyDeleted = AppUser.findDeletedByAuthSubject(subject);
        if (alreadyDeleted.isPresent()) {
            return alreadyDeleted.get().id;
        }
        AppUser user =
                AppUser.findByAuthSubject(subject)
                        .orElseThrow(
                                () ->
                                        new HouseholdException.NotFound(
                                                "User profile not synced; call PUT /v1/me first"));
        Instant now = clock.now();
        List<Household> households = households(user);
        for (Membership membership : Membership.listActiveForUser(user.id)) {
            membership.leave(now);
        }
        for (Household household : households) {
            household.deletedAt = now;
            household.updatedAt = now;
        }
        NotificationOutbox.deleteForUser(user.id);
        Invitation.deletePendingFor(user.email);
        Invitation.forgetAcceptedFor(user.email);
        user.anonymize(now);
        AccountDeletion.request(user.id, now).persist();
        return user.id;
    }

    /**
     * The households that go with the user: those where they are the only member (the only admin
     * necessarily, so the spec's "delete the household" is what is left to do).
     *
     * @throws HouseholdException.Conflict when they are the only admin of a household with others
     */
    private static List<Household> households(AppUser user) {
        List<Household> toDelete = new ArrayList<>();
        int blocking = 0;
        for (Membership membership : Membership.listActiveForUser(user.id)) {
            if (membership.role != MembershipRole.admin
                    || Membership.countActiveAdmins(membership.householdId) > 1) {
                continue;
            }
            if (Membership.countActive(membership.householdId) > 1) {
                blocking++;
            } else {
                Household.findActiveById(membership.householdId).ifPresent(toDelete::add);
            }
        }
        if (blocking > 0) {
            throw new HouseholdException.Conflict(
                    "You are the only admin of "
                            + blocking
                            + " household(s) that have other members; make another member an admin"
                            + " or delete the household before deleting your account");
        }
        return toDelete;
    }
}
