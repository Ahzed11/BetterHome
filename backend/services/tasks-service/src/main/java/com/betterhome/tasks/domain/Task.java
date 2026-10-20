package com.betterhome.tasks.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Entity
@Table(name = "task")
public class Task extends PanacheEntityBase {

    @Id public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(name = "template_id", nullable = false)
    public UUID templateId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public TaskOrigin origin;

    @Column(nullable = false)
    public String title;

    public String emoji;

    @Column(nullable = false)
    public String description;

    @Column(nullable = false)
    public int points;

    @Column(name = "late_points", nullable = false)
    public int latePoints;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public TaskStatus status;

    @Column(name = "assignee_id", nullable = false)
    public UUID assigneeId;

    @Column(name = "completer_id")
    public UUID completerId;

    @Column(name = "dismissed_by")
    public UUID dismissedBy;

    @Enumerated(EnumType.STRING)
    @Column(name = "dismissal_reason")
    public DismissalReason dismissalReason;

    @Column(name = "due_at")
    public Instant dueAt;

    @Column(name = "due_reminder_sent_at")
    public Instant dueReminderSentAt;

    /** Set once the assignee was told the task is overdue. */
    @Column(name = "overdue_notified_at")
    public Instant overdueNotifiedAt;

    @Column(name = "completed_at")
    public Instant completedAt;

    @Column(name = "completion_no", nullable = false)
    public int completionNo;

    @Column(name = "points_awarded")
    public Integer pointsAwarded;

    /** The reason given by the admin at the latest reversion; kept when the task is reopened. */
    @Column(name = "reversion_reason")
    public String reversionReason;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    public static Optional<Task> findInHousehold(UUID householdId, UUID taskId) {
        return find("id = ?1 and householdId = ?2", taskId, householdId).firstResultOptional();
    }

    public static List<Task> listForHousehold(
            UUID householdId, TaskStatus status, UUID assigneeId) {
        if (status != null && assigneeId != null) {
            return list(
                    "householdId = ?1 and status = ?2 and assigneeId = ?3 order by createdAt desc",
                    householdId,
                    status,
                    assigneeId);
        }
        if (status != null) {
            return list(
                    "householdId = ?1 and status = ?2 order by createdAt desc",
                    householdId,
                    status);
        }
        if (assigneeId != null) {
            return list(
                    "householdId = ?1 and assigneeId = ?2 order by createdAt desc",
                    householdId,
                    assigneeId);
        }
        return list("householdId = ?1 order by createdAt desc", householdId);
    }

    public static List<Task> listOpenForAssignee(UUID householdId, UUID assigneeId) {
        return list(
                "householdId = ?1 and assigneeId = ?2 and status = ?3",
                householdId,
                assigneeId,
                TaskStatus.open);
    }

    public static List<Task> listOpenRecurrenceForTemplate(UUID householdId, UUID templateId) {
        return list(
                "householdId = ?1 and templateId = ?2 and origin = ?3 and status = ?4",
                householdId,
                templateId,
                TaskOrigin.recurrence,
                TaskStatus.open);
    }

    /** Dismisses every open task of {@code assignee}, in any household; returns how many. */
    public static int dismissOpenOf(UUID assignee, UUID dismissedBy, Instant now) {
        return update(
                "status = ?1, dismissedBy = ?2, dismissalReason = ?3, updatedAt = ?4"
                        + " where assigneeId = ?5 and status = ?6",
                TaskStatus.dismissed,
                dismissedBy,
                DismissalReason.assignee_away,
                now,
                assignee,
                TaskStatus.open);
    }

    /** Hands every task assigned to {@code user} to {@code replacement}; returns how many. */
    public static int replaceAssignee(UUID user, UUID replacement) {
        return update("assigneeId = ?1 where assigneeId = ?2", replacement, user);
    }

    /** Hands every completion by {@code user} to {@code replacement}; returns how many. */
    public static int replaceCompleter(UUID user, UUID replacement) {
        return update("completerId = ?1 where completerId = ?2", replacement, user);
    }

    /** Hands every dismissal by {@code user} to {@code replacement}; returns how many. */
    public static int replaceDismissedBy(UUID user, UUID replacement) {
        return update("dismissedBy = ?1 where dismissedBy = ?2", replacement, user);
    }
}
