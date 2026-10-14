package com.betterhome.lists.service;

import com.betterhome.common.Clock;
import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ChecklistItem;
import com.betterhome.lists.domain.ListException;
import com.betterhome.lists.membership.MembershipGateway.MemberView;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.UUID;

/**
 * Items of a list: any active member adds, edits, checks, unchecks, deletes and resets. Items of an
 * archived list cannot change.
 */
@ApplicationScoped
public class ItemService {

    private final CallerService callerService;
    private final Clock clock;

    @Inject
    public ItemService(CallerService callerService, Clock clock) {
        this.callerService = callerService;
        this.clock = clock;
    }

    /** Live items in position order; readable even when the list is archived. */
    public List<ChecklistItem> list(UUID householdId, UUID listId) {
        callerService.requireMember(householdId);
        Checklist list = find(householdId, listId);
        return ChecklistItem.listLive(list.id);
    }

    @Transactional
    public ChecklistItem add(UUID householdId, UUID listId, String title) {
        MemberView member = callerService.requireMember(householdId);
        Checklist list =
                Checklist.lockInHousehold(householdId, listId)
                        .orElseThrow(() -> new ListException.NotFound("List not found"));
        list.requireActive();
        ChecklistItem item =
                ChecklistItem.create(
                        list.id,
                        title,
                        ChecklistItem.nextPosition(list.id),
                        member.userId(),
                        clock.now());
        item.persist();
        return item;
    }

    @Transactional
    public ChecklistItem rename(UUID householdId, UUID listId, UUID itemId, String title) {
        callerService.requireMember(householdId);
        ChecklistItem item = findLiveItemOfActiveList(householdId, listId, itemId);
        item.rename(title, clock.now());
        return item;
    }

    @Transactional
    public ChecklistItem check(UUID householdId, UUID listId, UUID itemId) {
        MemberView member = callerService.requireMember(householdId);
        ChecklistItem item = findLiveItemOfActiveList(householdId, listId, itemId);
        item.check(member.userId(), clock.now());
        return item;
    }

    @Transactional
    public ChecklistItem uncheck(UUID householdId, UUID listId, UUID itemId) {
        callerService.requireMember(householdId);
        ChecklistItem item = findLiveItemOfActiveList(householdId, listId, itemId);
        item.uncheck(clock.now());
        return item;
    }

    @Transactional
    public void delete(UUID householdId, UUID listId, UUID itemId) {
        MemberView member = callerService.requireMember(householdId);
        ChecklistItem item = findLiveItemOfActiveList(householdId, listId, itemId);
        item.softDelete(member.userId(), clock.now());
    }

    /** Unchecks every live item of the list in one transaction and returns the list's items. */
    @Transactional
    public List<ChecklistItem> reset(UUID householdId, UUID listId) {
        callerService.requireMember(householdId);
        Checklist list = find(householdId, listId);
        list.requireActive();
        ChecklistItem.uncheckAll(list.id, clock.now());
        return ChecklistItem.listLive(list.id);
    }

    private static Checklist find(UUID householdId, UUID listId) {
        return Checklist.findInHousehold(householdId, listId)
                .orElseThrow(() -> new ListException.NotFound("List not found"));
    }

    private static ChecklistItem findLiveItemOfActiveList(
            UUID householdId, UUID listId, UUID itemId) {
        Checklist list = find(householdId, listId);
        list.requireActive();
        return ChecklistItem.findLive(list.id, itemId)
                .orElseThrow(() -> new ListException.NotFound("Item not found"));
    }
}
