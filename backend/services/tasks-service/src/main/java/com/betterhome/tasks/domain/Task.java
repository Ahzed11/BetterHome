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

    @Id
    public UUID id;

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

    @Column(name = "completed_at")
    public Instant completedAt;

    @Column(name = "points_awarded")
    public Integer pointsAwarded;

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
}
