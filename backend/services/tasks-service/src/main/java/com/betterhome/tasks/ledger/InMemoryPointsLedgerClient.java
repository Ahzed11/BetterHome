package com.betterhome.tasks.ledger;

import jakarta.enterprise.context.ApplicationScoped;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-process ledger mirror for Phase 3 (dev/test). Replaced by an HTTP client against
 * scoring-service when service-to-service auth is wired.
 */
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

    public void clear() {
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
