package com.betterhome.households.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalTime;
import java.util.Optional;
import java.util.UUID;

@Entity
@Table(name = "household")
public class Household extends PanacheEntityBase {

    @Id public UUID id;

    @Column(nullable = false)
    public String name;

    @Column(nullable = false)
    public String timezone;

    @Column(name = "reminder_days_before", nullable = false)
    public int reminderDaysBefore;

    @Column(name = "reminder_time", nullable = false)
    public LocalTime reminderTime;

    @Column(name = "created_by", nullable = false)
    public UUID createdBy;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    @Column(name = "deleted_at")
    public Instant deletedAt;

    public static Optional<Household> findActiveById(UUID id) {
        return find("id = ?1 and deletedAt is null", id).firstResultOptional();
    }
}
