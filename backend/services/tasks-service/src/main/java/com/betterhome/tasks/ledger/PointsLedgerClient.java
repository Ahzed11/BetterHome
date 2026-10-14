package com.betterhome.tasks.ledger;

import java.util.UUID;

/**
 * Boundary to the scoring service for ledger writes. Tasks never write the scoring database
 * directly. Failures surface as {@code TaskException.ServiceUnavailable} so the surrounding task
 * transaction rolls back and no task is left done without its points.
 */
public interface PointsLedgerClient {

    /**
     * Appends the award for one completion of a task. {@code completionNo} is the idempotency key:
     * repeating a call with the same task and number never awards twice.
     */
    void award(
            UUID householdId, UUID userId, UUID taskId, int completionNo, int points, boolean late);

    void reverse(
            UUID householdId,
            UUID taskId,
            UUID assigneeUserId,
            int points,
            UUID adminUserId,
            String reason,
            String resultingStatus);
}
