package com.betterhome.tasks.membership;

import jakarta.enterprise.context.ApplicationScoped;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-process membership directory for local/dev tests. An HTTP client against households-service
 * replaces this in T-0008.
 */
@ApplicationScoped
public class InMemoryMembershipGateway implements MembershipGateway {

    private final Map<UUID, List<MemberView>> byHousehold = new ConcurrentHashMap<>();
    private final Map<UUID, HouseholdSettings> settingsByHousehold = new ConcurrentHashMap<>();

    public void replaceHouseholdMembers(UUID householdId, List<MemberView> members) {
        byHousehold.put(householdId, new ArrayList<>(members));
        settingsByHousehold.putIfAbsent(
                householdId, new HouseholdSettings("UTC", 0, LocalTime.of(8, 0)));
    }

    public void putSettings(UUID householdId, HouseholdSettings settings) {
        settingsByHousehold.put(householdId, settings);
    }

    public void clear() {
        byHousehold.clear();
        settingsByHousehold.clear();
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

    @Override
    public List<UUID> listActiveMemberIds(UUID householdId) {
        return byHousehold.getOrDefault(householdId, List.of()).stream()
                .sorted(Comparator.comparingLong(MemberView::membershipOrder))
                .map(MemberView::userId)
                .toList();
    }

    @Override
    public HouseholdSettings householdSettings(UUID householdId) {
        return settingsByHousehold.getOrDefault(
                householdId, new HouseholdSettings("UTC", 0, LocalTime.of(8, 0)));
    }
}
