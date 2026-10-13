package com.betterhome.scoring.service;

import com.betterhome.common.Clock;
import com.betterhome.scoring.domain.PointReason;
import com.betterhome.scoring.domain.PointTransaction;
import com.betterhome.scoring.domain.ReversionResultingStatus;
import com.betterhome.scoring.domain.ScoringException;
import com.betterhome.scoring.domain.TaskReversion;
import com.betterhome.scoring.membership.MembershipGateway.MemberView;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.UUID;

@ApplicationScoped
public class LedgerService {

    private final CallerService callerService;
    private final Clock clock;

    @Inject
    public LedgerService(CallerService callerService, Clock clock) {
        this.callerService = callerService;
        this.clock = clock;
    }

    /**
     * Append a positive award for a completed task. Callable by any active member (tasks-service
     * invokes this after complete / quick-log under the acting user's token).
     */
    @Transactional
    public PointTransaction award(
            UUID householdId, UUID userId, UUID taskId, int points, PointReason reason) {
        callerService.requireMember(householdId);
        if (points <= 0) {
            throw new ScoringException.BadRequest("Awarded points must be positive");
        }
        if (reason != PointReason.task_completed && reason != PointReason.task_completed_late) {
            throw new ScoringException.BadRequest("Invalid award reason");
        }
        if (taskId == null) {
            throw new ScoringException.BadRequest("taskId is required for awards");
        }
        Instant now = clock.now();
        PointTransaction row = new PointTransaction();
        row.id = UUID.randomUUID();
        row.householdId = householdId;
        row.userId = userId;
        row.taskId = taskId;
        row.points = points;
        row.reason = reason;
        row.createdAt = now;
        row.persist();
        return row;
    }

    /**
     * Reverse points for a done task: creates {@link TaskReversion} and a negative ledger row in one
     * transaction. Admin only.
     */
    @Transactional
    public TaskReversion reverse(
            UUID householdId,
            UUID taskId,
            UUID assigneeUserId,
            int pointsToReverse,
            String reason,
            ReversionResultingStatus resultingStatus) {
        MemberView admin = callerService.requireAdmin(householdId);
        if (reason == null || reason.isBlank()) {
            throw new ScoringException.BadRequest("Reversion reason is required");
        }
        if (pointsToReverse <= 0) {
            throw new ScoringException.BadRequest("pointsToReverse must be positive");
        }
        if (resultingStatus == null) {
            throw new ScoringException.BadRequest("resultingStatus is required");
        }
        int netForTask = PointTransaction.sumAwardedForTask(householdId, taskId);
        if (netForTask < pointsToReverse) {
            throw new ScoringException.Conflict(
                    "Cannot reverse more points than remain on this task");
        }
        Instant now = clock.now();

        TaskReversion reversion = new TaskReversion();
        reversion.id = UUID.randomUUID();
        reversion.householdId = householdId;
        reversion.taskId = taskId;
        reversion.adminUserId = admin.userId();
        reversion.reason = reason.trim();
        reversion.pointsReversed = pointsToReverse;
        reversion.resultingStatus = resultingStatus;
        reversion.createdAt = now;
        reversion.persist();

        PointTransaction row = new PointTransaction();
        row.id = UUID.randomUUID();
        row.householdId = householdId;
        row.userId = assigneeUserId;
        row.taskId = taskId;
        row.reversionId = reversion.id;
        row.points = -pointsToReverse;
        row.reason = PointReason.reversal;
        row.createdAt = now;
        row.persist();
        return reversion;
    }

    /** Admin manual adjustment. Guarded so the member's all-time score never goes negative. */
    @Transactional
    public PointTransaction adjust(UUID householdId, UUID userId, int delta) {
        callerService.requireAdmin(householdId);
        if (delta == 0) {
            throw new ScoringException.BadRequest("Adjustment must be non-zero");
        }
        int current = PointTransaction.sumForUser(householdId, userId);
        if (current + delta < 0) {
            throw new ScoringException.Conflict("Scores never go negative");
        }
        Instant now = clock.now();
        PointTransaction row = new PointTransaction();
        row.id = UUID.randomUUID();
        row.householdId = householdId;
        row.userId = userId;
        row.points = delta;
        row.reason = PointReason.manual_adjust;
        row.createdAt = now;
        row.persist();
        return row;
    }
}
