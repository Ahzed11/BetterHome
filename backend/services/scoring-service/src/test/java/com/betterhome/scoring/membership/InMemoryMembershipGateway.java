package com.betterhome.scoring.membership;

import com.betterhome.scoring.domain.ScoringException;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-process membership directory that stands in for {@link HttpMembershipGateway} in Quarkus
 * tests, so domain tests do not need a households server.
 */
@Alternative
@Priority(1)
@ApplicationScoped
public class InMemoryMembershipGateway implements MembershipGateway {

    private final Map<UUID, List<MemberView>> byHousehold = new ConcurrentHashMap<>();
    private volatile boolean unavailable;

    public void replaceHouseholdMembers(UUID householdId, List<MemberView> members) {
        byHousehold.put(householdId, new ArrayList<>(members));
    }

    /** Makes every following lookup fail as an unreachable households-service would. */
    public void setUnavailable(boolean unavailable) {
        this.unavailable = unavailable;
    }

    public void clear() {
        unavailable = false;
        byHousehold.clear();
    }

    @Override
    public Optional<MemberView> findByAuthSubject(UUID householdId, UUID authSubject) {
        requireAvailable();
        return byHousehold.getOrDefault(householdId, List.of()).stream()
                .filter(m -> m.authSubject().equals(authSubject))
                .findFirst();
    }

    @Override
    public List<MemberView> listActiveMembers(UUID householdId) {
        requireAvailable();
        return byHousehold.getOrDefault(householdId, List.of()).stream()
                .sorted(Comparator.comparingLong(MemberView::membershipOrder))
                .toList();
    }

    private void requireAvailable() {
        if (unavailable) {
            throw new ScoringException.ServiceUnavailable("households-service is unreachable");
        }
    }
}
