package com.betterhome.tasks.ledger;

import com.betterhome.tasks.domain.TaskException;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-process ledger that stands in for {@link HttpPointsLedgerClient} in Quarkus tests, so domain
 * tests do not need a scoring server.
 */
@Alternative
@Priority(1)
@ApplicationScoped
public class InMemoryPointsLedgerClient implements PointsLedgerClient {

    public record AwardRecord(
            UUID householdId, UUID userId, UUID taskId, int points, boolean late) {}

    public record ReverseRecord(
            UUID householdId,
            UUID taskId,
            UUID assigneeUserId,
            int points,
            UUID adminUserId,
            String reason,
            String resultingStatus) {}

    private final List<AwardRecord> awards = Collections.synchronizedList(new ArrayList<>());
    private final List<ReverseRecord> reversals = Collections.synchronizedList(new ArrayList<>());
    private final Map<UUID, Integer> balances = new ConcurrentHashMap<>();

    private volatile boolean unavailable;

    /** Makes every following call fail as an unreachable scoring-service would. */
    public void setUnavailable(boolean unavailable) {
        this.unavailable = unavailable;
    }

    private void requireAvailable() {
        if (unavailable) {
            throw new TaskException.ServiceUnavailable("scoring-service is unreachable");
        }
    }

    public void clear() {
        unavailable = false;
        awards.clear();
        reversals.clear();
        balances.clear();
    }

    public List<AwardRecord> awards() {
        return List.copyOf(awards);
    }

    public List<ReverseRecord> reversals() {
        return List.copyOf(reversals);
    }

    public int balance(UUID userId) {
        return balances.getOrDefault(userId, 0);
    }

    @Override
    public void award(UUID householdId, UUID userId, UUID taskId, int points, boolean late) {
        requireAvailable();
        awards.add(new AwardRecord(householdId, userId, taskId, points, late));
        balances.merge(userId, points, Integer::sum);
    }

    @Override
    public void reverse(
            UUID householdId,
            UUID taskId,
            UUID assigneeUserId,
            int points,
            UUID adminUserId,
            String reason,
            String resultingStatus) {
        requireAvailable();
        reversals.add(
                new ReverseRecord(
                        householdId,
                        taskId,
                        assigneeUserId,
                        points,
                        adminUserId,
                        reason,
                        resultingStatus));
        balances.merge(assigneeUserId, -points, Integer::sum);
    }
}
