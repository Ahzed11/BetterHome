package com.betterhome.lists.membership;

import com.betterhome.lists.domain.ListException;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-process membership directory that stands in for {@link HttpMembershipGateway} in Quarkus
 * tests. Members who left are simply absent, as in households-service's answer.
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

    /** Simulates households-service being down. */
    public void setUnavailable(boolean unavailable) {
        this.unavailable = unavailable;
    }

    public void clear() {
        byHousehold.clear();
    }

    @Override
    public Optional<MemberView> findByAuthSubject(UUID householdId, UUID authSubject) {
        if (unavailable) {
            throw new ListException.ServiceUnavailable("households-service is unreachable");
        }
        return byHousehold.getOrDefault(householdId, List.of()).stream()
                .filter(m -> m.authSubject().equals(authSubject))
                .findFirst();
    }
}
