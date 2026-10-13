package com.betterhome.tasks.membership;

import jakarta.enterprise.context.ApplicationScoped;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-process membership directory for Phase 2 (dev/test and local runs). An HTTP client against
 * households-service replaces this in a later task.
 */
@ApplicationScoped
public class InMemoryMembershipGateway implements MembershipGateway {

    private final Map<UUID, List<MemberView>> byHousehold = new ConcurrentHashMap<>();

    public void replaceHouseholdMembers(UUID householdId, List<MemberView> members) {
        byHousehold.put(householdId, new ArrayList<>(members));
    }

    public void clear() {
        byHousehold.clear();
    }

    @Override
    public Optional<MemberView> findByAuthSubject(UUID householdId, UUID authSubject) {
        return byHousehold.getOrDefault(householdId, List.of()).stream()
                .filter(m -> m.authSubject().equals(authSubject))
                .findFirst();
    }

    @Override
    public List<UUID> listEligibleAssigneeIds(UUID householdId) {
        return byHousehold.getOrDefault(householdId, List.of()).stream()
                .filter(m -> !m.away())
                .sorted(Comparator.comparingLong(MemberView::membershipOrder))
                .map(MemberView::userId)
                .toList();
    }
}
