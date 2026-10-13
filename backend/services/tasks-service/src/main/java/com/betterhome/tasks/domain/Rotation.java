package com.betterhome.tasks.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "rotation")
public class Rotation extends PanacheEntityBase {

    @Id
    public UUID id;

    @Column(name = "household_id", nullable = false)
    public UUID householdId;

    public String name;

    @Column(name = "last_assigned_user_id")
    public UUID lastAssignedUserId;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    public static java.util.Optional<Rotation> findOptionalById(UUID id) {
        return find("id", id).firstResultOptional();
    }
}
