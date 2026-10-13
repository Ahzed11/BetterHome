package com.betterhome.tasks.ledger;

import java.util.UUID;

/**
 * Boundary to the scoring service for ledger writes. Tasks never write the scoring database
 * directly. Phase 3 uses an in-process implementation; HTTP client follows in a later task.
 */
public interface PointsLedgerClient {

    void award(UUID householdId, UUID userId, UUID taskId, int points, boolean late);

    void reverse(
            UUID householdId,
            UUID taskId,
            UUID assigneeUserId,
            int points,
            UUID adminUserId,
            String reason,
            String resultingStatus);
}
