package com.betterhome.lists.service;

import com.betterhome.common.Clock;
import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ListException;
import com.betterhome.lists.membership.MembershipGateway.MemberView;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.UUID;

/** Lists of a household: any member reads, only admins create, rename and archive. */
@ApplicationScoped
public class ChecklistService {

    private final CallerService callerService;
    private final Clock clock;

    @Inject
    public ChecklistService(CallerService callerService, Clock clock) {
        this.callerService = callerService;
        this.clock = clock;
    }

    /** Archived lists are left out unless {@code includeArchived} is set. */
    public List<Checklist> list(UUID householdId, boolean includeArchived) {
        callerService.requireMember(householdId);
        return Checklist.listForHousehold(householdId, includeArchived);
    }

    @Transactional
    public Checklist create(UUID householdId, String title) {
        MemberView admin = callerService.requireAdmin(householdId);
        Checklist list = Checklist.create(householdId, title, admin.userId(), clock.now());
        list.persist();
        return list;
    }

    @Transactional
    public Checklist rename(UUID householdId, UUID listId, String title) {
        callerService.requireAdmin(householdId);
        Checklist list = find(householdId, listId);
        list.rename(title, clock.now());
        return list;
    }

    @Transactional
    public Checklist archive(UUID householdId, UUID listId) {
        callerService.requireAdmin(householdId);
        Checklist list = find(householdId, listId);
        list.archive(clock.now());
        return list;
    }

    private static Checklist find(UUID householdId, UUID listId) {
        return Checklist.findInHousehold(householdId, listId)
                .orElseThrow(() -> new ListException.NotFound("List not found"));
    }
}
