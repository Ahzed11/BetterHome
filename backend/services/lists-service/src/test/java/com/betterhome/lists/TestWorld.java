package com.betterhome.lists;

import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ChecklistItem;
import com.betterhome.lists.membership.InMemoryMembershipGateway;
import com.betterhome.lists.membership.MembershipGateway.MemberView;
import io.quarkus.security.identity.CurrentIdentityAssociation;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;

/**
 * Two households with known members, plus helpers to seed rows and to run code as a given caller.
 */
@ApplicationScoped
public class TestWorld {

    public static final UUID HOUSEHOLD = UUID.fromString("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
    public static final UUID OTHER_HOUSEHOLD =
            UUID.fromString("99999999-bbbb-cccc-dddd-eeeeeeeeeeee");

    public static final String ADMIN_SUBJECT = "11111111-1111-1111-1111-111111111111";
    public static final String MEMBER_SUBJECT = "22222222-2222-2222-2222-222222222222";
    public static final String OTHER_ADMIN_SUBJECT = "33333333-3333-3333-3333-333333333333";

    /** Used to be a member of {@link #HOUSEHOLD}; households-service no longer lists them. */
    public static final String LEFT_SUBJECT = "44444444-4444-4444-4444-444444444444";

    public static final UUID ADMIN_USER = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    public static final UUID MEMBER_USER = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
    public static final UUID OTHER_ADMIN_USER =
            UUID.fromString("cccccccc-cccc-cccc-cccc-cccccccccccc");

    @Inject InMemoryMembershipGateway gateway;
    @Inject CurrentIdentityAssociation identityAssociation;

    /** Resets the directory to the two households and removes every list and item. */
    @Transactional
    public void reset() {
        gateway.clear();
        gateway.setUnavailable(false);
        gateway.replaceHouseholdMembers(
                HOUSEHOLD,
                List.of(
                        new MemberView(ADMIN_USER, UUID.fromString(ADMIN_SUBJECT), true),
                        new MemberView(MEMBER_USER, UUID.fromString(MEMBER_SUBJECT), false)));
        gateway.replaceHouseholdMembers(
                OTHER_HOUSEHOLD,
                List.of(
                        new MemberView(
                                OTHER_ADMIN_USER, UUID.fromString(OTHER_ADMIN_SUBJECT), true)));
        ChecklistItem.deleteAll();
        Checklist.deleteAll();
    }

    @Transactional
    public Checklist seedList(UUID householdId, String title, Instant createdAt) {
        Checklist list = Checklist.create(householdId, title, ADMIN_USER, createdAt);
        list.persist();
        return list;
    }

    @Transactional
    public ChecklistItem seedItem(UUID listId, String title, int position, Instant createdAt) {
        ChecklistItem item = ChecklistItem.create(listId, title, position, MEMBER_USER, createdAt);
        item.persist();
        return item;
    }

    @Transactional
    public void archive(UUID listId, Instant at) {
        Checklist list = Checklist.findById(listId);
        list.archive(at);
    }

    @Transactional
    public Checklist reload(UUID listId) {
        return Checklist.findById(listId);
    }

    @Transactional
    public ChecklistItem reloadItem(UUID itemId) {
        return ChecklistItem.findById(itemId);
    }

    public <T> T asUser(String authSubject, Supplier<T> action) {
        SecurityIdentity previous = identityAssociation.getIdentity();
        identityAssociation.setIdentity(
                QuarkusSecurityIdentity.builder().setPrincipal(() -> authSubject).build());
        try {
            return action.get();
        } finally {
            identityAssociation.setIdentity(
                    previous != null
                            ? previous
                            : QuarkusSecurityIdentity.builder().setAnonymous(true).build());
        }
    }

    public void runAs(String authSubject, Runnable action) {
        asUser(
                authSubject,
                () -> {
                    action.run();
                    return null;
                });
    }
}
