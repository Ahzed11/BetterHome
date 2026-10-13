package com.betterhome.tasks.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Entity
@Table(name = "task_template")
public class TaskTemplate extends PanacheEntityBase {

    @Id
    public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    @Column(nullable = false)
    public String title;

    public String emoji;

    @Column(nullable = false)
    public String description;

    @Column(nullable = false)
    public int points;

    @Column(name = "late_points", nullable = false)
    public int latePoints;

    @Column(name = "default_due_offset_minutes", nullable = false)
    public int defaultDueOffsetMinutes;

    @Column(name = "rotation_id", nullable = false)
    public UUID rotationId;

    @Column(name = "created_by", nullable = false)
    public UUID createdBy;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    @Column(name = "archived_at")
    public Instant archivedAt;

    public boolean isArchived() {
        return archivedAt != null;
    }

    public static Optional<TaskTemplate> findActive(UUID householdId, UUID templateId) {
        return find(
                        "id = ?1 and householdId = ?2 and archivedAt is null",
                        templateId,
                        householdId)
                .firstResultOptional();
    }

    public static Optional<TaskTemplate> findInHousehold(UUID householdId, UUID templateId) {
        return find("id = ?1 and householdId = ?2", templateId, householdId).firstResultOptional();
    }

    public static List<TaskTemplate> listActive(UUID householdId) {
        return list(
                "householdId = ?1 and archivedAt is null order by createdAt", householdId);
    }
}
