package com.betterhome.tasks.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Entity
@Table(name = "task_recurrence")
public class TaskRecurrence extends PanacheEntityBase {

    @Id
    public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(name = "template_id", nullable = false)
    public UUID templateId;

    @Column(name = "rotation_id", nullable = false)
    public UUID rotationId;

    @Column(nullable = false)
    public String rrule;

    @Enumerated(EnumType.STRING)
    @Column(name = "assignment_mode", nullable = false)
    public AssignmentMode assignmentMode;

    @Column(name = "fixed_assignee_id")
    public UUID fixedAssigneeId;

    @Column(nullable = false)
    public String timezone;

    @Column(name = "starts_at", nullable = false)
    public Instant startsAt;

    @Column(name = "ends_at")
    public Instant endsAt;

    @Column(name = "last_generated_at")
    public Instant lastGeneratedAt;

    @Column(name = "next_run_at")
    public Instant nextRunAt;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    public static Optional<TaskRecurrence> findByTemplate(UUID householdId, UUID templateId) {
        return find("householdId = ?1 and templateId = ?2", householdId, templateId)
                .firstResultOptional();
    }

    public static Optional<TaskRecurrence> findOptionalById(UUID id) {
        return find("id", id).firstResultOptional();
    }
}
